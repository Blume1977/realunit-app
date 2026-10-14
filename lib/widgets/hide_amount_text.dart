import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/utils/format_fixed.dart';
import 'package:realunit_wallet/packages/utils/group_swiss_digits.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';

class HideAmountText extends StatelessWidget {
  const HideAmountText({
    super.key,
    this.style,
    required this.amount,
    this.decimals = 18,
    this.fractionalDigits = 2,
    this.trimZeros = false,
    this.leadingSymbol = '€',
    this.trailingSymbol = '',
    this.textAlign,
  });

  final String leadingSymbol;
  final String trailingSymbol;
  final TextStyle? style;
  final BigInt amount;
  final int decimals;
  final int fractionalDigits;
  final bool trimZeros;
  final TextAlign? textAlign;

  String _formatAmount() {
    if (amount == BigInt.zero) {
      return '--.--';
    }
    return groupSwissDigits(
      formatFixed(amount, decimals, fractionalDigits: fractionalDigits, trimZeros: trimZeros),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (context, state) => Text(
      state.hideAmounts
          ? "${leadingSymbol.isNotEmpty ? "$leadingSymbol " : ""}***.**"
          : "${leadingSymbol.isNotEmpty ? "$leadingSymbol " : ""}${_formatAmount()} $trailingSymbol",
      style: style,
      textAlign: textAlign,
    ),
  );
}
