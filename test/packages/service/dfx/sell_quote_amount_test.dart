import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/sell_quote_amount.dart';

void main() {
  test('accepts the same whole share count and its base units', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 10,
        amountWei: '10',
        decimals: 0,
      ),
      returnsNormally,
    );
  });

  test('rejects a lower share count', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 9,
        amountWei: '9',
        decimals: 0,
      ),
      throwsA(isA<SellShareCountMismatchException>()),
    );
  });

  test('rejects a higher share count', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 12,
        amountWei: '12',
        decimals: 0,
      ),
      throwsA(isA<SellShareCountMismatchException>()),
    );
  });

  test('rejects a fractional amount that would display as the request', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 10.9,
        amountWei: '10',
        decimals: 0,
      ),
      throwsA(isA<SellShareCountMismatchException>()),
    );
  });

  test('rejects base units that do not match the requested shares', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 10,
        amountWei: '11',
        decimals: 0,
      ),
      throwsA(isA<SellShareCountMismatchException>()),
    );
  });

  test('scales base units by the asset decimals', () {
    expect(
      () => requireSellQuoteMatchesRequestedShares(
        requestedShares: 10,
        returnedAmount: 10,
        amountWei: '10000000000000000000',
        decimals: 18,
      ),
      returnsNormally,
    );
  });
}
