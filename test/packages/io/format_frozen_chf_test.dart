import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/io/format_frozen_chf.dart';

void main() {
  test('formats a frozen CHF amount to two decimals', () {
    expect(formatFrozenChfAmount('246.5'), '246.50');
    expect(formatFrozenChfAmount('20'), '20.00');
    expect(formatFrozenChfAmount('246,5'), '246.50');
    expect(formatFrozenChfAmount(' 512.4 '), '512.40');
    expect(formatFrozenChfAmount("1'246.5"), '1246.50');
    expect(formatFrozenChfAmount('1.246,50'), '1246.50');
    expect(formatFrozenChfAmount('CHF 246,5'), '246.50');
    expect(formatFrozenChfAmount('not-a-number'), 'not-a-number');
    expect(formatFrozenChfAmount('1.005'), '1.01');
    expect(formatFrozenChfAmount('1.004'), '1.00');
    expect(formatFrozenChfAmount('1.015'), '1.02');
    // Negative amounts: the sign survives rounding, but a value that rounds to
    // zero must not be rendered as "-0.00".
    expect(formatFrozenChfAmount('-1.005'), '-1.01');
    expect(formatFrozenChfAmount('-246,5'), '-246.50');
    expect(formatFrozenChfAmount('-0.004'), '0.00');
  });

  test('keeps a missing euro amount out of the stored pair', () {
    expect(encodeFrozenFiatData(chfValue: 246.5), '246.50');
    expect(encodeFrozenFiatData(chfValue: 246.5, eurValue: 12.3), '246.50|12.30');
    expect(splitFrozenFiatData('246.50'), (chf: '246.50', eur: null));
    expect(splitFrozenFiatData('246.50|12.30'), (chf: '246.50', eur: '12.30'));
    expect(splitFrozenFiatData('246.50|'), (chf: '246.50', eur: null));
  });

  test('referralPayoutSemanticsLabel joins title, date, CHF and amount', () {
    expect(
      referralPayoutSemanticsLabel(
        title: 'Empfehlungsprämie',
        date: '24.08.2026 | 12:00',
        amount: '+ 20 REALU',
        chfLine: 'CHF 246.50 zum Zeitpunkt der Gutschrift',
      ),
      'Empfehlungsprämie. 24.08.2026 | 12:00. CHF 246.50 zum Zeitpunkt der Gutschrift. + 20 REALU',
    );
    expect(
      referralPayoutAmountText(
        hideAmounts: false,
        amount: BigInt.from(20),
        decimals: 0,
        symbol: 'REALU',
      ),
      '+ 20 REALU',
    );
    expect(
      referralPayoutAmountText(
        hideAmounts: true,
        amount: BigInt.from(20),
        decimals: 0,
        symbol: 'REALU',
      ),
      '+ ***.**',
    );
  });
}
