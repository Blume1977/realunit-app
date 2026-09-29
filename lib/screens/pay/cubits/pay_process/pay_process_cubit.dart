import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/sell_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';

part 'pay_process_state.dart';

/// Software-wallet pay. The customer only signs the EIP-7702 delegation. The
/// DFX relayer broadcasts one transaction and pays gas from the DFX balance,
/// the same way as sell. There is no faucet and no user-signed transfer.
///
/// BitBox and the debug wallet have no Pay option. A confirm that never left
/// the device leaves the quote reusable. A confirm that may already have been
/// relayed can be sent again: this payment does not leave CHF in the wallet,
/// and REALU is sold only when the first attempt did not arrive.
class PayProcessCubit extends Cubit<PayProcessState> {
  final RealUnitPayService _payService;
  final AppStore _appStore;

  final String _paymentLinkId;
  final String _quoteId;
  final SwapPaymentInfo _swap;

  bool _confirmSent = false;

  bool get swapCompleted => _confirmSent;

  Timer? _statusPollingTimer;

  static const _statusPollMaxAttempts = 40;
  static const _statusPollInterval = Duration(seconds: 3);

  int _statusPollGeneration = 0;
  int _statusPollAttempts = 0;
  bool _statusPollInFlight = false;

  PayProcessCubit({
    required RealUnitPayService payService,
    required AppStore appStore,
    required String paymentLinkId,
    required String quoteId,
    required SwapPaymentInfo swap,
  }) : _payService = payService,
       _appStore = appStore,
       _paymentLinkId = paymentLinkId,
       _quoteId = quoteId,
       _swap = swap,
       super(const PayProcessInitial());

  Future<void> start() async {
    final walletType = _appStore.wallet.walletType;
    if (walletType == WalletType.debug) {
      emit(
        const PayProcessFailure(PayProcessFailureReason.signatureUnsupported),
      );
      return;
    }
    if (walletType != WalletType.software) {
      emit(const PayProcessFailure(PayProcessFailureReason.payUnavailable));
      return;
    }
    if (!_swap.isValid) {
      final error = _swap.error;
      emit(
        PayProcessFailure(
          PayProcessFailureReason.generic,
          message: (error != null && error.isNotEmpty) ? error : null,
        ),
      );
      return;
    }
    if (_swap.eip7702 == null) {
      emit(const PayProcessFailure(PayProcessFailureReason.generic));
      return;
    }
    await _relay();
  }

  /// Retries a confirm that may already have been relayed. Never starts a
  /// second sale from a quote whose confirm has not left the device — that
  /// path re-enables Pay on the quote instead.
  Future<void> retryPay() async {
    if (state is! PayProcessPayRetry) return;
    await _relay();
  }

  Future<void> _relay() async {
    emit(const PayProcessPaying());
    try {
      final txHash = await _payService.confirmOcpPay(
        swap: _swap,
        paymentLinkId: _paymentLinkId,
        quoteId: _quoteId,
      );
      if (isClosed) return;
      _confirmSent = true;
      emit(PayProcessAwaitingSettlement(txHash));
      _startStatusPolling();
    } on AlreadyConfirmedException {
      if (isClosed) return;
      _confirmSent = true;
      emit(const PayProcessAwaitingSettlement('confirmed'));
      _startStatusPolling();
    } on PayConfirmNotSubmittedException catch (e) {
      if (isClosed) return;
      if (_confirmSent) {
        emit(
          PayProcessPayRetry(PayRetryReason.transient, message: e.apiMessage),
        );
        return;
      }
      emit(
        PayProcessFailure(
          PayProcessFailureReason.generic,
          message: e.apiMessage,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      _confirmSent = true;
      emit(
        PayProcessPayRetry(
          PayRetryReason.transient,
          message: e is ApiException ? e.message : null,
        ),
      );
    }
  }

  void _startStatusPolling() {
    _statusPollingTimer?.cancel();
    final generation = ++_statusPollGeneration;
    _statusPollAttempts = 0;
    _statusPollInFlight = false;
    _statusPollingTimer = Timer.periodic(_statusPollInterval, (_) async {
      if (generation != _statusPollGeneration || _statusPollInFlight) return;
      _statusPollInFlight = true;
      try {
        final status = await _payService.getPayStatus(_paymentLinkId);
        if (isClosed || generation != _statusPollGeneration) return;
        _statusPollAttempts++;
        if (!status.status.isTerminal) {
          if (_statusPollAttempts >= _statusPollMaxAttempts) {
            _statusPollingTimer?.cancel();
            emit(const PayProcessPayRetry(PayRetryReason.transient));
            return;
          }
          _statusPollInFlight = false;
          return;
        }
        _statusPollingTimer?.cancel();
        if (status.status.isCompleted) {
          emit(const PayProcessSuccess());
        } else {
          emit(const PayProcessPayRetry(PayRetryReason.transient));
        }
      } catch (_) {
        if (isClosed || generation != _statusPollGeneration) return;
        _statusPollAttempts++;
        if (_statusPollAttempts >= _statusPollMaxAttempts) {
          _statusPollingTimer?.cancel();
          emit(const PayProcessPayRetry(PayRetryReason.transient));
          return;
        }
        _statusPollInFlight = false;
      }
    });
  }

  @override
  Future<void> close() {
    _statusPollingTimer?.cancel();
    return super.close();
  }
}
