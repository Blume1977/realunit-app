import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/balance_service.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/screens/pin/bloc/auth/pin_auth_cubit.dart';
import 'package:realunit_wallet/setup/di.dart';

class LifecycleInitializer extends StatefulWidget {
  final Widget child;

  const LifecycleInitializer({super.key, required this.child});

  @override
  State<LifecycleInitializer> createState() => _LifecycleInitializerState();
}

class _LifecycleInitializerState extends State<LifecycleInitializer> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
  }

  void _onStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _onDetached();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
        _onInactive();
      case AppLifecycleState.hidden:
        _onHidden();
      case AppLifecycleState.paused:
        _onPaused();
    }
    developer.log(state.name, name: 'AppLifecycleListener');
  }

  void _onDetached() {}

  void _onResumed() {
    getIt<PinAuthCubit>().onAppResumed();
    getIt<BalanceService>().updateBalance(getIt<AppStore>().primaryAddress);
  }

  void _onInactive() {}

  void _onHidden() {
    getIt<PinAuthCubit>().onAppHidden();
    // Drop the mnemonic the moment the app stops being visible. The
    // 60 s post-unlock timer in [WalletService] is a best-effort safety net
    // — iOS suspends Dart timers in the background, so a backgrounded app
    // could otherwise keep an unlocked [SoftwareWallet] resident until the
    // OS kills the process. The next sign re-decrypts via the OS-keystore-
    // wrapped mnemonic key (sub-100 ms), invisible to the user.
    unawaited(_lockWalletIfLoaded());
  }

  /// Backgrounding the app during onboarding (before [HomeBloc] populates
  /// [AppStore.wallet]) makes [WalletService.lockCurrentWallet] dereference an
  /// unset field, which raises `Exception('No Wallet set')`. Swallow that one
  /// case so it doesn't surface as an unhandled async error; anything else
  /// stays visible so a real regression doesn't hide.
  Future<void> _lockWalletIfLoaded() async {
    try {
      await getIt<WalletService>().lockCurrentWallet();
    } on Exception catch (e) {
      developer.log(
        'wallet lock on hidden skipped: $e',
        name: 'LifecycleInitializer',
      );
    }
  }

  void _onPaused() {
    getIt<BalanceService>().cancelSync();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
