import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/io/format_frozen_chf.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/frozen_chf_label.dart';
import 'package:realunit_wallet/widgets/hide_amount_text.dart';
import 'package:realunit_wallet/widgets/transaction_title_label.dart';

class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final String walletAddress;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.walletAddress,
  });

  bool get _isOutbound => transaction.isOutbound(walletAddress);

  @override
  Widget build(BuildContext context) =>
      transaction.type == TransactionTypes.referralPayout
      ? ReferralPayoutTransactionRow(transaction: transaction)
      : InkWell(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: RealUnitColors.basic.white,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 10.0,
                  children: [
                    _isOutbound
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
                            child: const Icon(
                              Icons.add,
                              color: RealUnitColors.darkBlue,
                            ),
                          ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transactionTitleLabel(context, transaction, isOutbound: _isOutbound),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 20 / 16,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy | H:mm').format(transaction.timestamp.toLocal()),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color: RealUnitColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    HideAmountText(
                      leadingSymbol: _isOutbound ? '-' : '+',
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
          ),
        );
}

class ReferralPayoutTransactionRow extends StatelessWidget {
  final Transaction transaction;

  const ReferralPayoutTransactionRow({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final chf = transaction.data;
    final s = S.of(context);
    final date = DateFormat('dd.MM.yyyy | H:mm').format(
      transaction.timestamp.toLocal(),
    );
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) {
        final amount = referralPayoutAmountText(
          hideAmounts: settings.hideAmounts,
          amount: transaction.amount,
          decimals: transaction.asset.decimals,
          symbol: transaction.asset.symbol,
        );
        final chfLine = chf != null && chf.isNotEmpty
            ? referralPayoutFrozenLine(
                context: context,
                raw: chf,
                currency: settings.currency,
                hideAmounts: settings.hideAmounts,
              )
            : null;
        return Semantics(
          container: true,
          label: referralPayoutSemanticsLabel(
            title: s.referralPayout,
            date: date,
            amount: amount,
            chfLine: chfLine,
          ),
          child: ExcludeSemantics(
            child: InkWell(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: RealUnitColors.basic.white,
                ),
                child: Row(
                  spacing: 10.0,
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: RealUnitColors.brand200,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: RealUnitColors.darkBlue,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.referralPayout,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 20 / 16,
                            ),
                          ),
                          Text(
                            date,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 16 / 12,
                              color: RealUnitColors.neutral500,
                            ),
                          ),
                          if (chf != null && chf.isNotEmpty)
                            FrozenChfLabel(raw: chf),
                        ],
                      ),
                    ),
                    HideAmountText(
                      leadingSymbol: '+',
                      amount: transaction.amount,
                      decimals: transaction.asset.decimals,
                      fractionalDigits: 0,
                      trimZeros: false,
                      trailingSymbol: transaction.asset.symbol,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 20 / 16,
                      ),
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
}
