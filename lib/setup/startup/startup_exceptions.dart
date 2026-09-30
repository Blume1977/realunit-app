/// Thrown when the encrypted database file exists and its key is verifiably
/// absent from secure storage. Only a wallet reset can recover; retrying will
/// not recreate the key. [walletConfigured] is a non-personal diagnostic for
/// the crash report.
class DatabaseKeyMissingException implements Exception {
  const DatabaseKeyMissingException({required this.walletConfigured});

  final bool walletConfigured;

  @override
  String toString() =>
      'DatabaseKeyMissingException: Database found, but key is missing! '
      '(wallet configured: $walletConfigured)';
}

/// Thrown when the encrypted database file exists but its key could not be
/// read right now (for example while protected data is unavailable). The app
/// may retry; it must never reset the wallet in this state.
/// [protectedDataAvailable] is a non-personal diagnostic for the crash report.
class DatabaseKeyUnreadableException implements Exception {
  const DatabaseKeyUnreadableException({required this.protectedDataAvailable});

  final bool? protectedDataAvailable;

  @override
  String toString() =>
      'DatabaseKeyUnreadableException: Database found, but its key could not be read '
      '(protected data available: $protectedDataAvailable)';
}
