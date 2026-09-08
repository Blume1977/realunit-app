import 'package:realunit_wallet/packages/service/dfx/models/referral/referral_json_list.dart';
import 'package:realunit_wallet/packages/utils/format_fixed.dart';

/// Formats the CHF amount frozen at credit for history and dashboard rows.
/// The ARB string already prefixes `CHF`, so this is the numeric part only.
/// A DE/CH decimal comma (`246,5`), Swiss thousands apostrophes
/// (`1'246.50`), and a `CHF` prefix are accepted.
String formatFrozenChfAmount(String raw) {
  final normalized = normalizeReferralDecimalString(raw);
  if (normalized == null) return raw;
  return _roundHalfUpToCents(normalized);
}

/// Half-up to two decimals from a decimal string. `double` + `toStringAsFixed(2)`
/// can turn `1.005` into `1.00`.
String _roundHalfUpToCents(String normalized) {
  final negative = normalized.startsWith('-');
  var value = negative ? normalized.substring(1) : normalized;
  final dot = value.indexOf('.');
  var whole = dot < 0 ? value : value.substring(0, dot);
  var frac = dot < 0 ? '' : value.substring(dot + 1);
  if (whole.isEmpty) whole = '0';
  if (frac.length <= 2) {
    return '${negative ? '-' : ''}$whole.${frac.padRight(2, '0')}';
  }
  final roundUp = frac.codeUnitAt(2) >= 53; // '5'
  var cents = int.parse(whole) * 100 + int.parse(frac.substring(0, 2));
  if (roundUp) cents += 1;
  final sign = negative && cents != 0 ? '-' : '';
  return '$sign${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

/// Matches [HideAmountText] for a whole-REALU prize (+ 20 REALU / + ***.**).
String referralPayoutAmountText({
  required bool hideAmounts,
  required BigInt amount,
  required int decimals,
  required String symbol,
}) {
  if (hideAmounts) return '+ ***.**';
  return '+ ${formatFixed(amount, decimals, fractionalDigits: 0, trimZeros: false)} $symbol';
}

/// One VoiceOver name: title, date, frozen CHF, amount.
String referralPayoutSemanticsLabel({
  required String title,
  required String date,
  required String amount,
  String? chfLine,
}) {
  return [
    title,
    date,
    if (chfLine != null && chfLine.isNotEmpty) chfLine,
    amount,
  ].join('. ');
}
