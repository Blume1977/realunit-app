import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/io/format_frozen_chf.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_detail_page.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/frozen_chf_label.dart';
import 'package:realunit_wallet/widgets/hide_amount_text.dart';
import 'package:realunit_wallet/widgets/transaction_title_label.dart';

class TransactionHistoryRow extends StatelessWidget {
  final Transaction transaction;
  final String walletAddress;

  const TransactionHistoryRow({
    super.key,
    required this.transaction,
    required this.walletAddress,
  });

  @override
  Widget build(BuildContext context) {
    return TransactionHistoryRowView(
      transaction: transaction,
      isOutbound: transaction.isOutbound(walletAddress),
      walletAddress: walletAddress,
    );
  }
}

class TransactionHistoryRowView extends StatelessWidget {
  const TransactionHistoryRowView({
    super.key,
    required this.transaction,
    required this.isOutbound,
    this.walletAddress = '',
  });

  final Transaction transaction;
  final bool isOutbound;
  final String walletAddress;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: () => openTransactionDetail(context, transaction, walletAddress),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10.0,
            children: [
              isOutbound
                  ? Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: RealUnitColors.brand200,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: const Icon(
                        Icons.horizontal_rule_rounded,
                        color: RealUnitColors.darkBlue,
                      ),
                    )
                  : Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: RealUnitColors.brand200,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: ExcludeSemantics(
                        excluding:
                            transaction.type == TransactionTypes.referralPayout,
                        child: const Icon(
                          Icons.add,
                          color: RealUnitColors.darkBlue,
                        ),
                      ),
                    ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.type == TransactionTypes.referralPayout
                          ? S.of(context).referralPayout
                          : transactionTitleLabel(
                              context,
                              transaction,
                              isOutbound: isOutbound,
                            ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 20 / 16,
                      ),
                    ),
                    Text(
                      transaction.type == TransactionTypes.referralPayout
                          ? DateFormat(
                              'dd.MM.yyyy | H:mm',
                            ).format(transaction.timestamp.toLocal())
                          : DateFormat(
                              'MMM dd, yyyy | H:mm',
                            ).format(transaction.timestamp.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: RealUnitColors.neutral500,
                      ),
                    ),
                    if (transaction.type == TransactionTypes.referralPayout &&
                        transaction.data != null &&
                        transaction.data!.isNotEmpty)
                      FrozenChfLabel(raw: transaction.data!),
                  ],
                ),
              ),
              HideAmountText(
                leadingSymbol:
                    isOutbound &&
                        transaction.type != TransactionTypes.referralPayout
                    ? '-'
                    : '+',
                amount: transaction.amount,
                decimals: transaction.asset.decimals,
                fractionalDigits: 0,
                trimZeros: false,
                trailingSymbol: transaction.asset.symbol,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 20 / 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (transaction.type != TransactionTypes.referralPayout) return row;
    final s = S.of(context);
    final settings = context.watch<SettingsBloc>().state;
    final date = DateFormat(
      'dd.MM.yyyy | H:mm',
    ).format(transaction.timestamp.toLocal());
    final chf = transaction.data;
    return Semantics(
      container: true,
      label: referralPayoutSemanticsLabel(
        title: s.referralPayout,
        date: date,
        amount: referralPayoutAmountText(
          hideAmounts: settings.hideAmounts,
          amount: transaction.amount,
          decimals: transaction.asset.decimals,
          symbol: transaction.asset.symbol,
        ),
        chfLine: chf != null && chf.isNotEmpty
            ? referralPayoutFrozenLine(
                context: context,
                raw: chf,
                currency: settings.currency,
                hideAmounts: settings.hideAmounts,
              )
            : null,
      ),
      child: ExcludeSemantics(child: row),
    );
  }
}
