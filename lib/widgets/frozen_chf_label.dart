import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/io/format_frozen_chf.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/styles/currency.dart';

String referralPayoutFrozenLine({
  required BuildContext context,
  required String raw,
  required Currency currency,
  required bool hideAmounts,
}) {
  final s = S.of(context);
  final parts = splitFrozenFiatData(raw);
  if (currency == Currency.eur && parts.eur != null) {
    return s.referralPayoutAmount(
      Currency.eur.code,
      hideAmounts ? '***.**' : parts.eur!,
    );
  }
  return s.referralPayoutChf(hideAmounts ? '***.**' : parts.chf);
}

/// Frozen CHF line for referral prizes. Honors [SettingsState.hideAmounts].
class FrozenChfLabel extends StatelessWidget {
  final String raw;

  const FrozenChfLabel({super.key, required this.raw});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Text(
          referralPayoutFrozenLine(
            context: context,
            raw: raw,
            currency: state.currency,
            hideAmounts: state.hideAmounts,
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: RealUnitColors.neutral500),
        );
      },
    );
  }
}
