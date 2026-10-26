part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object> get props => [];
}

final class SetLanguageEvent extends SettingsEvent {
  final Language language;

  const SetLanguageEvent(this.language);

  @override
  List<Object> get props => [language];
}

final class SetCurrencyEvent extends SettingsEvent {
  final Currency currency;

  const SetCurrencyEvent(this.currency);

  @override
  List<Object> get props => [currency];
}

/// Account currency from GET /v2/user. Applied only when the user has not
/// stored a local preference. Not written to prefs.
final class ApplyAccountCurrencyEvent extends SettingsEvent {
  final Currency currency;

  const ApplyAccountCurrencyEvent(this.currency);

  @override
  List<Object> get props => [currency];
}

/// Drops a non-persisted account default (wallet closed or switched).
final class ClearAccountCurrencyEvent extends SettingsEvent {
  const ClearAccountCurrencyEvent();
}

/// Pay access of the open account from GET /v2/user
/// (`capabilities.canPayWithRealUnit`). Not written to prefs.
final class ApplyAccountPayAccessEvent extends SettingsEvent {
  final bool allowed;

  const ApplyAccountPayAccessEvent(this.allowed);

  @override
  List<Object> get props => [allowed];
}

/// Forgets the pay access (wallet closed or switched): it is unknown until the
/// next account is loaded.
final class ClearAccountPayAccessEvent extends SettingsEvent {
  const ClearAccountPayAccessEvent();
}

final class SetNetworkModeEvent extends SettingsEvent {
  final NetworkMode networkMode;

  const SetNetworkModeEvent(this.networkMode);

  @override
  List<Object> get props => [networkMode];
}

final class ToggleHideAmountEvent extends SettingsEvent {
  const ToggleHideAmountEvent();
}

final class UnlockInsiderFeaturesEvent extends SettingsEvent {
  const UnlockInsiderFeaturesEvent();
}

final class RefreshWalletFeaturesEvent extends SettingsEvent {
  const RefreshWalletFeaturesEvent();
}

enum InsiderFeature { networkOptions, pay, send, referral, bonus }

final class SetInsiderFeatureEnabledEvent extends SettingsEvent {
  const SetInsiderFeatureEnabledEvent(this.feature, this.enabled);

  final InsiderFeature feature;
  final bool enabled;

  @override
  List<Object> get props => [feature, enabled];
}
