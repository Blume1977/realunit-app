import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_app.dart';
import 'package:realunit_wallet/setup/startup/app_startup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startApp', () {
    test('success runs initialize once, shows nothing, reports nothing, removes splash', () async {
      var initializeCalls = 0;
      var reportCalls = 0;
      var showCalls = 0;
      var removeSplashCalls = 0;

      await startApp(
        initialize: () async {
          initializeCalls++;
        },
        removeSplash: () => removeSplashCalls++,
        show: (_) => showCalls++,
        report: (_, {StackTrace? stackTrace}) => reportCalls++,
        resetDependencies: () async {},
        resetWallet: () async {},
      );

      expect(initializeCalls, 1);
      expect(showCalls, 0);
      expect(reportCalls, 0);
      expect(removeSplashCalls, 1);
    });

    test('failure reports once, shows StartupFailureApp, and removes splash', () async {
      final error = StateError('boot failed');
      Object? reportedError;
      StackTrace? reportedStack;
      Widget? shown;
      var removeSplashCalls = 0;

      await startApp(
        initialize: () async => throw error,
        removeSplash: () => removeSplashCalls++,
        show: (app) => shown = app,
        report: (e, {StackTrace? stackTrace}) {
          reportedError = e;
          reportedStack = stackTrace;
        },
        resetDependencies: () async {},
        resetWallet: () async {},
      );

      expect(reportedError, same(error));
      expect(reportedStack, isNotNull);
      expect(shown, isA<StartupFailureApp>());
      expect((shown! as StartupFailureApp).error, same(error));
      expect(removeSplashCalls, 1);
    });

    test('minimum splash duration delays show and removeSplash on failure', () {
      fakeAsync((async) {
        final error = StateError('boot failed');
        var shown = false;
        var removeSplashCalls = 0;

        startApp(
          initialize: () async => throw error,
          minimumSplashDuration: const Duration(seconds: 3),
          removeSplash: () => removeSplashCalls++,
          show: (_) => shown = true,
          report: (_, {StackTrace? stackTrace}) {},
          resetDependencies: () async {},
          resetWallet: () async {},
        );

        async.flushMicrotasks();
        expect(shown, isFalse);
        expect(removeSplashCalls, 0);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(shown, isFalse);
        expect(removeSplashCalls, 0);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(shown, isTrue);
        expect(removeSplashCalls, 1);
      });
    });

    test('restart resets dependencies first, then re-runs initialize', () async {
      final order = <String>[];
      Widget? shown;

      await startApp(
        initialize: () async {
          order.add('initialize');
          throw StateError('first boot');
        },
        show: (app) => shown = app,
        report: (_, {StackTrace? stackTrace}) {},
        resetDependencies: () async {
          order.add('resetDependencies');
        },
        resetWallet: () async {},
      );

      final failureApp = shown! as StartupFailureApp;
      order.clear();

      await expectLater(failureApp.restart(), throwsA(isA<StateError>()));

      expect(order, ['resetDependencies', 'initialize']);
    });

    test('resetWallet handed to StartupFailureApp is the injected closure', () async {
      var resetWalletCalls = 0;
      Future<void> injectedReset() async {
        resetWalletCalls++;
      }

      Widget? shown;
      await startApp(
        initialize: () async => throw StateError('boot failed'),
        show: (app) => shown = app,
        report: (_, {StackTrace? stackTrace}) {},
        resetDependencies: () async {},
        resetWallet: injectedReset,
      );

      final failureApp = shown! as StartupFailureApp;
      await failureApp.resetWallet();
      expect(resetWalletCalls, 1);
    });

    test('omitting removeSplash does not throw', () async {
      await expectLater(
        startApp(
          initialize: () async {},
          show: (_) {},
          report: (_, {StackTrace? stackTrace}) {},
          resetDependencies: () async {},
          resetWallet: () async {},
        ),
        completes,
      );
    });
  });
}
