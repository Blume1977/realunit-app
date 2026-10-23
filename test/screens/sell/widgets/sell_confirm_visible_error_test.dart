import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_confirm_sheet.dart';

void main() {
  const fallback =
      'The sale was not sent. The authorization does not match '
      'the confirmed amount or does not expire within 30 minutes.';

  test('a caveat rejection shows why the sale was not sent', () {
    expect(
      visibleSellConfirmError(
        error: 'Exception: EIP-7702 caveats: the caveat list is empty',
        caveatFallback: fallback,
      ),
      fallback,
    );
  });

  test('other confirm errors keep their existing text', () {
    expect(
      visibleSellConfirmError(
        error: 'Exception: signing cancelled',
        caveatFallback: fallback,
      ),
      'Exception: signing cancelled',
    );
  });
}
