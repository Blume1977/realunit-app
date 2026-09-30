import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:realunit_wallet/packages/storage/secure_storage.dart';
import 'package:realunit_wallet/setup/routing/boot_navigation.dart';
import 'package:realunit_wallet/setup/routing/referral_pending_code.dart';
import 'package:realunit_wallet/setup/startup/wallet_reset.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _databaseEncryptionKey = 'drift.encryption.password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFlutterSecureStorage mockStorage;
  late SecureStorage secureStorage;
  late List<String> events;

  setUp(() {
    mockStorage = _MockFlutterSecureStorage();
    secureStorage = SecureStorage.withStorage(mockStorage);
    events = <String>[];
    when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((invocation) async {
      events.add('delete:${invocation.namedArguments[#key]}');
    });
  });

  void stubKeyAbsent() {
    when(() => mockStorage.read(key: _databaseEncryptionKey)).thenAnswer((_) async => null);
    when(() => mockStorage.isCupertinoProtectedDataAvailable()).thenAnswer((_) async => true);
    when(() => mockStorage.containsKey(key: _databaseEncryptionKey)).thenAnswer((_) async => false);
  }

  group('resetWalletData', () {
    tearDown(clearPendingPaymentDeeplink);

    test('key absent wipes prefs, secure entries and database files', () async {
      stubKeyAbsent();
      SharedPreferences.setMockInitialValues({
        'currentWalletId': 42,
        'termsAccepted': true,
        pendingReferralCodeKey: 'INVITE1',
      });
      debugSetPendingReferralCodeSync('INVITE1');
      var databaseDeleted = false;

      await resetWalletData(
        secureStorage: secureStorage,
        deleteDatabaseFiles: () async {
          databaseDeleted = true;
        },
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('currentWalletId'), isNull);
      expect(prefs.getBool('termsAccepted'), isFalse);
      expect(prefs.getString(pendingReferralCodeKey), isNull);
      expect(await peekPendingReferralCode(), isNull);

      verify(() => mockStorage.delete(key: 'pin.credential')).called(1);
      verify(() => mockStorage.delete(key: 'pin.hash')).called(1);
      verify(() => mockStorage.delete(key: 'pin.salt')).called(1);
      verify(() => mockStorage.delete(key: 'biometric.enabled')).called(1);
      verify(() => mockStorage.delete(key: 'pin.failedAttempts')).called(1);
      verify(() => mockStorage.delete(key: 'pin.lockedUntil')).called(1);
      verify(() => mockStorage.delete(key: 'wallet.mnemonic.encryption.key')).called(1);
      expect(databaseDeleted, isTrue);
    });

    test('clears a stashed payment deeplink', () async {
      stubKeyAbsent();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      stashPendingPaymentDeeplink('lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD');

      await resetWalletData(
        secureStorage: secureStorage,
        deleteDatabaseFiles: () async {},
      );

      expect(peekPendingPaymentDeeplink(), isNull);
    });

    test('deletes database files only after every secure-storage deletion', () async {
      stubKeyAbsent();
      SharedPreferences.setMockInitialValues(const <String, Object>{});

      await resetWalletData(
        secureStorage: secureStorage,
        deleteDatabaseFiles: () async {
          events.add('deleteDatabaseFiles');
        },
      );

      expect(events, isNotEmpty);
      expect(events.last, 'deleteDatabaseFiles');
      expect(
        events.where((e) => e.startsWith('delete:')),
        isNotEmpty,
        reason: 'secure-storage deletions must happen before the database wipe',
      );
    });

    test('key readable leaves preferences and storage untouched', () async {
      when(() => mockStorage.read(key: _databaseEncryptionKey)).thenAnswer((_) async => 'present');
      SharedPreferences.setMockInitialValues({
        'currentWalletId': 7,
        'termsAccepted': true,
      });
      var databaseDeleted = false;

      await resetWalletData(
        secureStorage: secureStorage,
        deleteDatabaseFiles: () async {
          databaseDeleted = true;
        },
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('currentWalletId'), 7);
      expect(prefs.getBool('termsAccepted'), isTrue);
      verifyNever(() => mockStorage.delete(key: any(named: 'key')));
      expect(databaseDeleted, isFalse);
    });

    test('protected data unavailable leaves preferences and storage untouched', () async {
      when(() => mockStorage.read(key: _databaseEncryptionKey)).thenAnswer((_) async => null);
      when(() => mockStorage.isCupertinoProtectedDataAvailable()).thenAnswer((_) async => false);
      SharedPreferences.setMockInitialValues({
        'currentWalletId': 7,
        'termsAccepted': true,
      });
      var databaseDeleted = false;

      await resetWalletData(
        secureStorage: secureStorage,
        deleteDatabaseFiles: () async {
          databaseDeleted = true;
        },
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('currentWalletId'), 7);
      expect(prefs.getBool('termsAccepted'), isTrue);
      verifyNever(() => mockStorage.delete(key: any(named: 'key')));
      expect(databaseDeleted, isFalse);
    });

    test('a failing secure-storage deletion propagates and skips the database wipe', () async {
      stubKeyAbsent();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      when(
        () => mockStorage.delete(key: 'wallet.mnemonic.encryption.key'),
      ).thenThrow(StateError('keystore unavailable'));
      var databaseDeleted = false;

      await expectLater(
        resetWalletData(
          secureStorage: secureStorage,
          deleteDatabaseFiles: () async {
            databaseDeleted = true;
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(databaseDeleted, isFalse);
    });
  });
}
