/// The quote the server returned is not the share count this app requested.
class SellShareCountMismatchException implements Exception {
  const SellShareCountMismatchException();

  @override
  String toString() =>
      'SellShareCountMismatchException: returned share count does not match the request';
}

/// A sell quote may open only when the returned share count and the signed
/// base units are exactly the whole number this app sent.
void requireSellQuoteMatchesRequestedShares({
  required int requestedShares,
  required double returnedAmount,
  required String amountWei,
  required int decimals,
}) {
  final expectedWei =
      BigInt.from(requestedShares) * BigInt.from(10).pow(decimals);
  final actualWei = BigInt.tryParse(amountWei);
  if (returnedAmount != requestedShares.toDouble() ||
      actualWei != expectedWei) {
    throw const SellShareCountMismatchException();
  }
}
