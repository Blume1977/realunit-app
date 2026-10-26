import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_blockchain_api_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_faucet_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_unsigned_transactions_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_sell_payment_info_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/packages/wallet/wallet_account.dart';
import 'package:realunit_wallet/screens/sell_bitbox/cubit/sell_bitbox_cubit.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../helper/fake_bitbox_credentials.dart';
import '../../helper/unsigned_eip1559_tx.dart';

class _MockFaucet extends Mock implements DfxFaucetService {}

class _MockBlockchain extends Mock implements DfxBlockchainApiService {}

class _MockSellService extends Mock implements RealUnitSellPaymentInfoService {}

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock implements AWallet {}

class _MockWalletAccount extends Mock implements AWalletAccount {}

// Mainnet values the app is configured with (ApiConfig mainnet).
const _chainId = 1;
const _realuContract = '0x553c7f9c780316fc1d34b8e14ac2465ab22a090b';
const _zchfContract = '0xb58e61c3098d85632df34eecfb899a1ed80921cb';
const _brokerbot = '0xcff32c60b87296b8c0c12980de685bed6cb9dd6d';

// Quote fixture values.
const _depositAddress = '0x222222222222222222222222222222222222bc02';
const _otherAddress = '0x1111111111111111111111111111111111111111';
const _shares = 100;
const _zchfAmount = 250.5;
final _zchfAmountWei = BigInt.parse('250500000000000000000');
const _requiredGasEth = 0.001;

const _swapNonce = 7;
final _gasPrice = BigInt.from(2000000000); // 2 gwei
const _swapGasLimit = 350000;
const _depositGasLimit = 100000;

SellPaymentInfo _quote({
  double? zchfAmount = _zchfAmount,
  double requiredGasEth = _requiredGasEth,
}) => SellPaymentInfo(
  id: 42,
  eip7702: Eip7702Data.fromJson(_eip7702Json()),
  amount: _shares,
  exchangeRate: 1.0,
  rate: 1.0,
  beneficiary: const BeneficiaryDto(iban: 'CH...'),
  estimatedAmount: _zchfAmount,
  currency: Currency.chf,
  depositAddress: _depositAddress,
  tokenAddress: _realuContract,
  chainId: _chainId,
  ethBalance: 1.0,
  requiredGasEth: requiredGasEth,
  zchfAmount: zchfAmount,
);

Map<String, dynamic> _eip7702Json() => {
  'relayerAddress': _otherAddress,
  'delegationManagerAddress': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  'delegatorAddress': '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b',
  'userNonce': 7,
  'domain': {
    'name': 'DelegationManager',
    'version': '1',
    'chainId': _chainId,
    'verifyingContract': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  },
  'types': {
    'Delegation': <Map<String, dynamic>>[],
    'Caveat': <Map<String, dynamic>>[],
  },
  'message': {
    'delegate': _otherAddress,
    'delegator': '0x9f5713deacb8e9cab6c2d3fae1afc2715f8d2d71',
    'authority': '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'caveats': <Map<String, dynamic>>[],
    'salt': 0,
  },
  'tokenAddress': _realuContract,
  'amountWei': '$_shares',
  'depositAddress': _depositAddress,
};

/// REALU `transferAndCall(brokerbot, shares, "")`, the swap that matches [_quote].
UnsignedEip1559Tx _validSwap() => UnsignedEip1559Tx(
  chainId: _chainId,
  nonce: _swapNonce,
  maxPriorityFeePerGas: _gasPrice,
  maxFeePerGas: _gasPrice,
  gasLimit: _swapGasLimit,
  to: _realuContract,
  value: BigInt.zero,
  data: transferAndCallCalldata(_brokerbot, BigInt.from(_shares)),
);

/// ZCHF `transfer(depositAddress, zchfAmount)`, the deposit that matches [_quote].
UnsignedEip1559Tx _validDeposit() => UnsignedEip1559Tx(
  chainId: _chainId,
  nonce: _swapNonce + 1,
  maxPriorityFeePerGas: _gasPrice,
  maxFeePerGas: _gasPrice,
  gasLimit: _depositGasLimit,
  to: _zchfContract,
  value: BigInt.zero,
  data: addressAmountCalldata(erc20TransferSelector, _depositAddress, _zchfAmountWei),
);

