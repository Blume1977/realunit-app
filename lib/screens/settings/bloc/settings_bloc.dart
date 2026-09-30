import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:realunit_wallet/packages/service/dfx/models/wallet_features/dto/real_unit_wallet_features_dto.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(
    this._settingsRepository,
    this.getNewAuthToken, {
    this.onNetworkModeChanged,
    this.fetchWalletFeatures,
  }) : super(
         SettingsState(
           language: Language.fromCode(_settingsRepository.language),
           currency: Currency.fromCode(_settingsRepository.currency),
           networkMode: _settingsRepository.networkMode,
           insiderFeaturesUnlocked: _settingsRepository.insiderFeaturesUnlocked,
           walletFeaturePay: _settingsRepository.walletFeaturePay,
           walletFeatureSend: _settingsRepository.walletFeatureSend,
           walletFeaturePromoCode: _settingsRepository.walletFeaturePromoCode,
           walletFeatureReferral: _settingsRepository.walletFeatureReferral,
           walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
           walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
           walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
           walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
         ),
       ) {
    on<SetCurrencyEvent>(_onSetCurrencyEvent);
    on<ApplyAccountCurrencyEvent>(_onApplyAccountCurrencyEvent);
    on<ClearAccountCurrencyEvent>(_onClearAccountCurrencyEvent);
    on<SetLanguageEvent>(_onSetLanguageEvent);
    on<SetNetworkModeEvent>(_onSetNetworkModeEvent);
    on<ToggleHideAmountEvent>(_onToggleHideAmountEvent);
    on<UnlockInsiderFeaturesEvent>(_onUnlockInsiderFeaturesEvent);
    on<SetInsiderFeatureEnabledEvent>(_onSetInsiderFeatureEnabledEvent);
    on<RefreshWalletFeaturesEvent>(_onRefreshWalletFeaturesEvent);
    if (fetchWalletFeatures != null) {
      add(const RefreshWalletFeaturesEvent());
    }
  }

  final SettingsRepository _settingsRepository;
  final Future<void> Function() getNewAuthToken;

  /// Called after the network mode has been persisted and a fresh auth token
  /// has been fetched, but before the new state is emitted. Used to invalidate
  /// reference-data caches (fiats, languages) that are scoped per backend.
  final void Function()? onNetworkModeChanged;

  final Future<RealUnitWalletFeaturesDto> Function()? fetchWalletFeatures;

  void _onSetLanguageEvent(SetLanguageEvent event, Emitter<SettingsState> emit) {
    _settingsRepository.language = event.language.code;
    emit(state.copyWith(language: event.language));
  }

  void _onSetCurrencyEvent(SetCurrencyEvent event, Emitter<SettingsState> emit) {
    _settingsRepository.currency = event.currency.code;
    emit(state.copyWith(currency: event.currency));
  }

  void _onApplyAccountCurrencyEvent(
    ApplyAccountCurrencyEvent event,
    Emitter<SettingsState> emit,
  ) {
    if (_settingsRepository.hasStoredCurrency) return;
    emit(state.copyWith(currency: event.currency));
  }

  void _onClearAccountCurrencyEvent(
    ClearAccountCurrencyEvent event,
    Emitter<SettingsState> emit,
  ) {
    if (_settingsRepository.hasStoredCurrency) return;
    emit(state.copyWith(currency: Currency.fromCode(_settingsRepository.currency)));
  }

  Future<void> _onSetNetworkModeEvent(
    SetNetworkModeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    _settingsRepository.networkMode = event.networkMode;
    await getNewAuthToken();
    onNetworkModeChanged?.call();
    emit(state.copyWith(networkMode: event.networkMode));
  }

  void _onToggleHideAmountEvent(ToggleHideAmountEvent event, Emitter<SettingsState> emit) {
    emit(state.copyWith(hideAmounts: !state.hideAmounts));
  }

  void _onUnlockInsiderFeaturesEvent(
    UnlockInsiderFeaturesEvent event,
    Emitter<SettingsState> emit,
  ) {
    _settingsRepository.insiderFeaturesUnlocked = true;
    _settingsRepository.setWalletFeaturePayFromUser(true);
    _settingsRepository.setWalletFeatureSendFromUser(true);
    _settingsRepository.setWalletFeaturePromoCodeFromUser(true);
    _settingsRepository.setWalletFeatureReferralFromUser(true);
    emit(
      state.copyWith(
        insiderFeaturesUnlocked: true,
        walletFeaturePay: _settingsRepository.walletFeaturePay,
        walletFeatureSend: _settingsRepository.walletFeatureSend,
        walletFeaturePromoCode: _settingsRepository.walletFeaturePromoCode,
        walletFeatureReferral: _settingsRepository.walletFeatureReferral,
        walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
        walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
        walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
        walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
      ),
    );
  }

  Future<void> _onRefreshWalletFeaturesEvent(
    RefreshWalletFeaturesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final fetch = fetchWalletFeatures;
    if (fetch == null) return;
    try {
      final features = await fetch();
      _settingsRepository.walletFeaturePay = features.pay;
      _settingsRepository.walletFeatureSend = features.send;
      _settingsRepository.walletFeaturePromoCode = features.promoCode;
      _settingsRepository.walletFeatureReferral = features.referral;
      emit(
        state.copyWith(
          walletFeaturePay: _settingsRepository.walletFeaturePay,
          walletFeatureSend: _settingsRepository.walletFeatureSend,
          walletFeaturePromoCode: _settingsRepository.walletFeaturePromoCode,
          walletFeatureReferral: _settingsRepository.walletFeatureReferral,
          walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
          walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
          walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
          walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
        ),
      );
    } catch (_) {}
  }

  void _onSetInsiderFeatureEnabledEvent(
    SetInsiderFeatureEnabledEvent event,
    Emitter<SettingsState> emit,
  ) {
    switch (event.feature) {
      case InsiderFeature.pay:
        _settingsRepository.setWalletFeaturePayFromUser(event.enabled);
        emit(
          state.copyWith(
            walletFeaturePay: _settingsRepository.walletFeaturePay,
            walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
            walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
            walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
            walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
          ),
        );
      case InsiderFeature.send:
        _settingsRepository.setWalletFeatureSendFromUser(event.enabled);
        emit(
          state.copyWith(
            walletFeatureSend: _settingsRepository.walletFeatureSend,
            walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
            walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
            walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
            walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
          ),
        );
      case InsiderFeature.referral:
        _settingsRepository.setWalletFeatureReferralFromUser(event.enabled);
        emit(
          state.copyWith(
            walletFeatureReferral: _settingsRepository.walletFeatureReferral,
            walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
            walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
            walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
            walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
          ),
        );
      case InsiderFeature.bonus:
        _settingsRepository.setWalletFeaturePromoCodeFromUser(event.enabled);
        emit(
          state.copyWith(
            walletFeaturePromoCode: _settingsRepository.walletFeaturePromoCode,
            walletFeaturePayCentral: _settingsRepository.walletFeaturePayCentral,
            walletFeatureSendCentral: _settingsRepository.walletFeatureSendCentral,
            walletFeaturePromoCodeCentral: _settingsRepository.walletFeaturePromoCodeCentral,
            walletFeatureReferralCentral: _settingsRepository.walletFeatureReferralCentral,
          ),
        );
    }
  }
}
