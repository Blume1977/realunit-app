import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialise the binding so SharedPreferences plugin channels work.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$SettingsRepository', () {
    group('currentWalletId', () {
      test('returns null when no value is stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.currentWalletId, isNull);
      });

      test('saveCurrentWalletId persists the id', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        await repo.saveCurrentWalletId(42);

        expect(repo.currentWalletId, 42);
      });

      test('removeCurrentWalletId clears the stored id', () async {
        SharedPreferences.setMockInitialValues({'currentWalletId': 7});
        final repo = SettingsRepository(await SharedPreferences.getInstance());
        expect(repo.currentWalletId, 7);

        await repo.removeCurrentWalletId();

        expect(repo.currentWalletId, isNull);
      });
    });

    group('language', () {
      test('falls back to "en" for non-German system locales', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        // PlatformDispatcher.instance.locale in the test binding defaults to
        // en_US; the fallback rule says "anything non-de → en".
        expect(repo.language, 'en');
      });

      test('returns the stored language when set', () async {
        SharedPreferences.setMockInitialValues({'language': 'de'});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.language, 'de');
      });

      test('language setter persists', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.language = 'de';

        // The setter is fire-and-forget; give the platform channel a tick.
        await Future<void>.delayed(Duration.zero);
        expect(repo.language, 'de');
      });
    });

    group('currency', () {
      test('defaults to EUR when nothing is stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.currency, 'EUR');
        expect(repo.hasStoredCurrency, isFalse);
      });

      test('returns the stored currency when set', () async {
        SharedPreferences.setMockInitialValues({'currency': 'EUR'});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.currency, 'EUR');
        expect(repo.hasStoredCurrency, isTrue);
      });

      test('currency setter persists', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.currency = 'EUR';
        await Future<void>.delayed(Duration.zero);

        expect(repo.currency, 'EUR');
      });
    });

    group('terms', () {
      test('defaults to false when not stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.termsAccepted, isFalse);
        expect(repo.softwareTermsAccepted, isFalse);
      });

      test('termsAccepted setter persists', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.termsAccepted = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.termsAccepted, isTrue);
      });

      test('softwareTermsAccepted setter persists independently', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.softwareTermsAccepted = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.softwareTermsAccepted, isTrue);
        expect(repo.termsAccepted, isFalse);
      });
    });

    group('insiderFeaturesUnlocked', () {
      test('defaults to false when not stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.insiderFeaturesUnlocked, isFalse);
      });

      test('returns the stored value when set', () async {
        SharedPreferences.setMockInitialValues({'insiderFeaturesUnlocked': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.insiderFeaturesUnlocked, isTrue);
      });

      test('setter persists', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.insiderFeaturesUnlocked = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.insiderFeaturesUnlocked, isTrue);
      });
    });

    group('networkOptionsEnabled', () {
      test('defaults to false when not stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.networkOptionsEnabled, isFalse);
      });

      test('setting true stores key networkOptionsEnabled', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        repo.networkOptionsEnabled = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.networkOptionsEnabled, isTrue);
        expect(prefs.getBool('networkOptionsEnabled'), isTrue);
      });

      test('stays true after networkMode is testnet and is not scoped per network', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        repo.networkOptionsEnabled = true;
        await Future<void>.delayed(Duration.zero);

        repo.networkMode = NetworkMode.testnet;
        await Future<void>.delayed(Duration.zero);

        expect(repo.networkOptionsEnabled, isTrue);
        expect(prefs.containsKey('networkOptionsEnabled.mainnet'), isFalse);
        expect(prefs.containsKey('networkOptionsEnabled.testnet'), isFalse);
      });
    });

    group('wallet feature flags', () {
      test('default to false', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeaturePay, isFalse);
        expect(repo.walletFeatureSend, isFalse);
        expect(repo.walletFeaturePromoCode, isFalse);
        expect(repo.walletFeatureReferral, isFalse);
        expect(repo.walletFeaturePayCentral, isFalse);
        expect(repo.walletFeatureSendCentral, isFalse);
        expect(repo.walletFeaturePromoCodeCentral, isFalse);
        expect(repo.walletFeatureReferralCentral, isFalse);
      });

      test('persist true', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.walletFeaturePay = true;
        repo.walletFeatureSend = true;
        repo.walletFeaturePromoCode = true;
        repo.walletFeatureReferral = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isTrue);
        expect(repo.walletFeaturePromoCode, isTrue);
        expect(repo.walletFeatureReferral, isTrue);
        expect(repo.walletFeaturePayCentral, isTrue);
        expect(repo.walletFeatureSendCentral, isTrue);
        expect(repo.walletFeaturePromoCodeCentral, isTrue);
        expect(repo.walletFeatureReferralCentral, isTrue);
      });

      test('ignore false over true', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.walletFeaturePay = true;
        repo.walletFeatureSend = true;
        repo.walletFeaturePromoCode = true;
        repo.walletFeatureReferral = true;
        await Future<void>.delayed(Duration.zero);

        repo.walletFeaturePay = false;
        repo.walletFeatureSend = false;
        repo.walletFeaturePromoCode = false;
        repo.walletFeatureReferral = false;
        await Future<void>.delayed(Duration.zero);

        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isTrue);
        expect(repo.walletFeaturePromoCode, isTrue);
        expect(repo.walletFeatureReferral, isTrue);
        expect(repo.walletFeaturePayCentral, isTrue);
        expect(repo.walletFeatureSendCentral, isTrue);
        expect(repo.walletFeaturePromoCodeCentral, isTrue);
        expect(repo.walletFeatureReferralCentral, isTrue);
      });

      test('migrates old insider unlock to pay only', () async {
        SharedPreferences.setMockInitialValues({'insiderFeaturesUnlocked': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.insiderFeaturesUnlocked, isTrue);
        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isFalse);
        expect(repo.walletFeaturePromoCode, isFalse);
        expect(repo.walletFeatureReferral, isFalse);
      });

      test('migrates old insiderPayEnabled to walletFeaturePay', () async {
        SharedPreferences.setMockInitialValues({'insiderPayEnabled': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isFalse);
      });

      test('migrates old insiderSendEnabled to walletFeatureSend', () async {
        SharedPreferences.setMockInitialValues({'insiderSendEnabled': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeatureSend, isTrue);
        expect(repo.walletFeaturePay, isFalse);
      });

      test('migrates old insiderReferralEnabled to walletFeatureReferral', () async {
        SharedPreferences.setMockInitialValues({'insiderReferralEnabled': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeatureReferral, isTrue);
        expect(repo.walletFeaturePromoCode, isFalse);
      });

      test('migrates old insiderBonusEnabled to walletFeaturePromoCode', () async {
        SharedPreferences.setMockInitialValues({'insiderBonusEnabled': true});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeaturePromoCode, isTrue);
        expect(repo.walletFeatureReferral, isFalse);
      });

      test('a central true stays on when the insider switch is turned off', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        repo.walletFeaturePay = true;
        repo.walletFeatureSend = true;
        repo.walletFeaturePromoCode = true;
        repo.walletFeatureReferral = true;
        await Future<void>.delayed(Duration.zero);

        repo.setWalletFeaturePayFromUser(false);
        repo.setWalletFeatureSendFromUser(false);
        repo.setWalletFeaturePromoCodeFromUser(false);
        repo.setWalletFeatureReferralFromUser(false);
        await Future<void>.delayed(Duration.zero);

        final reloaded = SettingsRepository(prefs);
        expect(reloaded.walletFeaturePay, isTrue);
        expect(reloaded.walletFeatureSend, isTrue);
        expect(reloaded.walletFeaturePromoCode, isTrue);
        expect(reloaded.walletFeatureReferral, isTrue);
        expect(reloaded.walletFeaturePayCentral, isTrue);
        expect(reloaded.walletFeatureSendCentral, isTrue);
        expect(reloaded.walletFeaturePromoCodeCentral, isTrue);
        expect(reloaded.walletFeatureReferralCentral, isTrue);

        reloaded.walletFeaturePay = false;
        reloaded.walletFeatureSend = false;
        reloaded.walletFeaturePromoCode = false;
        reloaded.walletFeatureReferral = false;
        await Future<void>.delayed(Duration.zero);

        expect(reloaded.walletFeaturePay, isTrue);
        expect(reloaded.walletFeatureSend, isTrue);
        expect(reloaded.walletFeaturePromoCode, isTrue);
        expect(reloaded.walletFeatureReferral, isTrue);
      });

      test('a central true overrides a stored insider off', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        repo.setWalletFeaturePayFromUser(false);
        repo.setWalletFeatureSendFromUser(false);
        repo.setWalletFeaturePromoCodeFromUser(false);
        repo.setWalletFeatureReferralFromUser(false);
        await Future<void>.delayed(Duration.zero);

        expect(repo.walletFeaturePay, isFalse);
        expect(repo.walletFeatureSend, isFalse);
        expect(repo.walletFeaturePromoCode, isFalse);
        expect(repo.walletFeatureReferral, isFalse);

        final reloaded = SettingsRepository(prefs);
        expect(reloaded.walletFeaturePay, isFalse);
        expect(reloaded.walletFeatureSend, isFalse);
        expect(reloaded.walletFeaturePromoCode, isFalse);
        expect(reloaded.walletFeatureReferral, isFalse);

        reloaded.walletFeaturePay = true;
        reloaded.walletFeatureSend = true;
        reloaded.walletFeaturePromoCode = true;
        reloaded.walletFeatureReferral = true;
        await Future<void>.delayed(Duration.zero);

        expect(reloaded.walletFeaturePay, isTrue);
        expect(reloaded.walletFeatureSend, isTrue);
        expect(reloaded.walletFeaturePromoCode, isTrue);
        expect(reloaded.walletFeatureReferral, isTrue);
        expect(reloaded.walletFeaturePayCentral, isTrue);
        expect(reloaded.walletFeatureSendCentral, isTrue);
        expect(reloaded.walletFeaturePromoCodeCentral, isTrue);
        expect(reloaded.walletFeatureReferralCentral, isTrue);

        final stillOn = SettingsRepository(prefs);
        expect(stillOn.walletFeaturePay, isTrue);
        expect(stillOn.walletFeatureSend, isTrue);
        expect(stillOn.walletFeaturePromoCode, isTrue);
        expect(stillOn.walletFeatureReferral, isTrue);
        expect(stillOn.walletFeaturePayCentral, isTrue);
        expect(stillOn.walletFeatureSendCentral, isTrue);
        expect(stillOn.walletFeaturePromoCodeCentral, isTrue);
        expect(stillOn.walletFeatureReferralCentral, isTrue);

        stillOn.walletFeaturePay = false;
        stillOn.walletFeatureSend = false;
        stillOn.walletFeaturePromoCode = false;
        stillOn.walletFeatureReferral = false;
        await Future<void>.delayed(Duration.zero);

        expect(stillOn.walletFeaturePay, isTrue);
        expect(stillOn.walletFeatureSend, isTrue);
        expect(stillOn.walletFeaturePromoCode, isTrue);
        expect(stillOn.walletFeatureReferral, isTrue);
      });

      test('a server false does not clear an insider-on', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.setWalletFeaturePayFromUser(false);
        repo.setWalletFeatureSendFromUser(false);
        repo.setWalletFeaturePromoCodeFromUser(false);
        repo.setWalletFeatureReferralFromUser(false);
        repo.setWalletFeaturePayFromUser(true);
        repo.setWalletFeatureSendFromUser(true);
        repo.setWalletFeaturePromoCodeFromUser(true);
        repo.setWalletFeatureReferralFromUser(true);
        await Future<void>.delayed(Duration.zero);

        repo.walletFeaturePay = false;
        repo.walletFeatureSend = false;
        repo.walletFeaturePromoCode = false;
        repo.walletFeatureReferral = false;
        await Future<void>.delayed(Duration.zero);

        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isTrue);
        expect(repo.walletFeaturePromoCode, isTrue);
        expect(repo.walletFeatureReferral, isTrue);
        expect(repo.walletFeaturePayCentral, isFalse);
        expect(repo.walletFeatureSendCentral, isFalse);
        expect(repo.walletFeaturePromoCodeCentral, isFalse);
        expect(repo.walletFeatureReferralCentral, isFalse);
      });

      test('an old stored user-off does not block the next central true', () async {
        SharedPreferences.setMockInitialValues({
          'walletFeaturePay': false,
          'walletFeaturePayUserOff': true,
          'walletFeatureSend': false,
          'walletFeatureSendUserOff': true,
          'walletFeaturePromoCode': false,
          'walletFeaturePromoCodeUserOff': true,
          'walletFeatureReferral': false,
          'walletFeatureReferralUserOff': true,
        });
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.walletFeaturePay, isFalse);
        expect(repo.walletFeatureSend, isFalse);
        expect(repo.walletFeaturePromoCode, isFalse);
        expect(repo.walletFeatureReferral, isFalse);
        expect(repo.walletFeaturePayCentral, isFalse);
        expect(repo.walletFeatureSendCentral, isFalse);
        expect(repo.walletFeaturePromoCodeCentral, isFalse);
        expect(repo.walletFeatureReferralCentral, isFalse);

        repo.walletFeaturePay = true;
        repo.walletFeatureSend = true;
        repo.walletFeaturePromoCode = true;
        repo.walletFeatureReferral = true;
        await Future<void>.delayed(Duration.zero);

        expect(repo.walletFeaturePay, isTrue);
        expect(repo.walletFeatureSend, isTrue);
        expect(repo.walletFeaturePromoCode, isTrue);
        expect(repo.walletFeatureReferral, isTrue);
        expect(repo.walletFeaturePayCentral, isTrue);
        expect(repo.walletFeatureSendCentral, isTrue);
        expect(repo.walletFeaturePromoCodeCentral, isTrue);
        expect(repo.walletFeatureReferralCentral, isTrue);
      });

      test(
        'an old stored on without user-off migrates to insider on, not to the central latch',
        () async {
          SharedPreferences.setMockInitialValues({
            'walletFeaturePay': true,
            'walletFeatureSend': true,
            'walletFeaturePromoCode': true,
            'walletFeatureReferral': true,
          });
          final repo = SettingsRepository(await SharedPreferences.getInstance());

          expect(repo.walletFeaturePay, isTrue);
          expect(repo.walletFeatureSend, isTrue);
          expect(repo.walletFeaturePromoCode, isTrue);
          expect(repo.walletFeatureReferral, isTrue);
          expect(repo.walletFeaturePayCentral, isFalse);
          expect(repo.walletFeatureSendCentral, isFalse);
          expect(repo.walletFeaturePromoCodeCentral, isFalse);
          expect(repo.walletFeatureReferralCentral, isFalse);

          repo.setWalletFeaturePayFromUser(false);
          repo.setWalletFeatureSendFromUser(false);
          repo.setWalletFeaturePromoCodeFromUser(false);
          repo.setWalletFeatureReferralFromUser(false);
          await Future<void>.delayed(Duration.zero);

          expect(repo.walletFeaturePay, isFalse);
          expect(repo.walletFeatureSend, isFalse);
          expect(repo.walletFeaturePromoCode, isFalse);
          expect(repo.walletFeatureReferral, isFalse);
        },
      );

      test('stored false is not revived by an old insider key or by unlock', () async {
        SharedPreferences.setMockInitialValues({
          'walletFeaturePay': false,
          'insiderFeaturesUnlocked': true,
          'insiderPayEnabled': true,
          'walletFeatureSend': false,
          'insiderSendEnabled': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        expect(repo.walletFeaturePay, isFalse);
        expect(prefs.getBool('insiderPayEnabled'), isNull);
        expect(repo.walletFeatureSend, isFalse);
        expect(prefs.getBool('insiderSendEnabled'), isNull);
      });

      test('a true stored on mainnet is false while networkMode is testnet, and the reverse', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.walletFeaturePay = true;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isTrue);

        repo.networkMode = NetworkMode.testnet;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isFalse);

        repo.walletFeaturePay = true;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isTrue);

        repo.networkMode = NetworkMode.mainnet;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isTrue);

        SharedPreferences.setMockInitialValues({'networkMode': 'Testnet'});
        final testnetRepo = SettingsRepository(await SharedPreferences.getInstance());
        testnetRepo.walletFeaturePay = true;
        await Future<void>.delayed(Duration.zero);
        testnetRepo.networkMode = NetworkMode.mainnet;
        await Future<void>.delayed(Duration.zero);
        expect(testnetRepo.walletFeaturePay, isFalse);
      });

      test('unscoped true with Testnet migrates onto testnet only', () async {
        SharedPreferences.setMockInitialValues({
          'walletFeaturePay': true,
          'networkMode': 'Testnet',
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        expect(repo.walletFeaturePay, isTrue);
        expect(prefs.getBool('walletFeaturePayInsider.testnet'), isTrue);
        expect(prefs.getBool('walletFeaturePayInsider.mainnet'), isNull);
        expect(prefs.containsKey('walletFeaturePay'), isFalse);

        repo.networkMode = NetworkMode.mainnet;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isFalse);
      });

      test('unscoped true migrates onto mainnet when networkMode is unset', () async {
        SharedPreferences.setMockInitialValues({
          'walletFeaturePay': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        expect(repo.walletFeaturePay, isTrue);
        expect(prefs.getBool('walletFeaturePayInsider.mainnet'), isTrue);
        expect(prefs.containsKey('walletFeaturePay'), isFalse);
      });

      test('user-off on testnet does not block pay on mainnet', () async {
        SharedPreferences.setMockInitialValues({'networkMode': 'Testnet'});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.setWalletFeaturePayFromUser(false);
        await Future<void>.delayed(Duration.zero);

        repo.networkMode = NetworkMode.mainnet;
        await Future<void>.delayed(Duration.zero);

        repo.walletFeaturePay = true;
        await Future<void>.delayed(Duration.zero);
        expect(repo.walletFeaturePay, isTrue);
      });

      test('a later repository construction does not copy unlock pay onto testnet', () async {
        SharedPreferences.setMockInitialValues({'insiderFeaturesUnlocked': true});
        final prefs = await SharedPreferences.getInstance();
        final first = SettingsRepository(prefs);

        expect(first.walletFeaturePay, isTrue);
        expect(prefs.getBool('walletFeaturePayInsider.mainnet'), isTrue);
        expect(prefs.containsKey('walletFeaturePay.mainnet'), isFalse);
        expect(prefs.containsKey('walletFeaturePay'), isFalse);

        await prefs.setString('networkMode', 'Testnet');

        final second = SettingsRepository(prefs);
        expect(second.walletFeaturePay, isFalse);
        expect(prefs.containsKey('walletFeaturePayInsider.testnet'), isFalse);
        expect(prefs.containsKey('walletFeaturePay.testnet'), isFalse);
        expect(prefs.getBool('walletFeaturePayInsider.mainnet'), isTrue);
        expect(prefs.containsKey('walletFeaturePay'), isFalse);
      });

      test('unlock does not write pay when a scoped mainnet key already exists', () async {
        SharedPreferences.setMockInitialValues({
          'insiderFeaturesUnlocked': true,
          'networkMode': 'Testnet',
          'walletFeaturePay.mainnet': true,
          'insiderPayEnabled': true,
        });
        final prefsTrue = await SharedPreferences.getInstance();
        final repoTrue = SettingsRepository(prefsTrue);

        expect(repoTrue.walletFeaturePay, isFalse);
        expect(prefsTrue.getBool('walletFeaturePayInsider.mainnet'), isTrue);
        expect(prefsTrue.containsKey('walletFeaturePay.mainnet'), isFalse);
        expect(prefsTrue.containsKey('walletFeaturePayInsider.testnet'), isFalse);
        expect(prefsTrue.containsKey('walletFeaturePay.testnet'), isFalse);
        expect(prefsTrue.containsKey('walletFeaturePay'), isFalse);
        expect(prefsTrue.containsKey('insiderPayEnabled'), isFalse);

        SharedPreferences.setMockInitialValues({
          'insiderFeaturesUnlocked': true,
          'networkMode': 'Testnet',
          'walletFeaturePay.mainnet': false,
        });
        final prefsFalse = await SharedPreferences.getInstance();
        final repoFalse = SettingsRepository(prefsFalse);

        expect(repoFalse.walletFeaturePay, isFalse);
        expect(prefsFalse.getBool('walletFeaturePayInsider.mainnet'), isFalse);
        expect(prefsFalse.containsKey('walletFeaturePay.mainnet'), isFalse);
        expect(prefsFalse.containsKey('walletFeaturePayInsider.testnet'), isFalse);
        expect(prefsFalse.containsKey('walletFeaturePay.testnet'), isFalse);
        expect(prefsFalse.containsKey('walletFeaturePay'), isFalse);
      });

      test('unlock does not copy a scoped testnet pay key onto mainnet', () async {
        SharedPreferences.setMockInitialValues({
          'insiderFeaturesUnlocked': true,
          'walletFeaturePay.testnet': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        expect(repo.walletFeaturePay, isFalse);
        expect(prefs.getBool('walletFeaturePayInsider.testnet'), isTrue);
        expect(prefs.containsKey('walletFeaturePay.testnet'), isFalse);
        expect(prefs.containsKey('walletFeaturePayInsider.mainnet'), isFalse);
        expect(prefs.containsKey('walletFeaturePay.mainnet'), isFalse);
        expect(prefs.containsKey('walletFeaturePay'), isFalse);
      });
    });

    group('dismissedClientPolicyLatest', () {
      test('returns null when no value is stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.dismissedClientPolicyLatest, isNull);
      });

      test('setter persists', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.dismissedClientPolicyLatest = '1.4.0';
        await Future<void>.delayed(Duration.zero);

        expect(repo.dismissedClientPolicyLatest, '1.4.0');
      });

      test('empty or null setter removes', () async {
        SharedPreferences.setMockInitialValues({
          'dismissedClientPolicyLatest': '1.4.0',
        });
        final repo = SettingsRepository(await SharedPreferences.getInstance());
        expect(repo.dismissedClientPolicyLatest, '1.4.0');

        repo.dismissedClientPolicyLatest = '';
        await Future<void>.delayed(Duration.zero);
        expect(repo.dismissedClientPolicyLatest, isNull);

        repo.dismissedClientPolicyLatest = '1.4.0';
        await Future<void>.delayed(Duration.zero);
        expect(repo.dismissedClientPolicyLatest, '1.4.0');

        repo.dismissedClientPolicyLatest = null;
        await Future<void>.delayed(Duration.zero);
        expect(repo.dismissedClientPolicyLatest, isNull);
      });
    });

    group('networkMode', () {
      test('defaults to mainnet when no value is stored', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.networkMode, NetworkMode.mainnet);
      });

      test('defaults to mainnet when stored value is unknown', () async {
        SharedPreferences.setMockInitialValues({'networkMode': 'localnet'});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        // firstWhere falls back to mainnet via orElse.
        expect(repo.networkMode, NetworkMode.mainnet);
      });

      test('returns testnet when stored under the enum constructor name', () async {
        // The setter writes `mode.name`, which is the constructor arg
        // ('Mainnet' / 'Testnet') — NOT the Dart enum identifier.
        SharedPreferences.setMockInitialValues({'networkMode': 'Testnet'});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        expect(repo.networkMode, NetworkMode.testnet);
      });

      test('networkMode setter persists by enum name', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(await SharedPreferences.getInstance());

        repo.networkMode = NetworkMode.testnet;
        await Future<void>.delayed(Duration.zero);

        expect(repo.networkMode, NetworkMode.testnet);
      });
    });
  });
}
