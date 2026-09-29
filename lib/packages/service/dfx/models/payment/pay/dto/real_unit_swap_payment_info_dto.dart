import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';

/// Response of `PUT /v1/realunit/swap` — the REALU → ZCHF swap quote. The
/// backend is the authority on validity, limits, fees and the ZCHF estimate;
/// the app renders these fields and never recomputes them.
class RealUnitSwapPaymentInfoDto {
  final int id;
  final String uid;
  final int routeId;
  final DateTime timestamp;
  final double amount;
  final double estimatedAmount;
  final String targetAsset;
  final double minVolume;
  final double maxVolume;
  final double minVolumeTarget;
  final double maxVolumeTarget;
  final double ethBalance;
  final double requiredGasEth;
  final bool isValid;
  final String? error;
  final RealUnitSwapFeeDto? fees;
  final double? ethereumTransactionFeeChf;
  final double? ethereumTransactionFeeRealu;
  final double? valueChf;
  final double? valueEur;
  final Eip7702Data? eip7702;

  const RealUnitSwapPaymentInfoDto({
    required this.id,
    required this.uid,
    required this.routeId,
    required this.timestamp,
    required this.amount,
    required this.estimatedAmount,
    required this.targetAsset,
    required this.minVolume,
    required this.maxVolume,
    required this.minVolumeTarget,
    required this.maxVolumeTarget,
    required this.ethBalance,
    required this.requiredGasEth,
    required this.isValid,
    this.error,
    this.fees,
    this.ethereumTransactionFeeChf,
    this.ethereumTransactionFeeRealu,
    this.valueChf,
    this.valueEur,
    this.eip7702,
  });

  factory RealUnitSwapPaymentInfoDto.fromJson(Map<String, dynamic> json) {
    final isValid = json['isValid'] as bool;
    final ethereumTransactionFeeChf = json['ethereumTransactionFeeChf'] == null
        ? null
        : (json['ethereumTransactionFeeChf'] as num).toDouble();
    final ethereumTransactionFeeRealu =
        json['ethereumTransactionFeeRealu'] == null
        ? null
        : (json['ethereumTransactionFeeRealu'] as num).toDouble();
    final eip7702 = json['eip7702'] == null
        ? null
        : Eip7702Data.fromJson(json['eip7702'] as Map<String, dynamic>);
    if (isValid &&
        (ethereumTransactionFeeChf == null ||
            ethereumTransactionFeeRealu == null)) {
      throw const FormatException(
        'ethereumTransactionFeeChf and ethereumTransactionFeeRealu are required when isValid is true',
      );
    }
    return RealUnitSwapPaymentInfoDto(
      id: json['id'] as int,
      uid: json['uid'] as String,
      routeId: json['routeId'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      amount: (json['amount'] as num).toDouble(),
      estimatedAmount: (json['estimatedAmount'] as num).toDouble(),
      targetAsset: json['targetAsset'] as String,
      minVolume: (json['minVolume'] as num).toDouble(),
      maxVolume: (json['maxVolume'] as num).toDouble(),
      minVolumeTarget: (json['minVolumeTarget'] as num).toDouble(),
      maxVolumeTarget: (json['maxVolumeTarget'] as num).toDouble(),
      ethBalance: (json['ethBalance'] as num).toDouble(),
      requiredGasEth: (json['requiredGasEth'] as num).toDouble(),
      isValid: isValid,
      error: json['error'] as String?,
      fees: json['fees'] == null
          ? null
          : RealUnitSwapFeeDto.fromJson(json['fees'] as Map<String, dynamic>),
      ethereumTransactionFeeChf: ethereumTransactionFeeChf,
      ethereumTransactionFeeRealu: ethereumTransactionFeeRealu,
      valueChf: (json['valueChf'] as num?)?.toDouble(),
      valueEur: (json['valueEur'] as num?)?.toDouble(),
      eip7702: eip7702,
    );
  }
}

/// Fee breakdown from the swap quote. Only `total` is mapped for display.
class RealUnitSwapFeeDto {
  final double total;

  const RealUnitSwapFeeDto({required this.total});

  factory RealUnitSwapFeeDto.fromJson(Map<String, dynamic> json) {
    return RealUnitSwapFeeDto(total: (json['total'] as num).toDouble());
  }
}
