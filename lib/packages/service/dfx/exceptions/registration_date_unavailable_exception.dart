import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';

/// The registration date response is missing its date or the date is not a
/// `YYYY-MM-DD` calendar day. Thrown before anything is signed.
class RegistrationDateUnavailableException extends ApiException {
  const RegistrationDateUnavailableException({
    super.statusCode,
    required super.message,
  }) : super(code: 'UNKNOWN');

  @override
  String toString() => 'RegistrationDateUnavailableException: $message (statusCode: $statusCode)';
}
