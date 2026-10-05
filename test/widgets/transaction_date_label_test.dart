import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/widgets/transaction_date_label.dart';

void main() {
  group('transactionDateLabel', () {
    test('writes the date in the Swiss notation with the time of day', () {
      expect(transactionDateLabel(DateTime(2026, 5, 20, 14, 32)), '20.05.2026 | 14:32');
    });

    test('pads day and month and keeps the hour without a leading zero', () {
      expect(transactionDateLabel(DateTime(2026, 1, 3, 9, 5)), '03.01.2026 | 9:05');
    });

    test('leaves the time out on request', () {
      expect(transactionDateLabel(DateTime(2026, 5, 20, 14, 32), withTime: false), '20.05.2026');
    });

    test('shows a UTC timestamp in device-local time', () {
      final utc = DateTime.utc(2026, 5, 20, 12);
      final local = utc.toLocal();

      expect(transactionDateLabel(utc), transactionDateLabel(local));
      expect(transactionDateLabel(utc), contains('| ${local.hour}:00'));
    });
  });
}
