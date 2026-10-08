import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_process/pay_process_cubit.dart';
import 'package:realunit_wallet/screens/transaction_history/completed_transaction.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/route_animation_gate.dart';

class PayProcessPage extends StatelessWidget {
  final String paymentLinkId;
  final String quoteId;
  final SwapPaymentInfo swap;

  const PayProcessPage({
    super.key,
    required this.paymentLinkId,
    required this.quoteId,
    required this.swap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PayProcessCubit(
        payService: getIt<RealUnitPayService>(),
        appStore: getIt<AppStore>(),
        paymentLinkId: paymentLinkId,
        quoteId: quoteId,
        swap: swap,
      ),
      child: RouteAnimationGate(
        onSettled: (c) => c.read<PayProcessCubit>().start(),
        child: const PayProcessView(),
      ),
    );
  }
}

class PayProcessCompleted {
  final Transaction transaction;
  final String walletAddress;
  const PayProcessCompleted({
    required this.transaction,
    required this.walletAddress,
  });
}

class PayProcessView extends StatelessWidget {
  const PayProcessView({
    super.key,
    this.resolveCompleted = resolveCompletedTransaction,
  });

  final CompletedTransactionResolver resolveCompleted;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PayProcessCubit, PayProcessState>(
      listenWhen: (previous, current) =>
          current is PayProcessSuccess ||
          current is PayProcessFailure ||
          current is PayProcessPayRetry,
      listener: (context, state) async {
        if (state is PayProcessSuccess) {
          final completed = await resolveCompleted(
            CompletedTransactionRequest(
              txHash: state.txHash,
              amount: BigInt.from(state.shareAmount),
              receiverAddress: kReferralPayoutSenderAddress,
              // The shares were sold to pay a bill: the detail page offers the sale receipt
              // and the payment receipt.
              category: TransferCategory.payment,
            ),
          );
          if (context.mounted) {
            Navigator.of(context).pop(
              PayProcessCompleted(
                transaction: completed.transaction,
                walletAddress: completed.walletAddress,
              ),
            );
          }
        } else if (state is PayProcessPayRetry) {
          // The confirm may already have been sent. This payment leaves no CHF.
          // Retry sends the same delegation again.
          await _showRetrySheet(context, state);
        } else if (state is PayProcessFailure) {
          await _showResultSheet(
            context,
            icon: Icons.error_rounded,
            title: S.of(context).payFailureTitle,
            description: _failureMessage(context, state),
            swapCompleted: context.read<PayProcessCubit>().swapCompleted,
          );
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: state is! PayProcessSuccess,
          child: Scaffold(
            appBar: AppBar(title: Text(S.of(context).pay)),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 24,
                  children: [
                    const CupertinoActivityIndicator(radius: 16),
                    Text(
                      _progressLabel(context, state),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _progressLabel(BuildContext context, PayProcessState state) => switch (state) {
    PayProcessInitial() || PayProcessPreparingSwap() => S.of(context).payPreparingSwap,
    PayProcessWaitingForEth() => S.of(context).payWaitingForEth,
    PayProcessSwapping() => S.of(context).paySwapping,
    PayProcessRefreshingQuote() => S.of(context).payRefreshingQuote,
    PayProcessPaying() => S.of(context).payPaying,
    PayProcessAwaitingSettlement() => S.of(context).payAwaitingSettlement,
    PayProcessSuccess() => S.of(context).paySuccess,
    PayProcessPayRetry() => S.of(context).payRetryTitle,
    PayProcessFailure() => S.of(context).payFailureTitle,
  };

  String _failureMessage(BuildContext context, PayProcessFailure state) {
    final apiText = state.message;
    if (apiText != null && apiText.isNotEmpty) {
      return apiText;
    }
    return switch (state.reason) {
      PayProcessFailureReason.insufficientEth => S.of(context).payFailureInsufficientEth,
      PayProcessFailureReason.signatureUnsupported => S.of(context).payFailureSignatureUnsupported,
      PayProcessFailureReason.payUnavailable => S.of(context).payFailurePayUnavailable,
      PayProcessFailureReason.bitboxRequired => S.of(context).payFailureBitboxRequired,
      PayProcessFailureReason.generic => S.of(context).payFailureGeneric,
    };
  }

  String _retryMessage(BuildContext context, PayProcessPayRetry state) {
    final apiText = state.message;
    if (apiText != null && apiText.isNotEmpty) {
      return apiText;
    }
    return switch (state.reason) {
      PayRetryReason.transient => S.of(context).payRetryTransient,
    };
  }

  Future<void> _showResultSheet(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool swapCompleted,
  }) async {
    await waitForIncomingRouteAnimation(context);
    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: [
              Icon(icon, color: RealUnitColors.realUnitBlue, size: 64),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RealUnitColors.neutral500,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context).close),
              ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted) Navigator.of(context).pop(swapCompleted);
  }

  /// Recovery sheet when a pay confirm did not finish. This payment leaves no
  /// CHF in the wallet. The primary action ([PayProcessCubit.retryPay]) sends
  /// the same delegation again and can sell REALU if the first confirm did not
  /// arrive.
  Future<void> _showRetrySheet(
    BuildContext context,
    PayProcessPayRetry state,
  ) async {
    await waitForIncomingRouteAnimation(context);
    if (!context.mounted) {
      return;
    }

    final cubit = context.read<PayProcessCubit>();
    // The sheet returns true when the user retries (keep the page) and false
    // when they close (leave the flow); a barrier dismissal yields null.
    final retry = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: [
              const Icon(
                Icons.replay_rounded,
                color: RealUnitColors.realUnitBlue,
                size: 64,
              ),
              Text(
                S.of(sheetContext).payRetryTitle,
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              Text(
                _retryMessage(sheetContext, state),
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: RealUnitColors.neutral500,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(S.of(sheetContext).payRetryButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(S.of(sheetContext).close),
              ),
            ],
          ),
        ),
      ),
    );

    if (retry == true) {
      // Send the same delegation again. Keep the page so the next attempt
      // surfaces its own result.
      await cubit.retryPay();
    } else if (context.mounted) {
      // Closed: leave the flow. This payment did not leave CHF in the wallet.
      // true tells the quote page not to offer Pay again on the same quote.
      Navigator.of(context).pop(true);
    }
  }
}
