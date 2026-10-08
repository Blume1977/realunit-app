import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/dfx_transaction.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pdf_service.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/completed_transaction.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/receipt/transaction_history_receipt_cubit.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/frozen_chf_label.dart';
import 'package:realunit_wallet/widgets/hide_amount_text.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';
import 'package:realunit_wallet/widgets/transaction_date_label.dart';
import 'package:realunit_wallet/widgets/transaction_title_label.dart';

class TransactionDetailArgs {
  final Transaction transaction;
  final String walletAddress;
  final bool returnToDashboard;
  const TransactionDetailArgs({
    required this.transaction,
    required this.walletAddress,
    this.returnToDashboard = false,
  });
}

void openTransactionDetail(
  BuildContext context,
  Transaction transaction,
  String walletAddress,
) {
  context.pushNamed(
    AppRoutes.transactionDetail,
    extra: TransactionDetailArgs(
      transaction: transaction,
      walletAddress: walletAddress,
    ),
  );
}

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key, required this.args});

  final TransactionDetailArgs args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TransactionHistoryReceiptCubit(getIt<RealUnitPdfService>()),
      child: TransactionDetailView(args: args),
    );
  }
}

enum _PendingReceipt { realunit, exchange, payment }

class TransactionDetailView extends StatefulWidget {
  const TransactionDetailView({super.key, required this.args});
  final TransactionDetailArgs args;

  @override
  State<TransactionDetailView> createState() => _TransactionDetailViewState();
}

