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
    for (final scope in ['mainnet', 'testnet']) {
      _migrateSplitFeature(
        featureKey: 'walletFeaturePay.$scope',
        userOffKey: 'walletFeaturePayUserOff.$scope',
        centralKey: 'walletFeaturePayCentral.$scope',
        insiderKey: 'walletFeaturePayInsider.$scope',
      );
      _migrateSplitFeature(
        featureKey: 'walletFeatureSend.$scope',
        userOffKey: 'walletFeatureSendUserOff.$scope',
        centralKey: 'walletFeatureSendCentral.$scope',
        insiderKey: 'walletFeatureSendInsider.$scope',
      );
      _migrateSplitFeature(
        featureKey: 'walletFeaturePromoCode.$scope',
        userOffKey: 'walletFeaturePromoCodeUserOff.$scope',
        centralKey: 'walletFeaturePromoCodeCentral.$scope',
        insiderKey: 'walletFeaturePromoCodeInsider.$scope',
      );
      _migrateSplitFeature(
        featureKey: 'walletFeatureReferral.$scope',
        userOffKey: 'walletFeatureReferralUserOff.$scope',
        centralKey: 'walletFeatureReferralCentral.$scope',
        insiderKey: 'walletFeatureReferralInsider.$scope',
      );
    }
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
    for (final base in [
      'walletFeaturePayCentral',
      'walletFeaturePayInsider',
      'walletFeatureSendCentral',
      'walletFeatureSendInsider',
      'walletFeaturePromoCodeCentral',
      'walletFeaturePromoCodeInsider',
      'walletFeatureReferralCentral',
      'walletFeatureReferralInsider',
    ]) {
      _migrateUnscopedToCurrentNetwork(base);
    }
  }

  String get _featureScope => networkMode.isTestnet ? 'testnet' : 'mainnet';
  String _scoped(String base) => '$base.$_featureScope';

  void _migrateUnscopedToCurrentNetwork(String base) {
    final scoped = _scoped(base);
    final hasAnyScope =
        _sharedPreferences.containsKey('$base.mainnet') ||
        _sharedPreferences.containsKey('$base.testnet');
    if (!hasAnyScope && _sharedPreferences.containsKey(base)) {
      _sharedPreferences.setBool(scoped, _sharedPreferences.getBool(base)!);
    }
    if (hasAnyScope || _sharedPreferences.containsKey(scoped)) {
      _sharedPreferences.remove(base);
    }
  }

  void _migrateInsiderFeature({
    required String featureKey,
    required String legacyKey,
    bool includeUnlock = false,
  }) {
    final alreadyDone = _featureRecorded(featureKey);
    if (alreadyDone) {
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

  bool _featureRecorded(String featureKey) {
    for (final key in [
      featureKey,
      '$featureKey.mainnet',
      '$featureKey.testnet',
      '${featureKey}Central',
      '${featureKey}Central.mainnet',
      '${featureKey}Central.testnet',
      '${featureKey}Insider',
      '${featureKey}Insider.mainnet',
      '${featureKey}Insider.testnet',
    ]) {
      if (_sharedPreferences.containsKey(key)) return true;
    }
    return false;
  }

  void _migrateSplitFeature({
    required String featureKey,
    required String userOffKey,
    required String centralKey,
    required String insiderKey,
  }) {
    final done =
        _sharedPreferences.containsKey(centralKey) ||
        _sharedPreferences.containsKey(insiderKey) ||
        _sharedPreferences.containsKey('$centralKey.mainnet') ||
        _sharedPreferences.containsKey('$centralKey.testnet') ||
        _sharedPreferences.containsKey('$insiderKey.mainnet') ||
        _sharedPreferences.containsKey('$insiderKey.testnet');
    if (done) {
      _sharedPreferences.remove(featureKey);
      _sharedPreferences.remove(userOffKey);
      return;
    }
    if (!_sharedPreferences.containsKey(featureKey) &&
        !_sharedPreferences.containsKey(userOffKey)) {
      return;
    }
    final oldOn = _sharedPreferences.getBool(featureKey) == true;
    final userOff = _sharedPreferences.getBool(userOffKey) == true;
    _sharedPreferences.setBool(insiderKey, oldOn && !userOff);
    _sharedPreferences.remove(featureKey);
    _sharedPreferences.remove(userOffKey);
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

  bool get networkOptionsEnabled =>
      _sharedPreferences.getBool('networkOptionsEnabled') ?? false;
  set networkOptionsEnabled(bool enabled) =>
      _sharedPreferences.setBool('networkOptionsEnabled', enabled);

  // Effective flag is central OR insider, for the selected network. The setter
  // is the server path and only latches central. User switches use the methods
  // below and do nothing once central is latched.
  bool get walletFeaturePay =>
      walletFeaturePayCentral ||
      (_sharedPreferences.getBool(_scoped('walletFeaturePayInsider')) ?? false);
  set walletFeaturePay(bool value) {
    if (value) {
      _sharedPreferences.setBool(_scoped('walletFeaturePayCentral'), true);
    }
  }

  bool get walletFeatureSend =>
      walletFeatureSendCentral ||
      (_sharedPreferences.getBool(_scoped('walletFeatureSendInsider')) ?? false);
  set walletFeatureSend(bool value) {
    if (value) {
      _sharedPreferences.setBool(_scoped('walletFeatureSendCentral'), true);
    }
  }

  bool get walletFeaturePromoCode =>
      walletFeaturePromoCodeCentral ||
      (_sharedPreferences.getBool(_scoped('walletFeaturePromoCodeInsider')) ?? false);
  set walletFeaturePromoCode(bool value) {
    if (value) {
      _sharedPreferences.setBool(_scoped('walletFeaturePromoCodeCentral'), true);
    }
  }

  bool get walletFeatureReferral =>
      walletFeatureReferralCentral ||
      (_sharedPreferences.getBool(_scoped('walletFeatureReferralInsider')) ?? false);
  set walletFeatureReferral(bool value) {
    if (value) {
      _sharedPreferences.setBool(_scoped('walletFeatureReferralCentral'), true);
    }
  }

  bool get walletFeaturePayCentral =>
      _sharedPreferences.getBool(_scoped('walletFeaturePayCentral')) ?? false;
  bool get walletFeatureSendCentral =>
      _sharedPreferences.getBool(_scoped('walletFeatureSendCentral')) ?? false;
  bool get walletFeaturePromoCodeCentral =>
      _sharedPreferences.getBool(_scoped('walletFeaturePromoCodeCentral')) ?? false;
  bool get walletFeatureReferralCentral =>
      _sharedPreferences.getBool(_scoped('walletFeatureReferralCentral')) ?? false;

  void setWalletFeaturePayFromUser(bool enabled) {
    if (walletFeaturePayCentral) return;
    _sharedPreferences.setBool(_scoped('walletFeaturePayInsider'), enabled);
  }

  void setWalletFeatureSendFromUser(bool enabled) {
    if (walletFeatureSendCentral) return;
    _sharedPreferences.setBool(_scoped('walletFeatureSendInsider'), enabled);
  }

  void setWalletFeaturePromoCodeFromUser(bool enabled) {
    if (walletFeaturePromoCodeCentral) return;
    _sharedPreferences.setBool(_scoped('walletFeaturePromoCodeInsider'), enabled);
  }

  void setWalletFeatureReferralFromUser(bool enabled) {
    if (walletFeatureReferralCentral) return;
    _sharedPreferences.setBool(_scoped('walletFeatureReferralInsider'), enabled);
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
