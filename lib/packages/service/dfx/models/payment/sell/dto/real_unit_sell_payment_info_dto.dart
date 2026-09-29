import 'package:realunit_wallet/packages/service/dfx/models/fees/dfx_fees_data.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/price_step_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/styles/currency.dart';

class RealUnitSellPaymentInfoDto {
  final int id;
  final int routeId;
  final DateTime timestamp;
  final Eip7702Data eip7702;
  final String depositAddress;
  final double amount;
  final String tokenAddress;
  final int chainId;
  final DfxFeesData fees;
  final double minVolume;
  final double maxVolume;
  final double minVolumeTarget;
  final double maxVolumeTarget;
  final double exchangeRate;
  final double rate;
  final List<PriceStep> priceSteps;
  final double estimatedAmount;
  final Currency currency;
  final BeneficiaryDto beneficiary;
  final double ethBalance;
  final double requiredGasEth;
  final bool isValid;
  final String? error;
  final double? valueChf;
  final double? valueEur;
  final double? zchfAmount;

  const RealUnitSellPaymentInfoDto({
    required this.id,
    required this.routeId,
    required this.timestamp,
    required this.eip7702,
    required this.depositAddress,
    required this.amount,
    required this.tokenAddress,
    required this.chainId,
    required this.fees,
    required this.minVolume,
    required this.maxVolume,
    required this.minVolumeTarget,
    required this.maxVolumeTarget,
    required this.exchangeRate,
    required this.rate,
    required this.priceSteps,
    required this.estimatedAmount,
    required this.currency,
    required this.beneficiary,
    required this.ethBalance,
    required this.requiredGasEth,
    required this.isValid,
    this.error,
    this.valueChf,
    this.valueEur,
    this.zchfAmount,
  });

  factory RealUnitSellPaymentInfoDto.fromJson(Map<String, dynamic> json) {
    return RealUnitSellPaymentInfoDto(
      id: json['id'] as int,
      routeId: json['routeId'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eip7702: Eip7702Data.fromJson(json['eip7702'] as Map<String, dynamic>),
      depositAddress: json['depositAddress'] as String,
      amount: (json['amount'] as num).toDouble(),
      tokenAddress: json['tokenAddress'] as String,
      chainId: json['chainId'] as int,
      fees: DfxFeesData.fromJson(json['fees'] as Map<String, dynamic>),
      minVolume: (json['minVolume'] as num).toDouble(),
      maxVolume: (json['maxVolume'] as num).toDouble(),
      minVolumeTarget: (json['minVolumeTarget'] as num).toDouble(),
      maxVolumeTarget: (json['maxVolumeTarget'] as num).toDouble(),
      exchangeRate: (json['exchangeRate'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      priceSteps: (json['priceSteps'] as List<dynamic>)
          .map((e) => PriceStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimatedAmount: (json['estimatedAmount'] as num).toDouble(),
      currency: Currency.fromCode(json['currency'] as String),
      beneficiary: BeneficiaryDto.fromJson(json['beneficiary'] as Map<String, dynamic>),
      ethBalance: (json['ethBalance'] as num).toDouble(),
      requiredGasEth: (json['requiredGasEth'] as num).toDouble(),
      isValid: json['isValid'] as bool,
      error: json['error'] as String?,
      valueChf: (json['valueChf'] as num?)?.toDouble(),
      valueEur: (json['valueEur'] as num?)?.toDouble(),
      zchfAmount: (json['zchfAmount'] as num?)?.toDouble(),
    );
  }
}

class BeneficiaryDto {
  final String? name;
  final String iban;

  const BeneficiaryDto({
    this.name,
    required this.iban,
  });

  factory BeneficiaryDto.fromJson(Map<String, dynamic> json) {
    return BeneficiaryDto(
      name: json['name'] as String?,
      iban: json['iban'] as String,
    );
  }
}
