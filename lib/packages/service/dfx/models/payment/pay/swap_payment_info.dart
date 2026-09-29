import 'package:equatable/equatable.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_swap_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';

/// Domain model for an IBAN-free REALU → ZCHF swap quote. The backend decides
/// validity, limits and the ZCHF estimate; this model only carries those fields
/// for the flow's cubits to render and to drive the ETH-balance / swap steps.
class SwapPaymentInfo extends Equatable {
  final int id;
  final double amount;
  final double estimatedAmount;
  final String targetAsset;
  final double ethBalance;
  final double requiredGasEth;
  final bool isValid;
  final String? error;
  final double? feesTotal;
  final double? ethereumTransactionFeeChf;
  final double? ethereumTransactionFeeRealu;
  final double? valueChf;
  final double? valueEur;
  final Eip7702Data? eip7702;

  const SwapPaymentInfo({
    required this.id,
    required this.amount,
    required this.estimatedAmount,
    required this.targetAsset,
    required this.ethBalance,
    required this.requiredGasEth,
    required this.isValid,
    this.error,
    this.feesTotal,
    this.ethereumTransactionFeeChf,
    this.ethereumTransactionFeeRealu,
    this.valueChf,
    this.valueEur,
    this.eip7702,
  });

  factory SwapPaymentInfo.fromDto(RealUnitSwapPaymentInfoDto dto) => SwapPaymentInfo(
    id: dto.id,
    amount: dto.amount,
    estimatedAmount: dto.estimatedAmount,
    targetAsset: dto.targetAsset,
    ethBalance: dto.ethBalance,
    requiredGasEth: dto.requiredGasEth,
    isValid: dto.isValid,
    error: dto.error,
    feesTotal: dto.fees?.total,
    ethereumTransactionFeeChf: dto.ethereumTransactionFeeChf,
    ethereumTransactionFeeRealu: dto.ethereumTransactionFeeRealu,
    valueChf: dto.valueChf,
    valueEur: dto.valueEur,
    eip7702: dto.eip7702,
  );

  @override
  List<Object?> get props => [
    id,
    amount,
    estimatedAmount,
    targetAsset,
    ethBalance,
    requiredGasEth,
    isValid,
    error,
    feesTotal,
    ethereumTransactionFeeChf,
    ethereumTransactionFeeRealu,
    valueChf,
    valueEur,
    eip7702,
  ];
}
