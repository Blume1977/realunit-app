import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_app.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/setup/error_handling/crash_reporting.dart';
import 'package:realunit_wallet/setup/startup/wallet_reset.dart';

/// Runs [initialize] (optionally in parallel with a minimum splash delay).
/// On success, does nothing further beyond [removeSplash]. On failure, reports
/// the error and shows [StartupFailureApp] so the user can retry or reset.
Future<void> startApp({
  required Future<void> Function() initialize,
  Duration minimumSplashDuration = Duration.zero,
  void Function()? removeSplash,
  void Function(Widget app) show = runApp,
  TracedNonFatalReporter report = reportNonFatal,
  Future<void> Function() resetDependencies = resetServiceLocator,
  Future<void> Function() resetWallet = resetWalletData,
}) async {
  try {
    await Future.wait([initialize(), Future<void>.delayed(minimumSplashDuration)]);
  } catch (error, stackTrace) {
    report(error, stackTrace: stackTrace);
    show(
      StartupFailureApp(
        error: error,
        restart: () async {
          await resetDependencies();
          await initialize();
        },
        resetWallet: resetWallet,
        languageCode: _languageCode(),
      ),
    );
  } finally {
    removeSplash?.call();
  }
}

String _languageCode() {
  if (getIt.isRegistered<SettingsRepository>()) return getIt<SettingsRepository>().language;
  return PlatformDispatcher.instance.locale.languageCode == 'de' ? 'de' : 'en';
}
