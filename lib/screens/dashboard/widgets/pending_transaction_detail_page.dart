import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';

class PendingTransactionDetailArgs {
  final TransactionDto transaction;
  const PendingTransactionDetailArgs({required this.transaction});
}

void openPendingTransactionDetail(
  BuildContext context,
  TransactionDto transaction,
) {
  context.pushNamed(
    AppRoutes.transactionDetail,
    extra: PendingTransactionDetailArgs(transaction: transaction),
  );
}

class PendingTransactionDetailPage extends StatelessWidget {
  const PendingTransactionDetailPage({super.key, required this.args});
  final PendingTransactionDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final transaction = args.transaction;
    final amountText = _amountText();
    final fieldRows = _fieldRows(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title(context))),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 16,
              children: [
                Column(
                  crossAxisAlignment: .start,
                  children: [
                    if (amountText != null)
                      Text(
                        amountText,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (transaction.date != null)
                      Text(
                        DateFormat(
                          'MMM dd, yyyy | H:mm',
                        ).format(transaction.date!.toLocal()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RealUnitColors.neutral500,
                        ),
                      ),
                    Text(
                      transaction.state == .waitingForPayment
                          ? S.of(context).transactionWaitingForPayment
                          : S.of(context).transactionPending,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RealUnitColors.neutral500,
                      ),
                    ),
                  ],
                ),
                if (fieldRows.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: RealUnitColors.basic.white,
                      border: Border.all(
                        width: 1,
                        color: RealUnitColors.neutral200,
                      ),
                      borderRadius: .circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: fieldRows,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    final s = S.of(context);
    return switch (args.transaction.type) {
      .buy => s.transactionBuy,
      .sell => s.transactionSell,
      .swap => s.transactionSwap,
      .referral => s.referralPayout,
      null => s.transactionPending,
    };
  }

  String? _amountText() {
    final transaction = args.transaction;
    if (transaction.inputAmount != null && transaction.inputAsset != null) {
      return '${transaction.inputAmount!.toStringAsFixed(2)} ${transaction.inputAsset}';
    }
    if (transaction.outputAmount != null && transaction.outputAsset != null) {
      return '${transaction.outputAmount!.toStringAsFixed(2)} ${transaction.outputAsset}';
    }
    return null;
  }

  List<Widget> _fieldRows(BuildContext context) {
    final transaction = args.transaction;
    final s = S.of(context);
    final rows = <Widget>[];

    void addField(String label, String value) {
      rows.add(_TransactionDetailField(label: label, value: value));
    }

    final inputComplete =
        transaction.inputAmount != null && transaction.inputAsset != null;
    final outputComplete =
        transaction.outputAmount != null && transaction.outputAsset != null;
    if (inputComplete || outputComplete) {
      final primaryIsInput = inputComplete;
      final otherAmount = primaryIsInput
          ? transaction.outputAmount
          : transaction.inputAmount;
      final otherAsset = primaryIsInput
          ? transaction.outputAsset
          : transaction.inputAsset;
      final primaryAsset = primaryIsInput
          ? transaction.inputAsset
          : transaction.outputAsset;
      if (otherAmount != null &&
          otherAsset != null &&
          otherAsset != primaryAsset) {
        addField(
          '${s.amountIn} $otherAsset',
          otherAmount.toStringAsFixed(2),
        );
      }
    }

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(const Divider(color: RealUnitColors.neutral200));
      }
    }
    return children;
  }
}

class _TransactionDetailField extends StatelessWidget {
  const _TransactionDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RealUnitColors.realUnitBlue,
            ),
          ),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
