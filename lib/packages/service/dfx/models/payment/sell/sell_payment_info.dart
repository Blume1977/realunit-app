import 'package:equatable/equatable.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/styles/currency.dart';

class StoredSellFiat extends Equatable {
  final double amount;
  final Currency currency;

  const StoredSellFiat({required this.amount, required this.currency});

  @override
  List<Object?> get props => [amount, currency];
}

class SellPaymentInfo {
  final int id;
  final Eip7702Data eip7702;
  final int amount;
  final double exchangeRate;
  final double rate;
  final BeneficiaryDto beneficiary;
  final double estimatedAmount;
  final Currency currency;
  final String depositAddress;
  final String tokenAddress;
  final int chainId;
  final double ethBalance;
  final double requiredGasEth;

  /// Relay gas the software-wallet customer pays. Absent on a BitBox quote.
  final double? ethereumTransactionFeeChf;
  final double? ethereumTransactionFeeRealu;
  // Fields below come from the API quote response. The backend is the
  // authority on whether the quote is valid for trading and what the
  // current min/max limits are for the user+currency combination.
  final bool isValid;
  final double minVolume;
  final double maxVolume;
  final String? error;
  final double? valueChf;
  final double? valueEur;
  final double? zchfAmount;

  const SellPaymentInfo({
    required this.id,
    required this.eip7702,
    required this.amount,
    required this.exchangeRate,
    required this.rate,
    required this.beneficiary,
    required this.estimatedAmount,
    required this.currency,
    required this.depositAddress,
    required this.tokenAddress,
    required this.chainId,
    required this.ethBalance,
    required this.requiredGasEth,
    this.ethereumTransactionFeeChf,
    this.ethereumTransactionFeeRealu,
    this.isValid = true,
    this.minVolume = 0,
    this.maxVolume = double.infinity,
    this.error,
    this.valueChf,
    this.valueEur,
    this.zchfAmount,
  });

  StoredSellFiat? storedFiat(Currency? settingsCurrency) {
    if (settingsCurrency == Currency.eur && valueEur != null) {
      return StoredSellFiat(amount: valueEur!, currency: Currency.eur);
    }
    if (settingsCurrency == Currency.chf && valueChf != null) {
      return StoredSellFiat(amount: valueChf!, currency: Currency.chf);
    }
    if (settingsCurrency == Currency.eur && valueChf != null) {
      return StoredSellFiat(amount: valueChf!, currency: Currency.chf);
    }
    if (settingsCurrency == Currency.chf && valueEur != null) {
      return StoredSellFiat(amount: valueEur!, currency: Currency.eur);
    }
    return null;
  }
}