void main() {
  late _MockFaucet faucet;
  late _MockBlockchain blockchain;
  late _MockSellService sellService;
  late _MockAppStore appStore;
  late _MockWallet wallet;
  late _MockWalletAccount account;
  late FakeBitboxCredentials creds;
  late List<BroadcastTransactionRequestDto> broadcasts;

  setUpAll(() {
    registerFallbackValue(
      const BroadcastTransactionRequestDto(unsignedTx: '', r: '', s: '', v: 0),
    );
    registerFallbackValue(_quote());
  });

  setUp(() {
    faucet = _MockFaucet();
    blockchain = _MockBlockchain();
    sellService = _MockSellService();
    appStore = _MockAppStore();
    wallet = _MockWallet();
    account = _MockWalletAccount();
    creds = FakeBitboxCredentials(signDelay: Duration.zero);
    broadcasts = [];

    when(() => appStore.wallet).thenReturn(wallet);
    when(() => appStore.apiConfig).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    when(() => appStore.primaryAddress).thenReturn(creds.address.hexEip55);
    when(() => wallet.currentAccount).thenReturn(account);
    when(() => account.primaryAddress).thenReturn(creds);
    when(() => sellService.broadcastTransaction(any(), any())).thenAnswer((invocation) async {
      broadcasts.add(invocation.positionalArguments[1] as BroadcastTransactionRequestDto);
      return '0xtxhash${broadcasts.length}';
    });
    when(() => sellService.confirmPaymentWithTxHash(any(), any())).thenAnswer((_) async {});
  });

  /// Runs the whole BitBox sell for the given unsigned transactions: prepare,
  /// confirm the swap, confirm the deposit. Each step runs only if the cubit
  /// reached the state that step expects.
  Future<SellBitboxCubit> runSell({
    required UnsignedEip1559Tx swap,
    required UnsignedEip1559Tx deposit,
    SellPaymentInfo? quote,
  }) async {
    when(() => sellService.createUnsignedTransactions(any())).thenAnswer(
      (_) async => RealUnitUnsignedTransactionsRequestDto(
        swap: swap.toHex(),
        deposit: deposit.toHex(),
      ),
    );
    final cubit = SellBitboxCubit(
      paymentInfo: quote ?? _quote(),
      faucetService: faucet,
      blockchainService: blockchain,
      sellService: sellService,
      appStore: appStore,
    )..start();
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((s) => s is SellBitboxEthReady);

    await cubit.proceedToSwap();
    if (cubit.state is SellBitboxAwaitingSwapConfirm) await cubit.confirmSwap();
    if (cubit.state is SellBitboxAwaitingDepositConfirm) await cubit.confirmDeposit();
    return cubit;
  }

  Future<void> expectRefused({
    UnsignedEip1559Tx? swap,
    UnsignedEip1559Tx? deposit,
    SellPaymentInfo? quote,
  }) async {
    final cubit = await runSell(
      swap: swap ?? _validSwap(),
      deposit: deposit ?? _validDeposit(),
      quote: quote,
    );
    expect(creds.signCallCount, 0, reason: 'expected 0 sign calls');
    expect(broadcasts, isEmpty, reason: 'expected 0 broadcasts');
    expect(cubit.state, isA<SellBitboxTransactionMismatch>());
  }

  group('BitBox sell signs only transactions that match the confirmed quote', () {
    test('signs and broadcasts a swap and deposit that match the quote', () async {
      final swap = _validSwap();
      final deposit = _validDeposit();

      final cubit = await runSell(swap: swap, deposit: deposit);

      expect(cubit.state, isA<SellBitboxSuccess>());
      expect(creds.signCallCount, 2);
      expect(
        creds.signedPayloads.map(convert.hex.encode).toList(),
        [swap.toHex().substring(2), deposit.toHex().substring(2)],
      );
      expect(broadcasts.map((b) => b.unsignedTx).toList(), [swap.toHex(), deposit.toHex()]);
      verify(() => sellService.confirmPaymentWithTxHash(any(), '0xtxhash2')).called(1);
    });
  });

  group('refuses to sign a swap that differs from the quote', () {
    test('swap to a contract other than the REALU token', () async {
      await expectRefused(swap: _validSwap().copyWith(to: _zchfContract));
    });

    test('swap calling transfer instead of transferAndCall', () async {
      await expectRefused(
        swap: _validSwap().copyWith(
          data: addressAmountCalldata(erc20TransferSelector, _brokerbot, BigInt.from(_shares)),
        ),
      );
    });

    test('swap calling approve instead of transferAndCall', () async {
      await expectRefused(
        swap: _validSwap().copyWith(
          data: addressAmountCalldata(erc20ApproveSelector, _brokerbot, BigInt.from(_shares)),
        ),
      );
    });

    test('swap to a recipient other than the configured brokerbot', () async {
      await expectRefused(
        swap: _validSwap().copyWith(
          data: transferAndCallCalldata(_otherAddress, BigInt.from(_shares)),
        ),
      );
    });

    test('swap for a share count other than the confirmed shares', () async {
      await expectRefused(
        swap: _validSwap().copyWith(
          data: transferAndCallCalldata(_brokerbot, BigInt.from(_shares + 1)),
        ),
      );
    });

    test('swap carrying native ETH value', () async {
      await expectRefused(swap: _validSwap().copyWith(value: BigInt.one));
    });

    test('swap for a chain other than the app chain', () async {
      await expectRefused(swap: _validSwap().copyWith(chainId: 11155111));
    });

    test('swap whose transferAndCall data argument is not empty', () async {
      await expectRefused(
        swap: _validSwap().copyWith(
          data: transferAndCallCalldata(
            _brokerbot,
            BigInt.from(_shares),
            tail: Uint8List.fromList([0x01]),
          ),
        ),
      );
    });

    test('swap that is not a type 2 transaction', () async {
      await expectRefused(swap: _validSwap().copyWith(typeByte: 0x01));
    });

    test('swap with bytes after the RLP payload', () async {
      await expectRefused(swap: _validSwap().copyWith(trailingHex: 'ff'));
    });
  });

  group('refuses to sign a deposit that differs from the quote', () {
    test('deposit to a contract other than the ZCHF token', () async {
      await expectRefused(deposit: _validDeposit().copyWith(to: _realuContract));
    });

    test('deposit to a recipient other than the quote deposit address', () async {
      await expectRefused(
        deposit: _validDeposit().copyWith(
          data: addressAmountCalldata(erc20TransferSelector, _otherAddress, _zchfAmountWei),
        ),
      );
    });

    test('deposit calling approve instead of transfer', () async {
      await expectRefused(
        deposit: _validDeposit().copyWith(
          data: addressAmountCalldata(erc20ApproveSelector, _depositAddress, _zchfAmountWei),
        ),
      );
    });

    test('deposit carrying native ETH value', () async {
      await expectRefused(deposit: _validDeposit().copyWith(value: BigInt.one));
    });

    test('deposit for a ZCHF amount other than the quote', () async {
      await expectRefused(
        deposit: _validDeposit().copyWith(
          data: addressAmountCalldata(
            erc20TransferSelector,
            _depositAddress,
            _zchfAmountWei - BigInt.from(10).pow(17),
          ),
        ),
      );
    });

    test('quote without a ZCHF amount', () async {
      await expectRefused(quote: _quote(zchfAmount: null));
    });

    test('deposit nonce that does not follow the swap nonce', () async {
      await expectRefused(deposit: _validDeposit().copyWith(nonce: _swapNonce));
    });

    test('deposit for a chain other than the app chain', () async {
      await expectRefused(deposit: _validDeposit().copyWith(chainId: 11155111));
    });

    test('deposit that is not a type 2 transaction', () async {
      await expectRefused(deposit: _validDeposit().copyWith(typeByte: 0x01));
    });

    test('deposit with bytes after the RLP payload', () async {
      await expectRefused(deposit: _validDeposit().copyWith(trailingHex: 'ff'));
    });
  });

  group('refuses to sign transactions whose fee exceeds the quoted gas', () {
    // maxFeePerGas x gasLimit of both transactions together may be at most
    // twice the quote's requiredGasEth (0.001 ETH); the valid fixture uses 0.0009.
    final highFee = BigInt.from(200000000000); // 200 gwei

    test('signs when the gas price rose but stays within twice the quoted gas', () async {
      final raised = BigInt.from(4000000000); // 4 gwei: 0.0018 ETH for both

      final cubit = await runSell(
        swap: _validSwap().copyWith(maxFeePerGas: raised),
        deposit: _validDeposit().copyWith(maxFeePerGas: raised),
      );

      expect(cubit.state, isA<SellBitboxSuccess>());
      expect(creds.signCallCount, 2);
    });

    test('signs when the fee is exactly twice the quoted gas', () async {
      // 350000 x 4 gwei + 100000 x 6 gwei = 0.002 ETH
      final cubit = await runSell(
        swap: _validSwap().copyWith(maxFeePerGas: BigInt.from(4000000000)),
        deposit: _validDeposit().copyWith(maxFeePerGas: BigInt.from(6000000000)),
      );

      expect(cubit.state, isA<SellBitboxSuccess>());
      expect(creds.signCallCount, 2);
    });

    test('fee one gas unit above twice the quoted gas', () async {
      await expectRefused(
        swap: _validSwap().copyWith(maxFeePerGas: BigInt.from(4000000000)),
        deposit: _validDeposit().copyWith(
          maxFeePerGas: BigInt.from(6000000000),
          gasLimit: _depositGasLimit + 1,
        ),
      );
    });

    test('fee just above twice the quoted gas', () async {
      final raised = BigInt.from(4500000000); // 4.5 gwei: 0.002025 ETH for both
      await expectRefused(
        swap: _validSwap().copyWith(maxFeePerGas: raised),
        deposit: _validDeposit().copyWith(maxFeePerGas: raised),
      );
    });

    test('swap fee above the quoted gas', () async {
      await expectRefused(
        swap: _validSwap().copyWith(maxFeePerGas: highFee),
      );
    });

    for (final requiredGasEth in const [-0.001, 1e-19]) {
      test('quote with quoted gas $requiredGasEth ETH', () async {
        final cubit = await runSell(
          swap: _validSwap(),
          deposit: _validDeposit(),
          quote: _quote(requiredGasEth: requiredGasEth),
        );

        expect(creds.signCallCount, 0, reason: 'expected 0 sign calls');
        expect(broadcasts, isEmpty, reason: 'expected 0 broadcasts');
        expect(
          cubit.state,
          isA<SellBitboxTransactionMismatch>().having(
            (s) => s.message,
            'message',
            contains('quoted gas'),
          ),
        );
      });
    }

    test('deposit fee above the quoted gas', () async {
      await expectRefused(
        deposit: _validDeposit().copyWith(maxFeePerGas: highFee),
      );
    });
  });
}
