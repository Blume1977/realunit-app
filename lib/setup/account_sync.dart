import 'dart:async';

import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';

/// Applies the account defaults from GET /v2/user (display currency and the
/// pay access capability) when a wallet opens or is replaced, and clears the
/// non-persisted defaults when it closes.
///
/// Extracted from [WalletApp] so open / close / A→B can be tested without
/// pumping the full app (same seam idea as boot_navigation).
class AccountSync {
  AccountSync({
    required SettingsBloc settings,
    required DfxKycService kyc,
    required AWallet? Function() currentWallet,
  }) : _settings = settings,
       _kyc = kyc,
       _currentWallet = currentWallet;

  final SettingsBloc _settings;
  final DfxKycService _kyc;
  final AWallet? Function() _currentWallet;

  /// Waits before each retry of a failed GET /v2/user. Without a retry one
  /// failed fetch at open would keep the pay action hidden until the next open.
  static const _retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

  int _generation = 0;
  int? _fetchingGeneration;

  AWallet? get currentWallet => _currentWallet();

  /// Applies an already-fetched GET /v2/user response (KYC path) only if
  /// [captured] is still the open wallet.
  void applyFromUser(UserDto user, {required AWallet? captured}) {
    final open = _currentWallet();
    if (open == null || !identical(open, captured)) return;
    _generation++;
    _dispatch(user);
  }

  void onOpened(AWallet? wallet) {
    final generation = ++_generation;
    unawaited(_apply(generation, wallet));
  }

  void onClosed() {
    _generation++;
    _settings.add(const ClearAccountCurrencyEvent());
    _settings.add(const ClearAccountPayAccessEvent());
  }

  /// Fetches the account again when the app returns to the foreground while
  /// the pay access is still unknown, so an outage longer than the retries at
  /// open does not hide the pay action for the whole session.
  void onResumed() {
    final open = _currentWallet();
    if (open == null || _fetchingGeneration == _generation) return;
    if (_settings.state.payAccess != AccountPayAccess.unknown) return;
    onOpened(open);
  }

  void onSwitched(AWallet? wallet) {
    _settings.add(const ClearAccountCurrencyEvent());
    _settings.add(const ClearAccountPayAccessEvent());
    onOpened(wallet);
  }

  Future<void> _apply(int generation, AWallet? captured) async {
    _fetchingGeneration = generation;
    try {
      await _fetch(generation, captured);
    } finally {
      if (_fetchingGeneration == generation) _fetchingGeneration = null;
    }
  }

  Future<void> _fetch(int generation, AWallet? captured) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final user = await _kyc.getUser();
        if (!_isCurrent(generation, captured)) return;
        _dispatch(user);
        return;
      } catch (_) {
        // Account defaults are display state; boot must not fail if /v2/user is
        // unavailable. After the last retry pay access stays unknown and the pay
        // action hidden.
        if (attempt >= _retryDelays.length) return;
      }
      await Future<void>.delayed(_retryDelays[attempt]);
      if (!_isCurrent(generation, captured)) return;
    }
  }

  bool _isCurrent(int generation, AWallet? captured) =>
      generation == _generation && identical(_currentWallet(), captured);

  void _dispatch(UserDto user) {
    final currency = user.currency;
    if (currency != null) _settings.add(ApplyAccountCurrencyEvent(currency));
    // A backend without the capability (null) does not gate pay: the action
    // behaves as before the capability existed.
    _settings.add(
      ApplyAccountPayAccessEvent(user.capabilities.canPayWithRealUnit ?? true),
    );
  }
}
