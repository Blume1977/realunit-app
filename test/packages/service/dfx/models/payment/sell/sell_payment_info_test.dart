import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/styles/currency.dart';

Map<String, dynamic> _eip7702Json() => {
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
      'types': {'Delegation': <Map<String, dynamic>>[], 'Caveat': <Map<String, dynamic>>[]},
      'message': {
        'delegate': '0xd',
        'delegator': '0xdr',
        'authority': '0xauth',
        'caveats': <Map<String, dynamic>>[],
        'salt': 0,
      },
      'tokenAddress': '0xtoken',
      'amountWei': '12345',
      'depositAddress': '0xdeposit_full_address_with_long_string',
    };

SellPaymentInfo _info({double? valueEur, double? valueChf}) => SellPaymentInfo(
      id: 42,
      eip7702: Eip7702Data.fromJson(_eip7702Json()),
      amount: 100,
      exchangeRate: 1.0,
      rate: 1.0,
      beneficiary: const BeneficiaryDto(iban: 'CH...'),
      estimatedAmount: 99.5,
      currency: Currency.chf,
      depositAddress: '0xdeposit_full_address_with_long_string',
      tokenAddress: '0xtoken',
      chainId: 1,
      ethBalance: 0.1,
      requiredGasEth: 0.001,
      valueEur: valueEur,
      valueChf: valueChf,
    );

void main() {
  group('$SellPaymentInfo.storedFiat', () {
    test('EUR settings with both amounts use valueEur and EUR', () {
      final stored = _info(valueEur: 11.4, valueChf: 12.5).storedFiat(Currency.eur);

      expect(stored?.amount, 11.4);
      expect(stored?.currency, Currency.eur);
      expect(stored?.currency.code, 'EUR');
    });

    test('EUR settings with missing valueEur use valueChf and CHF', () {
      final stored = _info(valueChf: 12.5).storedFiat(Currency.eur);

      expect(stored?.amount, 12.5);
      expect(stored?.currency, Currency.chf);
      expect(stored?.currency.code, 'CHF');
    });

    test('EUR settings with zero valueEur keep EUR and do not fall through', () {
      final stored = _info(valueEur: 0, valueChf: 12.5).storedFiat(Currency.eur);

      expect(stored?.amount, 0);
      expect(stored?.currency, Currency.eur);
      expect(stored?.currency.code, 'EUR');
    });

    test('CHF settings with both amounts use valueChf and CHF', () {
      final stored = _info(valueChf: 12.5, valueEur: 11.4).storedFiat(Currency.chf);

      expect(stored?.amount, 12.5);
      expect(stored?.currency, Currency.chf);
      expect(stored?.currency.code, 'CHF');
    });

    test('CHF settings with missing valueChf use valueEur and EUR', () {
      final stored = _info(valueEur: 11.4).storedFiat(Currency.chf);

      expect(stored?.amount, 11.4);
      expect(stored?.currency, Currency.eur);
      expect(stored?.currency.code, 'EUR');
    });

    test('both amounts missing returns null', () {
      expect(_info().storedFiat(Currency.eur), isNull);
    });

    test('null settings returns null even when both amounts are set', () {
      expect(_info(valueEur: 11.4, valueChf: 12.5).storedFiat(null), isNull);
    });
  });

  group('$StoredSellFiat', () {
    test('props are the amount and the currency', () {
      const stored = StoredSellFiat(amount: 1.84, currency: Currency.eur);
      const same = StoredSellFiat(amount: 1.84, currency: Currency.eur);
      const other = StoredSellFiat(amount: 2, currency: Currency.chf);

      expect(stored.props, <Object?>[1.84, Currency.eur]);
      expect(stored, same);
      expect(stored, isNot(other));
    });
  });
}
