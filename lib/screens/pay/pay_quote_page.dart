import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_quote/pay_quote_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_process_page.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_detail_page.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/route_animation_gate.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';

class PayQuotePage extends StatelessWidget {
  final String paymentLinkId;

  const PayQuotePage({super.key, required this.paymentLinkId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PayQuoteCubit(getIt<RealUnitPayService>(), paymentLinkId),
      child: RouteAnimationGate(
        onSettled: (c) => c.read<PayQuoteCubit>().load(),
        child: const PayQuoteView(),
      ),
    );
  }
}

class PayQuoteView extends StatelessWidget {
  const PayQuoteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).payQuoteTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: BlocBuilder<PayQuoteCubit, PayQuoteState>(
            builder: (context, state) => switch (state) {
              PayQuoteLoading() => const Center(
                child: CupertinoActivityIndicator(),
              ),
              PayQuoteReady() => _PayQuoteReadyView(state: state),
              PayQuoteExpired() => _PayQuoteMessage(
                message: S.of(context).payFailureQuoteExpired,
              ),
              PayQuoteUnavailable() => _PayQuoteMessage(
                message: S.of(context).payQuoteUnavailable,
              ),
              PayQuoteError(:final message) => _PayQuoteMessage(
                message: message.isNotEmpty
                    ? message
                    : S.of(context).payFailureGeneric,
                onRetry: () => context.read<PayQuoteCubit>().load(),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _PayQuoteReadyView extends StatefulWidget {
  final PayQuoteReady state;

  const _PayQuoteReadyView({required this.state});

  @override
  State<_PayQuoteReadyView> createState() => _PayQuoteReadyViewState();
}

class _PayQuoteReadyViewState extends State<_PayQuoteReadyView> {
  bool _navigating = false;
  Timer? _countdown;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _left(widget.state.expiresAt);
    if (_remaining > Duration.zero) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final left = _left(widget.state.expiresAt);
        setState(() => _remaining = left);
        if (left <= Duration.zero) _countdown?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  static Duration _left(DateTime expiresAt) {
    final left = expiresAt.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  static String _clock(Duration remaining) {
    final total = remaining.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining <= Duration.zero) {
      return _PayQuoteMessage(message: S.of(context).payFailureQuoteExpired);
    }
    final state = widget.state;
    final swap = state.swap;
    final feeChf = swap.ethereumTransactionFeeChf;
    final feeRealu = swap.ethereumTransactionFeeRealu;
    // The customer pays the network fee in REALU. DFX only fronts the gas.
    // A fee line is shown when the quote carries one. The signed quote itself
    // is not changed.
    final showFee = feeChf != null || feeRealu != null;
    final parts = _quoteParts(
      billChf: state.fiatAmount,
      shares: swap.amount,
      proceedsChf: swap.estimatedAmount,
      feeChf: feeChf ?? 0,
      feeRealu: feeRealu ?? 0,
    );
    final merchant = state.merchantName;
    final settings = context.watch<SettingsBloc>().state;
    final useEur = settings.currency == Currency.eur && state.hasEurReceipt;
    // The till asked for this franc amount. It stays on the requested row
    // even when the receipt shows the stored euro figures.
    final requestedChf = _chf(parts.billChf, 'CHF');
    final feeFiat = useEur ? _chf(state.feeEur!, 'EUR') : _chf(parts.feeChf, 'CHF');
    final roundingFiat = useEur ? _chf(state.roundingEur!, 'EUR') : _chf(parts.roundingChf, 'CHF');
    final totalFiat = useEur ? _chf(state.totalEur!, 'EUR') : _chf(parts.totalChf, 'CHF');
    return ScrollableActionsLayout(
      centerBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          if (merchant != null)
            Column(
              spacing: 2,
              children: [
                Text(
                  S.of(context).payQuoteMerchant,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RealUnitColors.neutral500,
                  ),
                ),
                Text(
                  merchant,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          Column(
            spacing: 4,
            children: [
              Text(
                S.of(context).youSell,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RealUnitColors.neutral500,
                ),
              ),
              Text(
                _wholeRealu(swap.amount),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          _ReceiptCard(
            children: [
              _AmountRow(
                label: S.of(context).payQuoteRequested,
                realu: _realu(parts.billRealu),
                chf: requestedChf,
                also: useEur ? _chf(state.billEur!, 'EUR') : null,
              ),
              if (showFee)
                _AmountRow(
                  label: S.of(context).payQuoteRealuFees,
                  realu: _realu(parts.feeRealu),
                  chf: feeFiat,
                ),
              _AmountRow(
                label: S.of(context).payQuoteRounding,
                realu: _realu(parts.roundingRealu),
                chf: roundingFiat,
              ),
              _AmountRow(
                label: S.of(context).payQuoteTotal,
                realu: _realu(parts.totalRealu),
                chf: totalFiat,
              ),
            ],
          ),
          Text(
            _clock(_remaining),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        AppFilledButton(
          label: S.of(context).payConfirmButton,
          state: _navigating
              ? FilledButtonState.loading
              : FilledButtonState.idle,
          onPressed: _navigating
              ? null
              : () async {
                  if (_navigating) return;
                  setState(() => _navigating = true);
                  final navigator = Navigator.of(context);
                  Object? swapCompleted = false;
                  try {
                    swapCompleted = await navigator.push<Object>(
                      MaterialPageRoute<Object>(
                        builder: (_) => PayProcessPage(
                          paymentLinkId: state.paymentLinkId,
                          quoteId: state.quoteId,
                          swap: state.swap,
                        ),
                      ),
                    );
                  } finally {
                    // Only a typed pre-swap failure pops `false` and re-enables
                    // Pay. `true` (swap ran) and `null` (AppBar / system back)
                    // both leave this quote so REALU cannot be sold twice.
                    if (mounted && swapCompleted == false) {
                      setState(() => _navigating = false);
                    }
                  }
                  if (!context.mounted) return;
                  if (swapCompleted is PayProcessCompleted) {
                    context.goNamed(
                      AppRoutes.transactionDetail,
                      extra: TransactionDetailArgs(
                        transaction: swapCompleted.transaction,
                        walletAddress: swapCompleted.walletAddress,
                        returnToDashboard: true,
                      ),
                    );
                  } else if (swapCompleted != false) {
                    navigator.pop();
                  }
                },
        ),
      ],
    );
  }
}

String _chf(double amount, String asset) =>
    '${amount.toStringAsFixed(2)} $asset';

String _wholeRealu(double shares) =>
    '${shares.toStringAsFixed(0)} ${realUnitAsset.symbol}';

/// At least two decimals, up to eight, without a tail of zeros.
String _realu(double amount) {
  final rounded = (amount * 1e8).round() / 1e8;
  var text = rounded.toStringAsFixed(8);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  if (!text.contains('.')) {
    text = '$text.00';
  } else if (text.split('.').last.length == 1) {
    text = '${text}0';
  }
  return '$text ${realUnitAsset.symbol}';
}

class _QuoteParts {
  final double billChf;
  final double billRealu;
  final double feeChf;
  final double feeRealu;
  final double roundingChf;
  final double roundingRealu;
  final double totalChf;
  final double totalRealu;

  const _QuoteParts({
    required this.billChf,
    required this.billRealu,
    required this.feeChf,
    required this.feeRealu,
    required this.roundingChf,
    required this.roundingRealu,
    required this.totalChf,
    required this.totalRealu,
  });
}

/// Splits the sold shares into the bill, the fee, and the whole-share round-up.
/// The round-up is the remainder, so the three REALU lines add up to [shares].
_QuoteParts _quoteParts({
  required double billChf,
  required double shares,
  required double proceedsChf,
  required double feeChf,
  required double feeRealu,
}) {
  final price = shares == 0 ? 0.0 : proceedsChf / shares;
  final billRealu = price == 0 ? 0.0 : billChf / price;
  final roundingChf = proceedsChf - billChf - feeChf;
  final roundingRealu = shares - billRealu - feeRealu;
  return _QuoteParts(
    billChf: billChf,
    billRealu: billRealu,
    feeChf: feeChf,
    feeRealu: feeRealu,
    roundingChf: roundingChf,
    roundingRealu: roundingRealu,
    totalChf: billChf + feeChf + roundingChf,
    totalRealu: billRealu + feeRealu + roundingRealu,
  );
}

class _ReceiptCard extends StatelessWidget {
  final List<Widget> children;

  const _ReceiptCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: RealUnitColors.neutral200,
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: RealUnitColors.neutral50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: rows),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String realu;
  final String chf;
  final String? also;

  const _AmountRow({
    required this.label,
    required this.realu,
    required this.chf,
    this.also,
  });

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35);
    final fiatStyle = small?.copyWith(color: RealUnitColors.neutral600);
    final Widget fiat = also == null
        ? Text(chf, textAlign: TextAlign.end, softWrap: true, style: fiatStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(chf, textAlign: TextAlign.end, softWrap: true, style: fiatStyle),
              Text(also!, textAlign: TextAlign.end, softWrap: true, style: fiatStyle),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text(
            label,
            softWrap: true,
            style: small?.copyWith(color: RealUnitColors.neutral500),
          ),
          Row(
            spacing: 12,
            children: [
              Flexible(
                child: Text(
                  realu,
                  softWrap: true,
                  style: small?.copyWith(
                    color: RealUnitColors.realUnitBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(child: fiat),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayQuoteMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _PayQuoteMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: RealUnitColors.neutral500),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('payQuoteRetryButton'),
              onPressed: onRetry,
              child: Text(S.of(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}
