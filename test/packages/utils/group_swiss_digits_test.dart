import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/utils/group_swiss_digits.dart';

void main() {
  group('groupSwissDigits', () {
    test('groups a decimal the Swiss way', () {
      expect(groupSwissDigits('332323.12'), "332'323.12");
    });

    test('groups the CHF holding total', () {
      expect(groupSwissDigits('130346.82'), "130'346.82");
    });

    test('groups a four-digit decimal', () {
      expect(groupSwissDigits('11016.00'), "11'016.00");
    });

    test('groups whole share counts', () {
      expect(groupSwissDigits('85194'), "85'194");
      expect(groupSwissDigits('7200'), "7'200");
      expect(groupSwissDigits('77993'), "77'993");
      expect(groupSwissDigits('135000'), "135'000");
    });

    test('leaves numbers below 1000 unchanged', () {
      expect(groupSwissDigits('1.53'), '1.53');
      expect(groupSwissDigits('999'), '999');
      expect(groupSwissDigits('0.50'), '0.50');
      expect(groupSwissDigits('0'), '0');
    });

    test('groups the thousands boundary and millions', () {
      expect(groupSwissDigits('1000'), "1'000");
      expect(groupSwissDigits('1000000.00'), "1'000'000.00");
    });

    test('keeps a leading minus on the grouped number', () {
      expect(groupSwissDigits('-11016.00'), "-11'016.00");
    });

    test('leaves sentinels and a leading plus unchanged', () {
      expect(groupSwissDigits('--.--'), '--.--');
      expect(groupSwissDigits('***.**'), '***.**');
      expect(groupSwissDigits(''), '');
      expect(groupSwissDigits('+11016.00'), '+11016.00');
    });
  });
}
