import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_page.dart';
import 'package:realunit_wallet/screens/startup_failure/widgets/startup_failure_reset_sheet.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

import '../../helper/pump_app.dart';

class _MockStartupFailureCubit extends MockCubit<StartupFailureState>
    implements StartupFailureCubit {}

class _RecordingUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}

void main() {
  late _MockStartupFailureCubit cubit;
  late UrlLauncherPlatform originalLauncher;
  late _RecordingUrlLauncher launcher;

  setUpAll(() {
    originalLauncher = UrlLauncherPlatform.instance;
  });

  tearDownAll(() {
    UrlLauncherPlatform.instance = originalLauncher;
  });

  setUp(() {
    cubit = _MockStartupFailureCubit();
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    when(() => cubit.state).thenReturn(
      const StartupFailureState(canResetWallet: false),
    );
    whenListen(
      cubit,
      const Stream<StartupFailureState>.empty(),
      initialState: const StartupFailureState(canResetWallet: false),
    );
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.resetWallet()).thenAnswer((_) async {});
  });

  Widget buildSubject() => BlocProvider<StartupFailureCubit>.value(
    value: cubit,
    child: const StartupFailurePage(),
  );

  void stubState(StartupFailureState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      const Stream<StartupFailureState>.empty(),
      initialState: state,
    );
  }

  group('StartupFailurePage', () {
    testWidgets('generic failure shows title, description, retry and support', (tester) async {
      stubState(const StartupFailureState(canResetWallet: false));
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.startupFailureTitle), findsOneWidget);
      expect(find.text(S.current.startupFailureDescription), findsOneWidget);
      expect(
        find.widgetWithText(AppFilledButton, S.current.retry),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppFilledButton, S.current.contactSupport),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
        findsNothing,
      );
    });

    testWidgets('missing-key failure shows key-missing description and three buttons', (
      tester,
    ) async {
      stubState(const StartupFailureState(canResetWallet: true));
      await tester.pumpApp(buildSubject());

      expect(
        find.text(S.current.startupFailureKeyMissingDescription),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppFilledButton, S.current.retry),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppFilledButton, S.current.contactSupport),
        findsOneWidget,
      );
    });

    testWidgets('actionFailed shows the hint text', (tester) async {
      stubState(
        const StartupFailureState(
          canResetWallet: false,
          actionFailed: true,
        ),
      );
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.startupFailureActionFailed), findsOneWidget);
    });

    testWidgets('tapping retry calls cubit.retry', (tester) async {
      stubState(const StartupFailureState(canResetWallet: false));
      await tester.pumpApp(buildSubject());

      await tester.tap(find.widgetWithText(AppFilledButton, S.current.retry));
      await tester.pump();

      verify(() => cubit.retry()).called(1);
    });

    testWidgets('busy shows loading on retry and disables reset and support', (tester) async {
      stubState(
        const StartupFailureState(
          canResetWallet: true,
          isBusy: true,
        ),
      );
      await tester.pumpApp(buildSubject());

      final retry = tester.widget<AppFilledButton>(
        find.widgetWithText(AppFilledButton, S.current.retry),
      );
      expect(retry.state, FilledButtonState.loading);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      final reset = tester.widget<AppFilledButton>(
        find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
      );
      expect(reset.onPressed, isNull);

      final support = tester.widget<AppFilledButton>(
        find.widgetWithText(AppFilledButton, S.current.contactSupport),
      );
      expect(support.onPressed, isNull);
    });

    testWidgets(
      'reset sheet confirms after checkbox and closes without calling on dismiss',
      (tester) async {
        stubState(const StartupFailureState(canResetWallet: true));
        await tester.pumpApp(buildSubject());

        await tester.tap(
          find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StartupFailureResetSheet), findsOneWidget);

        final resetInSheet = tester.widget<AppFilledButton>(
          find.descendant(
            of: find.byType(StartupFailureResetSheet),
            matching: find.widgetWithText(AppFilledButton, S.current.reset),
          ),
        );
        expect(resetInSheet.onPressed, isNull);

        await tester.tap(find.text(S.current.startupFailureResetCheck));
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(StartupFailureResetSheet),
            matching: find.widgetWithText(AppFilledButton, S.current.reset),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StartupFailureResetSheet), findsNothing);
        verify(() => cubit.resetWallet()).called(1);
      },
    );

    testWidgets('closing the reset sheet does not call resetWallet', (tester) async {
      stubState(const StartupFailureState(canResetWallet: true));
      await tester.pumpApp(buildSubject());

      await tester.tap(
        find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(StartupFailureResetSheet),
          matching: find.widgetWithText(AppFilledButton, S.current.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StartupFailureResetSheet), findsNothing);
      verifyNever(() => cubit.resetWallet());
    });

    testWidgets('tapping support launches mailto:info@realunit.ch', (tester) async {
      stubState(const StartupFailureState(canResetWallet: false));
      await tester.pumpApp(buildSubject());

      await tester.tap(
        find.widgetWithText(AppFilledButton, S.current.contactSupport),
      );
      await tester.pump();

      expect(launcher.launchedUrls, ['mailto:info@realunit.ch']);
    });

    testWidgets('app resume retries for a generic failure', (tester) async {
      stubState(const StartupFailureState(canResetWallet: false));
      await tester.pumpApp(buildSubject());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => cubit.retry()).called(1);
    });

    testWidgets('app resume does not retry for a missing-key failure', (tester) async {
      stubState(const StartupFailureState(canResetWallet: true));
      await tester.pumpApp(buildSubject());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verifyNever(() => cubit.retry());
    });

    testWidgets('system back action does not pop the page', (tester) async {
      stubState(const StartupFailureState(canResetWallet: false));

      await tester.pumpApp(const Scaffold(body: Text('base-marker')));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => buildSubject()),
        ),
      );
      await tester.pumpAndSettle();

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(StartupFailurePage), findsOneWidget);
      expect(find.text('base-marker'), findsNothing);
    });
  });
}
