import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_process/pay_process_cubit.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_result_sheet.dart';
import 'package:realunit_wallet/screens/transaction_history/completed_transaction.dart';
import 'package:realunit_wallet/setup/di.dart';
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
          current is PayProcessNotOffered,
      listener: (context, state) async {
        if (state is PayProcessNotOffered) {
          // Not a failed payment, so there is no result sheet. Null leaves
          // the quote the same way system back does, and Pay is not offered
          // again on that quote.
          Navigator.of(context).pop();
          return;
        }
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
        final sheetOpen = state is PayProcessFailure;

        return PopScope(
          canPop: state is! PayProcessSuccess,
          child: Scaffold(
            appBar: AppBar(title: Text(S.of(context).pay)),
            body: SafeArea(
              child: Center(
                child: sheetOpen
                    ? const SizedBox.shrink()
                    : Column(
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
    PayProcessInitial() ||
    PayProcessPreparingSwap() ||
    PayProcessNotOffered() => S.of(context).payPreparingSwap,
    PayProcessWaitingForEth() => S.of(context).payWaitingForEth,
    PayProcessSwapping() => S.of(context).paySwapping,
    PayProcessRefreshingQuote() => S.of(context).payRefreshingQuote,
    PayProcessPaying() => S.of(context).payPaying,
    PayProcessAwaitingSettlement() => S.of(context).payAwaitingSettlement,
    PayProcessSuccess() => S.of(context).paySuccess,
    PayProcessFailure() => S.of(context).payFailureTitle,
  };

  String _failureMessage(BuildContext context, PayProcessFailure state) {
    final apiText = state.message;
    if (apiText != null && apiText.isNotEmpty) {
      return apiText;
    }
    return switch (state.reason) {
      PayProcessFailureReason.generic => S.of(context).payFailureGeneric,
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
      isScrollControlled: true,
      isDismissible: false,
      builder: (sheetContext) => PayResultSheet(
        icon: icon,
        title: title,
        description: description,
        closeLabel: S.of(sheetContext).close,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
    if (context.mounted) Navigator.of(context).pop(swapCompleted);
  }
}
