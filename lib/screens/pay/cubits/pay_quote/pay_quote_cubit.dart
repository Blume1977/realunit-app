import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/lnurlp_payment_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_swap_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';

part 'pay_quote_state.dart';

/// Reads the public OCP payment-link quote (`GET /v1/lnurlp/:id`) and surfaces
/// the requested fiat amount + the exact ZCHF amount the Ethereum method
/// requires. The amount comes from the API `transferAmounts` (ZCHF on the
/// Ethereum entry) — the app never computes it. An expired quote surfaces as a
/// typed state so the view can prompt a re-scan. An invalid swap preview
/// (`isValid: false`) is [PayQuoteError], never Ready — the app does not
/// locally ceil share counts; `swap.amount` is displayed only when valid.
/// The swap quote shown here is the quote later signed; the process step does
/// not request a second, larger quote.
class PayQuoteCubit extends Cubit<PayQuoteState> {
  final RealUnitPayService _payService;
  final String _paymentLinkId;

  PayQuoteCubit(this._payService, this._paymentLinkId) : super(const PayQuoteLoading());

  Future<void> load() async {
    emit(const PayQuoteLoading());

    try {
      final details = await _payService.getPaymentDetails(_paymentLinkId);
      if (isClosed) return;

      if (details.quote.expiration.isBefore(DateTime.now())) {
        emit(const PayQuoteExpired());
        return;
      }

      final zchfAmount = _zchfTransferAmount(details);
      if (zchfAmount == null) {
        emit(const PayQuoteUnavailable());
        return;
      }

      // Confirmed swap quote using the plain bill ZCHF amount (no slippage
      // buffer). Shown on the pay-quote screen so the user sees expected REALU
      // sold, CHF proceeds and the API Ethereum transaction fee before
      // confirming. PayProcessCubit signs this same quote — it does not
      // re-request a larger one.
      final swap = await _payService.getSwapPaymentInfo(
        RealUnitSwapDto.fromTargetAmount(zchfAmount),
      );
      if (isClosed) return;

      if (!swap.isValid) {
        emit(_invalidSwapState(swap));
        return;
      }

      final fiatAmount = details.requestedAmount.amount;
      double? billEur;
      double? feeEur;
      double? roundingEur;
      double? totalEur;
      final valueChf = swap.valueChf;
      final valueEur = swap.valueEur;
      if (valueChf != null && valueEur != null && valueChf != 0) {
        final ratio = valueEur / valueChf;
        final feeChf = swap.ethereumTransactionFeeChf ?? 0;
        final roundingChf = swap.estimatedAmount - fiatAmount - feeChf;
        final totalChf = fiatAmount + feeChf + roundingChf;
        billEur = fiatAmount * ratio;
        feeEur = feeChf * ratio;
        roundingEur = roundingChf * ratio;
        totalEur = totalChf * ratio;
      }

      emit(
        PayQuoteReady(
          paymentLinkId: _paymentLinkId,
          quoteId: details.quote.id,
          fiatAsset: details.requestedAmount.asset,
          fiatAmount: fiatAmount,
          zchfAmount: zchfAmount,
          merchantName: _recipientName(details),
          merchantCity: details.recipient?.city,
          expiresAt: details.quote.expiration,
          swap: swap,
          billEur: billEur,
          feeEur: feeEur,
          roundingEur: roundingEur,
          totalEur: totalEur,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(PayQuoteError(ApiException.userFacingMessage(e)));
    }
  }

  /// Invalid preview swaps are not payable. Non-empty API errors are shown 1:1;
  /// a missing/empty error uses the view's generic copy. The app does not map
  /// `AmountTooLow` onto holdings — that string is the API's volume signal.
  static PayQuoteError _invalidSwapState(SwapPaymentInfo swap) {
    final error = swap.error;
    if (error != null && error.isNotEmpty) {
      return PayQuoteError(error);
    }
    return const PayQuoteError('');
  }

  /// OCP recipient name, or the payment link's display name when the
  /// recipient has none.
  static String? _recipientName(LnurlpPaymentDto details) {
    final name = details.recipient?.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final displayName = details.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return null;
  }

  /// The ZCHF amount listed for the Ethereum transfer method, or null if the
  /// payment link does not offer an Ethereum/ZCHF method.
  static double? _zchfTransferAmount(LnurlpPaymentDto details) {
    for (final transfer in details.transferAmounts) {
      if (transfer.method.toLowerCase() != 'ethereum') continue;
      for (final asset in transfer.assets) {
        if (asset.asset.toUpperCase() == 'ZCHF') return asset.amount;
      }
    }
    return null;
  }
}
