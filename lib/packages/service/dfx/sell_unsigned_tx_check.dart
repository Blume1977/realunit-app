import 'package:realunit_wallet/packages/service/dfx/delegation_caveat_check.dart';
import 'package:realunit_wallet/packages/service/dfx/eip1559_unsigned_tx_decoder.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';

/// The unsigned sell transactions do not match the confirmed quote.
class SellUnsignedTxMismatchException implements Exception {
  final String reason;

  const SellUnsignedTxMismatchException(this.reason);

  @override
  String toString() => 'SellUnsignedTxMismatchException: $reason';
}

const _ethDecimals = 18;
const _zchfDecimals = 18;

/// The transactions are built with the gas price at that moment, which can be
/// above the one the quote was priced with. Their combined maximum fee may be
/// at most this multiple of the quoted gas.
const sellGasHeadroomFactor = 2;

/// Checks the BitBox sell swap and deposit against the confirmed [quote]
/// before either is signed.
///
/// The swap must be the REALU `transferAndCall(brokerbot, shares, "")`; the
/// deposit, at the next nonce, must transfer exactly the quoted ZCHF amount to
/// the quote deposit address. Both must be value-free type 2 transactions on
/// [chainId] whose combined maximum fee stays within [sellGasHeadroomFactor]
/// times the quoted gas.
void checkSellUnsignedTransactions({
  required String swap,
  required String deposit,
  required SellPaymentInfo quote,
  required String tokenAddress,
  required int tokenDecimals,
  required int chainId,
  required bool testnet,
}) {
  final swapTx = _decode(swap, 'swap');
  final depositTx = _decode(deposit, 'deposit');

  for (final (name, tx) in [('swap', swapTx), ('deposit', depositTx)]) {
    if (tx.chainId != BigInt.from(chainId)) {
      _reject('$name chain ID is ${tx.chainId}, expected $chainId');
    }
    if (tx.value != BigInt.zero) {
      _reject('$name carries native value');
    }
  }

  if (swapTx.to != tokenAddress.toLowerCase()) {
    _reject('swap is not sent to the RealUnit token');
  }
  final swapCall = _guard(() => Erc677TransferAndCallCalldataDecoder.decode(swapTx.data), 'swap');
  if (swapCall.recipient != pinnedBrokerbotAddress(testnet: testnet).toLowerCase()) {
    _reject('swap recipient is not the brokerbot');
  }
  final shares = BigInt.from(quote.amount) * BigInt.from(10).pow(tokenDecimals);
  if (swapCall.amountWei != shares) {
    _reject('swap amount ${swapCall.amountWei} is not the confirmed $shares');
  }
  if (swapCall.callData.isNotEmpty) {
    _reject('swap carries call data for the brokerbot');
  }

  if (depositTx.nonce != swapTx.nonce + BigInt.one) {
    _reject('deposit nonce does not follow the swap nonce');
  }
  if (depositTx.to != pinnedZchfAddress(testnet: testnet).toLowerCase()) {
    _reject('deposit is not sent to the ZCHF token');
  }
  final depositCall = _guard(() => Erc20TransferCalldataDecoder.decode(depositTx.data), 'deposit');
  if (depositCall.recipient != quote.depositAddress.toLowerCase()) {
    _reject('deposit recipient is not the quote deposit address');
  }
  final zchfAmount = quote.zchfAmount;
  final zchfWei = zchfAmount == null ? null : _toBaseUnits(zchfAmount, _zchfDecimals);
  if (zchfWei == null) {
    _reject('quote has no exact ZCHF amount');
  }
  if (depositCall.amountWei != zchfWei) {
    _reject('deposit amount ${depositCall.amountWei} is not the quoted $zchfWei');
  }

  final maxFee =
      swapTx.maxFeePerGas * swapTx.gasLimit + depositTx.maxFeePerGas * depositTx.gasLimit;
  final quotedGas = _toBaseUnits(quote.requiredGasEth, _ethDecimals);
  if (quotedGas == null || maxFee > quotedGas * BigInt.from(sellGasHeadroomFactor)) {
    _reject('maximum fee $maxFee wei exceeds ${sellGasHeadroomFactor}x the quoted gas');
  }
}

DecodedEip1559Transaction _decode(String raw, String name) =>
    _guard(() => Eip1559UnsignedTxDecoder.decode(raw), name);

T _guard<T>(T Function() decode, String name) {
  try {
    return decode();
  } on PayUnsignedTxMismatchException catch (e) {
    _reject('$name: ${e.reason}');
  }
}

Never _reject(String reason) => throw SellUnsignedTxMismatchException(reason);

/// The exact base units of [value], or null when its shortest decimal form
/// does not fit in [decimals] places.
BigInt? _toBaseUnits(double value, int decimals) {
  if (!value.isFinite || value.isNegative) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:e([+-]?\d+))?$').firstMatch(value.toString());
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  final shift = decimals - fraction.length + int.parse(match.group(3) ?? '0');
  if (shift < 0) return null;
  return BigInt.parse('${match.group(1)}$fraction') * BigInt.from(10).pow(shift);
}
