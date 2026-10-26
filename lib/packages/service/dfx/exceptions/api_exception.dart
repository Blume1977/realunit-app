import 'dart:convert';

import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/buy_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;

  const ApiException({
    this.statusCode,
    required this.code,
    required this.message,
  });

  factory ApiException.fromJson(Map<String, dynamic> json, {int? httpStatusCode}) {
    if (httpStatusCode == 426) {
      return UpgradeRequiredException.fromJson(json, httpStatusCode: httpStatusCode);
    }

    final code = json['code'] as String?;

    switch (code) {
      case 'UPGRADE_REQUIRED':
        return UpgradeRequiredException.fromJson(json, httpStatusCode: httpStatusCode);
      case 'KYC_LEVEL_REQUIRED':
        return KycLevelRequiredException.fromJson(json, httpStatusCode: httpStatusCode);
      case 'REGISTRATION_REQUIRED':
        return RegistrationRequiredException.fromJson(json, httpStatusCode: httpStatusCode);
      case 'PAY_COUNTRY_NOT_ALLOWED':
        return PayCountryNotAllowedException.fromJson(json, httpStatusCode: httpStatusCode);
      default:
        final message = json['message'];
        return ApiException(
          statusCode: json['statusCode'] as int? ?? httpStatusCode,
          code: code ?? 'UNKNOWN',
          message: message is List ? message.join(', ') : message?.toString() ?? 'Unknown error',
        );
    }
  }

  /// Builds an [ApiException] from an HTTP error body that may or may not be JSON.
  ///
  /// JSON objects go through [fromJson] (KYC/registration subclasses preserved).
  /// Non-JSON or non-object bodies yield an empty [message] — never the raw body.
  /// HTTP 426 is always [UpgradeRequiredException], even when the body is empty
  /// or not JSON.
  factory ApiException.fromBody(String body, {required int httpStatusCode}) {
    if (httpStatusCode == 426) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return ApiException.fromJson(decoded, httpStatusCode: httpStatusCode);
        }
      } on Object {
        // Malformed JSON or fromJson TypeError: 426 is still upgrade-required.
      }
      return const UpgradeRequiredException();
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return ApiException.fromJson(decoded, httpStatusCode: httpStatusCode);
      }
    } on FormatException {
      // Non-JSON body (plain text, HTML, empty). No API user-facing text.
    }
    return ApiException(
      statusCode: httpStatusCode,
      code: 'UNKNOWN',
      message: '',
    );
  }

  @override
  String toString() => 'RealUnitApiException: $message (code: $code, statusCode: $statusCode)';

  /// User-visible text for an error thrown from a DFX API call.
  ///
  /// [UpgradeRequiredException] is never shown as API English. Other
  /// [ApiException]s are shown 1:1 as [message]. Any other object has no API
  /// text; [Object.toString] is the remainder (transport, parse, local).
  static String userFacingMessage(Object error) {
    if (error is UpgradeRequiredException) return '';
    if (error is ApiException) return error.message;
    return error.toString();
  }

  /// Normalizes the JSON `message` field. Null/empty means the API sent no
  /// user-facing text — callers must not invent a substitute.
  static String? userFacingMessageFromJson(Object? message) {
    if (message == null) {
      return null;
    }
    if (message is List) {
      final joined = message.map((item) => item.toString()).join(', ');
      return joined.isEmpty ? null : joined;
    }
    final text = message.toString();
    return text.isEmpty ? null : text;
  }
}

class UpgradeRequiredException extends ApiException {
  final String? minSupportedVersion;
  final String? latestVersion;

  const UpgradeRequiredException({
    this.minSupportedVersion,
    this.latestVersion,
    super.statusCode = 426,
  }) : super(code: 'UPGRADE_REQUIRED', message: '');

  factory UpgradeRequiredException.fromJson(
    Map<String, dynamic> json, {
    int? httpStatusCode,
  }) {
    return UpgradeRequiredException(
      minSupportedVersion: json['minSupportedVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      statusCode: json['statusCode'] as int? ?? httpStatusCode ?? 426,
    );
  }

  @override
  String toString() => 'UpgradeRequiredException (min: $minSupportedVersion)';
}
