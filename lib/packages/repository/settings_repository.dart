import 'dart:ui';

import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  final SharedPreferences _sharedPreferences;

  SettingsRepository(this._sharedPreferences) {
    _migrateInsiderFeature(
      featureKey: 'walletFeaturePay',
      legacyKey: 'insiderPayEnabled',
      includeUnlock: true,
    );
    _migrateInsiderFeature(
      featureKey: 'walletFeatureSend',
      legacyKey: 'insiderSendEnabled',
    );
    _migrateInsiderFeature(
      featureKey: 'walletFeaturePromoCode',
      legacyKey: 'insiderBonusEnabled',
    );
    _migrateInsiderFeature(
      featureKey: 'walletFeatureReferral',
      legacyKey: 'insiderReferralEnabled',
    );
    _migrateSplitFeature(
      featureKey: 'walletFeaturePay',
      userOffKey: 'walletFeaturePayUserOff',
      centralKey: 'walletFeaturePayCentral',
      insiderKey: 'walletFeaturePayInsider',
    );
    _migrateSplitFeature(
      featureKey: 'walletFeatureSend',
      userOffKey: 'walletFeatureSendUserOff',
      centralKey: 'walletFeatureSendCentral',
      insiderKey: 'walletFeatureSendInsider',
    );
    _migrateSplitFeature(
      featureKey: 'walletFeaturePromoCode',
      userOffKey: 'walletFeaturePromoCodeUserOff',
      centralKey: 'walletFeaturePromoCodeCentral',
      insiderKey: 'walletFeaturePromoCodeInsider',
    );
    _migrateSplitFeature(
      featureKey: 'walletFeatureReferral',
      userOffKey: 'walletFeatureReferralUserOff',
      centralKey: 'walletFeatureReferralCentral',
      insiderKey: 'walletFeatureReferralInsider',
    );
  }

  void _migrateInsiderFeature({
    required String featureKey,
    required String legacyKey,
    bool includeUnlock = false,
  }) {
    if (_sharedPreferences.containsKey(featureKey)) {
      if (_sharedPreferences.containsKey(legacyKey)) {
        _sharedPreferences.remove(legacyKey);
      }
      return;
    }
    final legacyOn = _sharedPreferences.getBool(legacyKey) == true;
    if (!legacyOn && !(includeUnlock && insiderFeaturesUnlocked)) return;
    _sharedPreferences.setBool(featureKey, true);
    _sharedPreferences.remove(legacyKey);
  }

  void _migrateSplitFeature({
    required String featureKey,
    required String userOffKey,
    required String centralKey,
    required String insiderKey,
  }) {
    if (_sharedPreferences.containsKey(centralKey) || _sharedPreferences.containsKey(insiderKey)) {
      return;
    }
    if (!_sharedPreferences.containsKey(featureKey) &&
        !_sharedPreferences.containsKey(userOffKey)) {
      return;
    }
    final oldOn = _sharedPreferences.getBool(featureKey) == true;
    final userOff = _sharedPreferences.getBool(userOffKey) == true;
    if (oldOn && !userOff) {
      _sharedPreferences.setBool(insiderKey, true);
    } else {
      _sharedPreferences.setBool(insiderKey, false);
    }
  }

  Future<bool> saveCurrentWalletId(int walletId) =>
      _sharedPreferences.setInt('currentWalletId', walletId);

  Future<bool> removeCurrentWalletId() => _sharedPreferences.remove('currentWalletId');

  int? get currentWalletId => _sharedPreferences.getInt('currentWalletId');

  String get language {
    final stored = _sharedPreferences.getString('language');
    if (stored != null) return stored;

    final systemLang = PlatformDispatcher.instance.locale.languageCode;
    return systemLang == 'de' ? 'de' : 'en';
  }

  set language(String langCode) => _sharedPreferences.setString('language', langCode);

  bool get hasStoredCurrency => _sharedPreferences.getString('currency') != null;

  // Unset default is EUR. Residence-based CHF/EUR comes from the account
  // currency on GET /v2/user (applied by SettingsBloc, not persisted here).
  String get currency => _sharedPreferences.getString('currency') ?? 'EUR';

  set currency(String currencyCode) => _sharedPreferences.setString('currency', currencyCode);

  bool get termsAccepted => _sharedPreferences.getBool('termsAccepted') ?? false;

  set termsAccepted(bool accepted) => _sharedPreferences.setBool('termsAccepted', accepted);

  NetworkMode get networkMode {
    final value = _sharedPreferences.getString('networkMode');
    return NetworkMode.values.firstWhere(
      (network) => network.name == value,
      orElse: () => NetworkMode.mainnet,
    );
  }

  set networkMode(NetworkMode mode) => _sharedPreferences.setString('networkMode', mode.name);

  bool get softwareTermsAccepted => _sharedPreferences.getBool('softwareTermsAccepted') ?? false;

  set softwareTermsAccepted(bool accepted) =>
      _sharedPreferences.setBool('softwareTermsAccepted', accepted);

  bool get insiderFeaturesUnlocked =>
      _sharedPreferences.getBool('insiderFeaturesUnlocked') ?? false;
  set insiderFeaturesUnlocked(bool unlocked) =>
      _sharedPreferences.setBool('insiderFeaturesUnlocked', unlocked);

  // Effective flag is central OR insider. The setter is the server path and
  // only latches central. User switches use the methods below and do nothing
  // once central is latched.
  bool get walletFeaturePay =>
      walletFeaturePayCentral || (_sharedPreferences.getBool('walletFeaturePayInsider') ?? false);
  set walletFeaturePay(bool value) {
    if (value) {
      _sharedPreferences.setBool('walletFeaturePayCentral', true);
    }
  }

  bool get walletFeatureSend =>
      walletFeatureSendCentral || (_sharedPreferences.getBool('walletFeatureSendInsider') ?? false);
  set walletFeatureSend(bool value) {
    if (value) {
      _sharedPreferences.setBool('walletFeatureSendCentral', true);
    }
  }

  bool get walletFeaturePromoCode =>
      walletFeaturePromoCodeCentral ||
      (_sharedPreferences.getBool('walletFeaturePromoCodeInsider') ?? false);
  set walletFeaturePromoCode(bool value) {
    if (value) {
      _sharedPreferences.setBool('walletFeaturePromoCodeCentral', true);
    }
  }

  bool get walletFeatureReferral =>
      walletFeatureReferralCentral ||
      (_sharedPreferences.getBool('walletFeatureReferralInsider') ?? false);
  set walletFeatureReferral(bool value) {
    if (value) {
      _sharedPreferences.setBool('walletFeatureReferralCentral', true);
    }
  }

  bool get walletFeaturePayCentral =>
      _sharedPreferences.getBool('walletFeaturePayCentral') ?? false;
  bool get walletFeatureSendCentral =>
      _sharedPreferences.getBool('walletFeatureSendCentral') ?? false;
  bool get walletFeaturePromoCodeCentral =>
      _sharedPreferences.getBool('walletFeaturePromoCodeCentral') ?? false;
  bool get walletFeatureReferralCentral =>
      _sharedPreferences.getBool('walletFeatureReferralCentral') ?? false;

  void setWalletFeaturePayFromUser(bool enabled) {
    if (walletFeaturePayCentral) return;
    _sharedPreferences.setBool('walletFeaturePayInsider', enabled);
  }

  void setWalletFeatureSendFromUser(bool enabled) {
    if (walletFeatureSendCentral) return;
    _sharedPreferences.setBool('walletFeatureSendInsider', enabled);
  }

  void setWalletFeaturePromoCodeFromUser(bool enabled) {
    if (walletFeaturePromoCodeCentral) return;
    _sharedPreferences.setBool('walletFeaturePromoCodeInsider', enabled);
  }

  void setWalletFeatureReferralFromUser(bool enabled) {
    if (walletFeatureReferralCentral) return;
    _sharedPreferences.setBool('walletFeatureReferralInsider', enabled);
  }

  String? get dismissedClientPolicyLatest {
    final value = _sharedPreferences.getString('dismissedClientPolicyLatest');
    if (value == null || value.isEmpty) return null;
    return value;
  }

  set dismissedClientPolicyLatest(String? value) {
    if (value == null || value.isEmpty) {
      _sharedPreferences.remove('dismissedClientPolicyLatest');
    } else {
      _sharedPreferences.setString('dismissedClientPolicyLatest', value);
    }
  }
}
