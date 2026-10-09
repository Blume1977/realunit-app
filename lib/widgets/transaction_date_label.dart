import 'package:intl/intl.dart';

/// Formats the date of a transaction the same way everywhere it is shown: the Swiss
/// numeric notation in device-local time, with the time of day unless [withTime] is false.
String transactionDateLabel(DateTime timestamp, {bool withTime = true}) {
  final pattern = withTime ? 'dd.MM.yyyy | H:mm' : 'dd.MM.yyyy';
  return DateFormat(pattern).format(timestamp.toLocal());
}
