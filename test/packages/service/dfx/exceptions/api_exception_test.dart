import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/buy_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';

void main() {
  group('$ApiException', () {
    group('fromJson', () {
      test('uses statusCode from JSON body when present', () {
        final exception = ApiException.fromJson(
          {'statusCode': 404, 'message': 'Not found'},
          httpStatusCode: 500,
        );

        expect(exception.statusCode, 404);
        expect(exception.message, 'Not found');
        expect(exception.code, 'UNKNOWN');
      });

      test('falls back to httpStatusCode when JSON body has no statusCode', () {
        final exception = ApiException.fromJson(
          {'code': 'TFA_REQUIRED', 'message': '2FA required (strict)', 'level': 'strict'},
          httpStatusCode: 403,
        );

        expect(exception.statusCode, 403);
        expect(exception.code, 'TFA_REQUIRED');
        expect(exception.message, '2FA required (strict)');
      });

      test('statusCode is null when neither JSON body nor httpStatusCode provide it', () {
        final exception = ApiException.fromJson(
          {'code': 'SOME_ERROR', 'message': 'Something went wrong'},
        );

        expect(exception.statusCode, isNull);
        expect(exception.code, 'SOME_ERROR');
      });

      test('handles message as List', () {
        final exception = ApiException.fromJson(
          {'message': ['error1', 'error2']},
          httpStatusCode: 400,
        );

        expect(exception.message, 'error1, error2');
        expect(exception.statusCode, 400);
      });

      test('creates KycLevelRequiredException with httpStatusCode', () {
        final exception = ApiException.fromJson(
          {
            'code': 'KYC_LEVEL_REQUIRED',
            'message': 'KYC level too low',
            'requiredLevel': 30,
            'currentLevel': 20,
          },
          httpStatusCode: 403,
        );

        expect(exception, isA<KycLevelRequiredException>());
        expect(exception.statusCode, 403);
        final kyc = exception as KycLevelRequiredException;
        expect(kyc.requiredLevel, 30);
        expect(kyc.currentLevel, 20);
        expect(kyc.context, isNull);
      });

      test('creates KycLevelRequiredException with context from JSON', () {
        final exception = ApiException.fromJson(
          {
            'code': 'KYC_LEVEL_REQUIRED',
            'message': 'KYC level too low',
            'requiredLevel': 30,
            'currentLevel': 20,
            'context': 'RealunitBuy',
          },
          httpStatusCode: 403,
        );

        expect(exception, isA<KycLevelRequiredException>());
        final kyc = exception as KycLevelRequiredException;
        expect(kyc.context, 'RealunitBuy');
      });

      test('creates RegistrationRequiredException with httpStatusCode', () {
        final exception = ApiException.fromJson(
          {'code': 'REGISTRATION_REQUIRED', 'message': 'Please register first'},
          httpStatusCode: 403,
        );

        expect(exception, isA<RegistrationRequiredException>());
        expect(exception.statusCode, 403);
        expect(exception.message, 'Please register first');
        expect((exception as RegistrationRequiredException).context, isNull);
      });

      test('creates RegistrationRequiredException with context from JSON', () {
        final exception = ApiException.fromJson(
          {
            'code': 'REGISTRATION_REQUIRED',
            'message': 'Please register first',
            'context': 'RealunitSell',
          },
          httpStatusCode: 403,
        );

        expect(exception, isA<RegistrationRequiredException>());
        final reg = exception as RegistrationRequiredException;
        expect(reg.context, 'RealunitSell');
      });

      test('creates PayCountryNotAllowedException with httpStatusCode', () {
        final exception = ApiException.fromJson(
          {'code': 'PAY_COUNTRY_NOT_ALLOWED', 'message': 'RealUnit pay is not available for the residence country'},
          httpStatusCode: 403,
        );

        expect(exception, isA<PayCountryNotAllowedException>());
        expect(exception.statusCode, 403);
        expect(exception.code, 'PAY_COUNTRY_NOT_ALLOWED');
        expect(exception.message, 'RealUnit pay is not available for the residence country');
        expect(exception.toString(), contains('PayCountryNotAllowedException'));
      });

      test('HTTP 426 is UpgradeRequired even when JSON code is KYC', () {
        final exception = ApiException.fromJson(
          {
            'code': 'KYC_LEVEL_REQUIRED',
            'message': 'KYC level too low',
            'requiredLevel': 30,
            'currentLevel': 20,
          },
          httpStatusCode: 426,
        );

        expect(exception, isA<UpgradeRequiredException>());
      });

      test('UPGRADE_REQUIRED code is UpgradeRequired when status is not 426', () {
        final exception = ApiException.fromJson(
          {
            'code': 'UPGRADE_REQUIRED',
            'message': 'Please update the RealUnit app to continue.',
            'minSupportedVersion': '1.3.0',
          },
          httpStatusCode: 400,
        );

        expect(exception, isA<UpgradeRequiredException>());
        expect(
          (exception as UpgradeRequiredException).minSupportedVersion,
          '1.3.0',
        );
      });
    });

    group('fromBody', () {
      test('JSON object body matches fromJson including KYC subclass', () {
        final exception = ApiException.fromBody(
          '{"statusCode":403,"code":"KYC_LEVEL_REQUIRED","message":"KYC level too low","requiredLevel":30,"currentLevel":20}',
          httpStatusCode: 403,
        );

        expect(exception, isA<KycLevelRequiredException>());
        expect(exception.statusCode, 403);
        expect(exception.code, 'KYC_LEVEL_REQUIRED');
        expect(exception.message, 'KYC level too low');
        final kyc = exception as KycLevelRequiredException;
        expect(kyc.requiredLevel, 30);
        expect(kyc.currentLevel, 20);
      });

      test('plain-text 502 body yields empty-message ApiException', () {
        final exception = ApiException.fromBody(
          'error code: 502',
          httpStatusCode: 502,
        );

        expect(exception, isA<ApiException>());
        expect(exception, isNot(isA<KycLevelRequiredException>()));
        expect(exception.statusCode, 502);
        expect(exception.code, 'UNKNOWN');
        expect(exception.message, '');
      });

      test('HTML 502 body yields empty-message ApiException', () {
        final exception = ApiException.fromBody(
          '<html>bad gateway</html>',
          httpStatusCode: 502,
        );

        expect(exception.statusCode, 502);
        expect(exception.code, 'UNKNOWN');
        expect(exception.message, '');
      });

      test('JSON array body yields empty-message ApiException', () {
        final exception = ApiException.fromBody(
          '[1]',
          httpStatusCode: 500,
        );

        expect(exception.statusCode, 500);
        expect(exception.code, 'UNKNOWN');
        expect(exception.message, '');
      });

      test('426 malformed JSON returns UpgradeRequiredException and does not throw', () {
        expect(
          () => ApiException.fromBody('{', httpStatusCode: 426),
          returnsNormally,
        );
        final exception = ApiException.fromBody('{', httpStatusCode: 426);
        expect(exception, isA<UpgradeRequiredException>());
        expect(
          (exception as UpgradeRequiredException).minSupportedVersion,
          isNull,
        );
        expect(exception.latestVersion, isNull);
        expect(exception.statusCode, 426);
      });

      test(
        '426 JSON with non-string minSupportedVersion returns UpgradeRequiredException',
        () {
          expect(
            () => ApiException.fromBody(
              '{"minSupportedVersion":1}',
              httpStatusCode: 426,
            ),
            returnsNormally,
          );
          final exception = ApiException.fromBody(
            '{"minSupportedVersion":1}',
            httpStatusCode: 426,
          );
          expect(exception, isA<UpgradeRequiredException>());
          expect(
            (exception as UpgradeRequiredException).minSupportedVersion,
            isNull,
          );
        },
      );

      test('well-formed 426 JSON parses minSupportedVersion', () {
        final exception = ApiException.fromBody(
          '{"code":"UPGRADE_REQUIRED","minSupportedVersion":"1.3.0","latestVersion":"1.4.0"}',
          httpStatusCode: 426,
        );

        expect(exception, isA<UpgradeRequiredException>());
        final upgrade = exception as UpgradeRequiredException;
        expect(upgrade.minSupportedVersion, '1.3.0');
        expect(upgrade.latestVersion, '1.4.0');
        expect(upgrade.statusCode, 426);
      });

      test('empty-body 426 returns UpgradeRequiredException', () {
        final exception = ApiException.fromBody('', httpStatusCode: 426);
        expect(exception, isA<UpgradeRequiredException>());
        expect(
          (exception as UpgradeRequiredException).minSupportedVersion,
          isNull,
        );
      });

      test('non-object JSON 426 returns UpgradeRequiredException', () {
        final exception = ApiException.fromBody('[1]', httpStatusCode: 426);
        expect(exception, isA<UpgradeRequiredException>());
      });
    });

    group('userFacingMessage', () {
      test('returns ApiException.message 1:1', () {
        const error = ApiException(
          statusCode: 503,
          code: 'AKTIONARIAT_UNAVAILABLE',
          message: 'Price source is temporarily unavailable',
        );

        expect(
          ApiException.userFacingMessage(error),
          'Price source is temporarily unavailable',
        );
        expect(
          ApiException.userFacingMessage(error),
          isNot(contains('RealUnitApiException')),
        );
      });

      test('returns Object.toString for non-API errors', () {
        expect(
          ApiException.userFacingMessage(Exception('socket closed')),
          'Exception: socket closed',
        );
      });
    });

    group('userFacingMessageFromJson', () {
      test('returns null when the API sent no message', () {
        expect(ApiException.userFacingMessageFromJson(null), isNull);
        expect(ApiException.userFacingMessageFromJson(''), isNull);
        expect(ApiException.userFacingMessageFromJson(<Object>[]), isNull);
      });

      test('joins a list message the same way fromJson does', () {
        expect(
          ApiException.userFacingMessageFromJson(['error1', 'error2']),
          'error1, error2',
        );
      });

      test('returns a string message 1:1', () {
        expect(
          ApiException.userFacingMessageFromJson('Price source is temporarily unavailable'),
          'Price source is temporarily unavailable',
        );
      });
    });
  });
}
