import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/sell_unsigned_tx_check.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../../helper/unsigned_eip1559_tx.dart';

const _realu = '0x553c7f9c780316fc1d34b8e14ac2465ab22a090b';
const _depositAddress = '0x222222222222222222222222222222222222bc02';
const _sepoliaBrokerbot = '0x39c33c2fd5b07b8e890fd2115d4adff7235fc9d2';
const _sepoliaZchf = '0xd3117681ca462268048f57d106d312ba0b1215ea';
const _sepoliaChainId = 11155111;

SellPaymentInfo _quote({required double zchfAmount, required double requiredGasEth}) =>
    SellPaymentInfo(
      id: 1,
      eip7702: Eip7702Data.fromJson(const {
        'relayerAddress': '',
        'delegationManagerAddress': '',
        'delegatorAddress': '',
        'userNonce': 0,
        'domain': {'name': '', 'version': '', 'chainId': 0, 'verifyingContract': ''},
        'types': {'Delegation': <Map<String, dynamic>>[], 'Caveat': <Map<String, dynamic>>[]},
        'message': {
          'delegate': '',
          'delegator': '',
          'authority': '',
          'caveats': <Map<String, dynamic>>[],
          'salt': 0,
        },
        'tokenAddress': '',
        'amountWei': '0',
        'depositAddress': '',
      }),
      amount: 3,
      exchangeRate: 1.0,
      rate: 1.0,
      beneficiary: const BeneficiaryDto(iban: 'CH...'),
      estimatedAmount: zchfAmount,
      currency: Currency.chf,
      depositAddress: _depositAddress,
      tokenAddress: _realu,
      chainId: _sepoliaChainId,
      ethBalance: 1.0,
      requiredGasEth: requiredGasEth,
      zchfAmount: zchfAmount,
    );

String _swap({BigInt? maxFeePerGas}) => UnsignedEip1559Tx(
  chainId: _sepoliaChainId,
  nonce: 0,
  maxPriorityFeePerGas: BigInt.one,
  maxFeePerGas: maxFeePerGas ?? BigInt.one,
  gasLimit: 350000,
  to: _realu,
  value: BigInt.zero,
  data: transferAndCallCalldata(_sepoliaBrokerbot, BigInt.from(3)),
).toHex();

String _deposit(BigInt zchfWei) => UnsignedEip1559Tx(
  chainId: _sepoliaChainId,
  nonce: 1,
  maxPriorityFeePerGas: BigInt.one,
  maxFeePerGas: BigInt.one,
  gasLimit: 100000,
  to: _sepoliaZchf,
  value: BigInt.zero,
  data: addressAmountCalldata(erc20TransferSelector, _depositAddress, zchfWei),
).toHex();

void _check({required String swap, required String deposit, required SellPaymentInfo quote}) =>
    checkSellUnsignedTransactions(
      swap: swap,
      deposit: deposit,
      quote: quote,
      tokenAddress: _realu,
      tokenDecimals: 0,
      chainId: _sepoliaChainId,
      testnet: true,
    );

void main() {
  group('checkSellUnsignedTransactions', () {
    test('accepts the testnet brokerbot and ZCHF token', () {
      expect(
        () => _check(
          swap: _swap(),
          deposit: _deposit(BigInt.parse('3750000000000000000')),
          quote: _quote(zchfAmount: 3.75, requiredGasEth: 0.001),
        ),
        returnsNormally,
      );
    });

    test('reads quote amounts that print in exponent form', () {
      // 1e-7 ZCHF and 5e-7 ETH print as "1e-7" and "5e-7".
      expect(
        () => _check(
          swap: _swap(maxFeePerGas: BigInt.from(1000000)),
          deposit: _deposit(BigInt.parse('100000000000')),
          quote: _quote(zchfAmount: 1e-7, requiredGasEth: 5e-7),
        ),
        returnsNormally,
      );
    });

    test('refuses a ZCHF amount with more than 18 decimals', () {
      expect(
        () => _check(
          swap: _swap(),
          deposit: _deposit(BigInt.zero),
          quote: _quote(zchfAmount: 1e-19, requiredGasEth: 0.001),
        ),
        throwsA(
          isA<SellUnsignedTxMismatchException>().having(
            (e) => e.reason,
            'reason',
            'quote has no exact ZCHF amount',
          ),
        ),
      );
    });

    test('refuses a negative ZCHF amount', () {
      expect(
        () => _check(
          swap: _swap(),
          deposit: _deposit(BigInt.zero),
          quote: _quote(zchfAmount: -1, requiredGasEth: 0.001),
        ),
        throwsA(
          isA<SellUnsignedTxMismatchException>().having(
            (e) => e.reason,
            'reason',
            'quote has no exact ZCHF amount',
          ),
        ),
      );
    });

    test('names the transaction that does not decode', () {
      expect(
        () => _check(
          swap: '0x02',
          deposit: _deposit(BigInt.parse('3750000000000000000')),
          quote: _quote(zchfAmount: 3.75, requiredGasEth: 0.001),
        ),
        throwsA(
          isA<SellUnsignedTxMismatchException>().having(
            (e) => e.reason,
            'reason',
            startsWith('swap:'),
          ),
        ),
      );
    });
  });
}
