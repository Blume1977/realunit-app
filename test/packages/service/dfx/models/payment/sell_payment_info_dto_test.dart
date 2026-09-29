import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/styles/currency.dart';

void main() {
  Map<String, dynamic> eip7702Json() => {
    'relayerAddress': '0xrelay',
    'delegationManagerAddress': '0xmgr',
    'delegatorAddress': '0xdr',
    'userNonce': 7,
    'domain': {
      'name': 'RealUnit',
      'version': '1',
      'chainId': 1,
      'verifyingContract': '0xverify',
    },
    'types': {
      'Delegation': <Map<String, dynamic>>[],
      'Caveat': <Map<String, dynamic>>[],
    },
    'message': {
      'delegate': '0xd',
      'delegator': '0xdr',
      'authority': '0xauth',
      'caveats': <Map<String, dynamic>>[],
      'salt': 0,
    },
    'tokenAddress': '0xtoken',
    'amountWei': '12345',
    'depositAddress': '0xdeposit',
  };

  Map<String, dynamic> base() => {
    'id': 1,
    'routeId': 2,
    'timestamp': '2026-05-15T10:00:00Z',
    'eip7702': eip7702Json(),
    'depositAddress': '0xdeposit',
    'amount': 100.5,
    'tokenAddress': '0xtoken',
    'chainId': 1,
    'fees': {
      'rate': 0.01,
      'fixed': 0.5,
      'network': 0.0,
      'min': 1.0,
      'dfx': 0.25,
      'total': 1.76,
    },
    'minVolume': 5.0,
    'maxVolume': 5000.0,
    'minVolumeTarget': 5.1,
    'maxVolumeTarget': 5100.0,
    'exchangeRate': 1.1,
    'rate': 1.05,
    'priceSteps': <Map<String, dynamic>>[],
    'estimatedAmount': 95.5,
    'currency': 'CHF',
    'beneficiary': {'name': 'Alice', 'iban': 'CH...'},
    'ethBalance': 0.1,
    'requiredGasEth': 0.001,
    'isValid': true,
  };

  group('$RealUnitSellPaymentInfoDto.fromJson', () {
    test('parses the full happy-path wire shape', () {
      final dto = RealUnitSellPaymentInfoDto.fromJson(base());

      expect(dto.id, 1);
      expect(dto.routeId, 2);
      expect(dto.timestamp, DateTime.utc(2026, 5, 15, 10));
      expect(dto.depositAddress, '0xdeposit');
      expect(dto.amount, 100.5);
      expect(dto.tokenAddress, '0xtoken');
      expect(dto.chainId, 1);
      expect(dto.fees.total, 1.76);
      expect(dto.minVolume, 5.0);
      expect(dto.maxVolume, 5000.0);
      expect(dto.currency, Currency.chf);
      expect(dto.beneficiary.name, 'Alice');
      expect(dto.beneficiary.iban, 'CH...');
      expect(dto.ethBalance, 0.1);
      expect(dto.requiredGasEth, 0.001);
      expect(dto.isValid, isTrue);
    });

    test('walks into the nested Eip7702Data DTO', () {
      final dto = RealUnitSellPaymentInfoDto.fromJson(base());

      // The recursive parse must walk all the way down — pin one leaf field
      // from each level.
      expect(dto.eip7702.relayerAddress, '0xrelay');
      expect(dto.eip7702.domain.chainId, 1);
      expect(dto.eip7702.message.delegate, '0xd');
      expect(dto.eip7702.amountWei, '12345');
    });

    test('parses the network fee when the quote includes it', () {
      final json = base()
        ..['ethereumTransactionFeeChf'] = 3
        ..['ethereumTransactionFeeRealu'] = 1;

      final dto = RealUnitSellPaymentInfoDto.fromJson(json);

      expect(dto.ethereumTransactionFeeChf, 3);
      expect(dto.ethereumTransactionFeeRealu, 1);
    });

    test('integer wire values for floating-point fields widen to double', () {
      final json = base()
        ..['amount'] = 100
        ..['exchangeRate'] = 1
        ..['rate'] = 1;

      final dto = RealUnitSellPaymentInfoDto.fromJson(json);

      expect(dto.amount, 100.0);
      expect(dto.exchangeRate, 1.0);
      expect(dto.rate, 1.0);
    });
  });
}
