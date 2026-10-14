import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/utils/format_fixed.dart';

void main() {
  group('formatFixed', () {
    group('formatFixed, no fractional digits and trimming zeros', () {
      test(
        'should format 1000000 into 1',
        () => expect(formatFixed(BigInt.parse('1000000'), 6), '1'),
      );

      test(
        'should format 1000001 into 1.000001',
        () => expect(formatFixed(BigInt.parse('1000001'), 6), '1.000001'),
      );
    });

    group('formatFixed, different fractional digits and trimming zeros', () {
      test(
        'should format 1000001 into 1',
        () => expect(formatFixed(BigInt.parse('1000001'), 6, fractionalDigits: 5), '1'),
      );

      test(
        'should format 1000000 into 1, fractionalDigits > decimals',
        () => expect(formatFixed(BigInt.parse('1000000'), 6, fractionalDigits: 12), '1'),
      );

      test(
        'should format 1000001 into 1.000001, fractionalDigits > decimals',
        () => expect(
          formatFixed(BigInt.parse('1000001'), 6, fractionalDigits: 12),
          '1.000001',
        ),
      );
    });

    group('formatFixed, less fractional digits and not trimming zeros', () {
      test(
        'should format 1000000 into 1.000000',
        () => expect(
          formatFixed(BigInt.parse('1000000'), 6, trimZeros: false),
          '1.000000',
        ),
      );

      test(
        'should format 1000001 into 1.00000',
        () => expect(
          formatFixed(BigInt.parse('1000001'), 6, fractionalDigits: 5, trimZeros: false),
          '1.00000',
        ),
      );

      test(
        'should format 1000000 into 1.000000',
        () => expect(
          formatFixed(BigInt.parse('1000000'), 6, fractionalDigits: 12, trimZeros: false),
          '1.000000',
        ),
      );
    });

    // Negative inputs go through a separate code path: the sign is stripped,
    // the magnitude is formatted, and the result is re-prefixed with '-'.
    // Skipping these cases left the negative branch (`value * -1` and the
    // `'-$valString'` return) uncovered.
    group('formatFixed, negative inputs', () {
      test(
        'negative whole number is formatted with a leading minus',
        () => expect(formatFixed(BigInt.parse('-1000000'), 6), '-1'),
      );

      test(
        'negative with a fractional remainder keeps the magnitude precision',
        () => expect(formatFixed(BigInt.parse('-1234567'), 6), '-1.234567'),
      );

      test(
        'negative respects fractionalDigits truncation',
        () => expect(
          formatFixed(BigInt.parse('-1234567'), 6, fractionalDigits: 3),
          '-1.234',
        ),
      );

      test(
        'negative with trimZeros=false keeps the trailing zeros after the minus',
        () => expect(
          formatFixed(BigInt.parse('-1000000'), 6, trimZeros: false),
          '-1.000000',
        ),
      );
    });

    test(
      'does not insert Swiss thousands marks',
      () => expect(
        formatFixed(BigInt.from(33232312), 2, trimZeros: false),
        '332323.12',
      ),
    );
  });
}
