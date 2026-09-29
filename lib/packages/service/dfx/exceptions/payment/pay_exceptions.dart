// Typed failures for the OCP pay flow (scan → swap → pay). Each one renders a
// human-readable string (see `exception_surface_test.dart`) so it can surface
// cleanly in logs, Sentry, and user-facing error states instead of the Dart
// default `Instance of '...'`.

/// The scanned QR / pasted code is not a DFX Open CryptoPay payment link.
class InvalidPaymentLinkException implements Exception {
  final String reason;

  const InvalidPaymentLinkException(this.reason);

  @override
  String toString() => 'InvalidPaymentLinkException: $reason';
}

/// Confirm never left the device, or the server rejected it before relaying.
/// The REALU sale did not start, so the quote may be confirmed again.
/// [apiMessage] is set only when the DFX API returned the text. A local
/// failure leaves it null so the screen uses its own copy.
class PayConfirmNotSubmittedException implements Exception {
  final String message;
  final String? apiMessage;

  const PayConfirmNotSubmittedException(this.message, {this.apiMessage});

  @override
  String toString() => 'PayConfirmNotSubmittedException: $message';
}

/// The debug wallet cannot sign the EIP-7702 delegation, so Pay stops
/// before any request leaves the device.
class PaySignatureUnsupportedException implements Exception {
  // Only ever thrown / constructed as a const expression, so the zero-arg
  // body never registers a runtime line hit; toString() below is exercised.
  const PaySignatureUnsupportedException(); // coverage:ignore-line

  @override
  String toString() =>
      'PaySignatureUnsupportedException: this wallet mode cannot sign transactions';
}

/// A pay response did not match the request. The software-wallet pay signs only
/// the EIP-7702 delegation; the relayer broadcasts and pays gas. There is no
/// separate ZCHF transfer for the customer to sign.
class PayUnsignedTxMismatchException implements Exception {
  final String reason;

  const PayUnsignedTxMismatchException(this.reason);

  @override
  String toString() => 'PayUnsignedTxMismatchException: $reason';
}
