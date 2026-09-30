part of 'settings_bloc.dart';

final class SettingsState {
  const SettingsState({
    this.language = Language.en,
    this.currency = Currency.chf,
    this.networkMode = NetworkMode.mainnet,
    this.hideAmounts = false,
    this.insiderFeaturesUnlocked = false,
    bool walletFeaturePay = false,
    bool walletFeatureSend = false,
    bool walletFeaturePromoCode = false,
    bool walletFeatureReferral = false,
    this.walletFeaturePayCentral = false,
    this.walletFeatureSendCentral = false,
    this.walletFeaturePromoCodeCentral = false,
    this.walletFeatureReferralCentral = false,
    bool insiderPayEnabled = false,
    bool insiderSendEnabled = false,
    bool insiderReferralEnabled = false,
    bool insiderBonusEnabled = false,
  }) : walletFeaturePay = walletFeaturePay || insiderPayEnabled,
       walletFeatureSend = walletFeatureSend || insiderSendEnabled,
       walletFeaturePromoCode = walletFeaturePromoCode || insiderBonusEnabled,
       walletFeatureReferral = walletFeatureReferral || insiderReferralEnabled;

  final Language language;
  final Currency currency;
  final NetworkMode networkMode;
  final bool hideAmounts;
  final bool insiderFeaturesUnlocked;
  final bool walletFeaturePay;
  final bool walletFeatureSend;
  final bool walletFeaturePromoCode;
  final bool walletFeatureReferral;
  final bool walletFeaturePayCentral;
  final bool walletFeatureSendCentral;
  final bool walletFeaturePromoCodeCentral;
  final bool walletFeatureReferralCentral;

  bool get insiderPayEnabled => walletFeaturePay;
  bool get insiderSendEnabled => walletFeatureSend;
  bool get insiderReferralEnabled => walletFeatureReferral;
  bool get insiderBonusEnabled => walletFeaturePromoCode;

  SettingsState copyWith({
    Language? language,
    Currency? currency,
    NetworkMode? networkMode,
    bool? hideAmounts,
    bool? insiderFeaturesUnlocked,
    bool? walletFeaturePay,
    bool? walletFeatureSend,
    bool? walletFeaturePromoCode,
    bool? walletFeatureReferral,
    bool? walletFeaturePayCentral,
    bool? walletFeatureSendCentral,
    bool? walletFeaturePromoCodeCentral,
    bool? walletFeatureReferralCentral,
  }) => SettingsState(
    language: language ?? this.language,
    currency: currency ?? this.currency,
    networkMode: networkMode ?? this.networkMode,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    insiderFeaturesUnlocked: insiderFeaturesUnlocked ?? this.insiderFeaturesUnlocked,
    walletFeaturePay: walletFeaturePay ?? this.walletFeaturePay,
    walletFeatureSend: walletFeatureSend ?? this.walletFeatureSend,
    walletFeaturePromoCode: walletFeaturePromoCode ?? this.walletFeaturePromoCode,
    walletFeatureReferral: walletFeatureReferral ?? this.walletFeatureReferral,
    walletFeaturePayCentral: walletFeaturePayCentral ?? this.walletFeaturePayCentral,
    walletFeatureSendCentral: walletFeatureSendCentral ?? this.walletFeatureSendCentral,
    walletFeaturePromoCodeCentral:
        walletFeaturePromoCodeCentral ?? this.walletFeaturePromoCodeCentral,
    walletFeatureReferralCentral: walletFeatureReferralCentral ?? this.walletFeatureReferralCentral,
  );
}
