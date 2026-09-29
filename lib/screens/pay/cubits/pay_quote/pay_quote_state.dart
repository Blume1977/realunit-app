part of 'pay_quote_cubit.dart';

sealed class PayQuoteState extends Equatable {
  const PayQuoteState();

  @override
  List<Object?> get props => [];
}

class PayQuoteLoading extends PayQuoteState {
  const PayQuoteLoading();
}

class PayQuoteReady extends PayQuoteState {
  final String paymentLinkId;
  final String quoteId;
  final String fiatAsset;
  final double fiatAmount;
  final double zchfAmount;
  final String? merchantName;
  final String? merchantCity;
  final DateTime expiresAt;
  final SwapPaymentInfo swap;
  final double? billEur;
  final double? feeEur;
  final double? roundingEur;
  final double? totalEur;

  const PayQuoteReady({
    required this.paymentLinkId,
    required this.quoteId,
    required this.fiatAsset,
    required this.fiatAmount,
    required this.zchfAmount,
    required this.swap,
    required this.expiresAt,
    this.merchantName,
    this.merchantCity,
    this.billEur,
    this.feeEur,
    this.roundingEur,
    this.totalEur,
  });

  bool get hasEurReceipt =>
      billEur != null && feeEur != null && roundingEur != null && totalEur != null;

  @override
  List<Object?> get props => [
    paymentLinkId,
    quoteId,
    fiatAsset,
    fiatAmount,
    zchfAmount,
    merchantName,
    merchantCity,
    expiresAt,
    swap,
    billEur,
    feeEur,
    roundingEur,
    totalEur,
  ];
}

/// The quote attached to the scanned link has expired — the user must re-scan.
class PayQuoteExpired extends PayQuoteState {
  const PayQuoteExpired();
}

/// The payment link offers no Ethereum/ZCHF transfer method.
class PayQuoteUnavailable extends PayQuoteState {
  const PayQuoteUnavailable();
}

class PayQuoteError extends PayQuoteState {
  final String message;

  const PayQuoteError(this.message);

  @override
  List<Object?> get props => [message];
}