class _TransactionDetailViewState extends State<TransactionDetailView> {
  _PendingReceipt? _pending;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      TransactionHistoryReceiptCubit,
      TransactionHistoryReceiptState
    >(
      listener: (context, state) async {
        if (state is TransactionHistoryReceiptFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: RealUnitColors.status.red600,
            ),
          );
        }
        if (state is TransactionHistoryReceiptSuccess) {
          await OpenFile.open(state.receiptPath);
        }
      },
      builder: (context, state) {
        final transaction = widget.args.transaction;
        final fieldRows = _fieldRows(context);
        final content = Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 16.0,
            children: [
              Column(
                crossAxisAlignment: .start,
                children: [
                  HideAmountText(
                    leadingSymbol: _leadingSymbol(),
                    amount: transaction.amount,
                    decimals: transaction.asset.decimals,
                    fractionalDigits: _fractionalDigits(),
                    trimZeros: false,
                    trailingSymbol: transaction.asset.symbol,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    transactionDateLabel(transaction.timestamp),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: fieldRows,
                  ),
                ),
              if (transaction.type != TransactionTypes.referralPayout &&
                  usableTxHash(transaction.txId) != null) ...[
                Text(
                  S.of(context).saleReceiptSheetTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Column(
                  spacing: 12,
                  children: _receiptButtons(context, state),
                ),
              ],
            ],
          ),
        );
        if (widget.args.returnToDashboard) {
          return Scaffold(
            appBar: AppBar(title: Text(_title(context))),
            body: SafeArea(
              child: ScrollableActionsLayout(
                body: content,
                actions: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: AppFilledButton(
                      label: S.of(context).transactionDetailBackToMain,
                      onPressed: () =>
                          context.goNamed(AppRoutes.dashboard),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final scrollView = SafeArea(
          child: SingleChildScrollView(
            child: content,
          ),
        );
        return Scaffold(
          appBar: AppBar(title: Text(_title(context))),
          body: scrollView,
        );
      },
    );
  }

  String _title(BuildContext context) {
    final transaction = widget.args.transaction;
    final s = S.of(context);
    return switch (transaction.type) {
      TransactionTypes.referralPayout => s.referralPayout,
      _ => transactionTitleLabel(
        context,
        transaction,
        isOutbound: transaction.isOutbound(widget.args.walletAddress),
      ),
    };
  }

  String _leadingSymbol() {
    final transaction = widget.args.transaction;
    if (transaction.type == TransactionTypes.referralPayout) return '+';
    return transaction.isOutbound(widget.args.walletAddress) ? '-' : '+';
  }

  int _fractionalDigits() {
    return 0;
  }

  List<Widget> _fieldRows(BuildContext context) {
    final transaction = widget.args.transaction;
    final s = S.of(context);
    final rows = <Widget>[];

    void addField(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(_TransactionDetailField(label: label, value: value));
    }

    if (transaction is DfxTransaction) {
      final hideAmounts = context.watch<SettingsBloc>().state.hideAmounts;
      // A sale has two different amounts: the proceeds of the share sale and what DFX pays out
      // after its fee. Naming them keeps them apart from each other and from the two receipts.
      final isSale = transaction.category == TransferCategory.sale;
      final inputLabel = isSale ? s.saleProceedsIn : s.amountIn;
      final outputLabel = isSale ? s.payoutIn : s.amountIn;
      void addLeg(String label, double? amount, String? asset) {
        if (amount == null || asset == null || asset.isEmpty) return;
        if (asset == transaction.asset.symbol) return;
        addField(
          '$label $asset',
          hideAmounts ? '***.**' : amount.toStringAsFixed(2),
        );
      }

      addLeg(inputLabel, transaction.inputAmount, transaction.inputAsset);
      addLeg(outputLabel, transaction.outputAmount, transaction.outputAsset);
    }

    addField(s.transactionDetailNote, transaction.note);

    if (transaction.type == TransactionTypes.referralPayout &&
        transaction.data != null &&
        transaction.data!.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: FrozenChfLabel(raw: transaction.data!),
          ),
        ),
      );
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

  List<Widget> _receiptButtons(
    BuildContext context,
    TransactionHistoryReceiptState state,
  ) {
    final isLoading = state is TransactionHistoryReceiptLoading;
    final transaction = widget.args.transaction;
    if (transaction.category == TransferCategory.sale) {
      return [
        AppFilledButton(
          variant: .primary,
          icon: Icons.file_download_outlined,
          label: S.of(context).saleReceiptRealunit,
          state: isLoading && _pending == .realunit ? .loading : .idle,
          onPressed: isLoading ? null : _onRealunitPressed,
        ),
        AppFilledButton(
          variant: .secondary,
          icon: Icons.file_download_outlined,
          label: S.of(context).saleReceiptExchange,
          state: isLoading && _pending == .exchange ? .loading : .idle,
          onPressed: isLoading ? null : _onExchangePressed,
        ),
      ];
    }
    // A payment is two acts with a receipt each: the sale of the shares (the regular sale
    // receipt) and the payment of the merchant's bill. Nothing is paid out, so no DFX payout.
    if (transaction.category == TransferCategory.payment) {
      return [
        AppFilledButton(
          variant: .primary,
          icon: Icons.file_download_outlined,
          label: S.of(context).paymentReceiptSale,
          state: isLoading && _pending == .realunit ? .loading : .idle,
          onPressed: isLoading ? null : _onRealunitPressed,
        ),
        AppFilledButton(
          variant: .secondary,
          icon: Icons.file_download_outlined,
          label: S.of(context).paymentReceiptPayment,
          state: isLoading && _pending == .payment ? .loading : .idle,
          onPressed: isLoading ? null : _onPaymentPressed,
        ),
      ];
    }
    return [
      AppFilledButton(
        variant: .primary,
        icon: Icons.file_download_outlined,
        label: S.of(context).transactionReceipt,
        state: isLoading ? .loading : .idle,
        onPressed: isLoading ? null : _onRealunitPressed,
      ),
    ];
  }

  void _onRealunitPressed() {
    final settings = context.read<SettingsBloc>().state;
    setState(() => _pending = .realunit);
    context.read<TransactionHistoryReceiptCubit>().generateReceipt(
      widget.args.transaction.txId,
      currency: settings.currency,
      language: settings.language,
    );
  }

  void _onPaymentPressed() {
    final settings = context.read<SettingsBloc>().state;
    setState(() => _pending = .payment);
    context.read<TransactionHistoryReceiptCubit>().generatePaymentReceipt(
      widget.args.transaction.txId,
      language: settings.language,
    );
  }

  void _onExchangePressed() {
    setState(() => _pending = .exchange);
    context.read<TransactionHistoryReceiptCubit>().generateExchangeReceipt(
      widget.args.transaction.txId,
    );
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
