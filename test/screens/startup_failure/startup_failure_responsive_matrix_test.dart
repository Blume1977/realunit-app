// Responsive matrix gate for StartupFailurePage + StartupFailureResetSheet.
//
// Proves sticky CTAs stay fully tappable across the full device × text-scale
// matrix under the worst-case missing-key + actionFailed set (longest DE copy,
// three buttons, failure hint) and for the reset confirmation sheet.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_page.dart';
import 'package:realunit_wallet/screens/startup_failure/widgets/startup_failure_reset_sheet.dart';
import 'package:realunit_wallet/styles/themes.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

import '../../helper/helper.dart';

class _MockStartupFailureCubit extends MockCubit<StartupFailureState>
    implements StartupFailureCubit {}

class _FakeUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
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
  }) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => true;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  S.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

const _openSheetKey = Key('startup_failure_matrix.open');

const _worstCaseState = StartupFailureState(
  canResetWallet: true,
  actionFailed: true,
);

void main() {
  late _MockStartupFailureCubit cubit;
  late UrlLauncherPlatform originalLauncher;

  setUpAll(() {
    originalLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncher();
  });

  tearDownAll(() {
    UrlLauncherPlatform.instance = originalLauncher;
  });

  setUp(() {
    cubit = _MockStartupFailureCubit();
    when(() => cubit.state).thenReturn(_worstCaseState);
    whenListen(
      cubit,
      const Stream<StartupFailureState>.empty(),
      initialState: _worstCaseState,
    );
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.resetWallet()).thenAnswer((_) async {});
  });

  Widget buildPage() => BlocProvider<StartupFailureCubit>.value(
    value: cubit,
    child: const StartupFailurePage(),
  );

  Future<void> pumpPage(
    WidgetTester tester,
    MatrixCell cell,
  ) async {
    await tester.binding.setSurfaceSize(cell.mediaQuery.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: cell.mediaQuery,
        child: MaterialApp(
          theme: realUnitTheme,
          locale: const Locale('de'),
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: S.delegate.supportedLocales,
          home: buildPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpAndOpenSheet(
    WidgetTester tester,
    MatrixCell cell,
  ) async {
    await tester.binding.setSurfaceSize(cell.mediaQuery.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: cell.mediaQuery,
        child: MaterialApp(
          theme: realUnitTheme,
          locale: const Locale('de'),
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: _openSheetKey,
                  onPressed: () {
                    showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const StartupFailureResetSheet(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(_openSheetKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('StartupFailurePage responsive matrix (full device × textScale)', () {
    for (final cell in kFullResponsiveMatrix) {
      testWidgets(cell.id, (tester) async {
        await withTargetPlatform(cell.device.platform, () async {
          await expectNoLayoutOverflow(
            tester,
            () async {
              await pumpPage(tester, cell);
            },
            reason: 'overflow on ${cell.label}',
          );

          final retry = find.widgetWithText(AppFilledButton, S.current.retry);
          await tester.ensureVisible(retry);
          await tester.pump();
          await expectFullyTappable(
            tester,
            retry,
            within: find.byType(StartupFailurePage),
            reason: '${cell.label}: Retry not tappable',
          );

          final reset = find.widgetWithText(
            AppFilledButton,
            S.current.settingsDeleteWallet,
          );
          await tester.ensureVisible(reset);
          await tester.pump();
          await expectFullyTappable(
            tester,
            reset,
            within: find.byType(StartupFailurePage),
            reason: '${cell.label}: Reset wallet not tappable',
          );

          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(StartupFailureResetSheet), findsNothing);

          final support = find.widgetWithText(
            AppFilledButton,
            S.current.contactSupport,
          );
          await tester.ensureVisible(support);
          await tester.pump();
          await expectFullyTappable(
            tester,
            support,
            within: find.byType(StartupFailurePage),
            reason: '${cell.label}: Contact support not tappable',
          );
        });
      });
    }
  });

  group('StartupFailureResetSheet responsive matrix (full device × textScale)', () {
    for (final cell in kFullResponsiveMatrix) {
      testWidgets('resetSheet · ${cell.id}', (tester) async {
        await withTargetPlatform(cell.device.platform, () async {
          await expectNoLayoutOverflow(
            tester,
            () async {
              await pumpAndOpenSheet(tester, cell);
            },
            reason: 'StartupFailureResetSheet overflow / ${cell.label}',
          );

          final closeButton = find.descendant(
            of: find.byType(StartupFailureResetSheet),
            matching: find.widgetWithText(AppFilledButton, S.current.close),
          );
          await tester.ensureVisible(closeButton);
          await tester.pump();
          await expectFullyTappable(
            tester,
            closeButton,
            within: find.byType(StartupFailureResetSheet),
            reason: 'StartupFailureResetSheet / ${cell.label}: Close not tappable',
          );

          await tester.pumpAndSettle();
          expect(find.byType(StartupFailureResetSheet), findsNothing);

          await tester.tap(find.byKey(_openSheetKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final checkboxLabel = find.text(S.current.startupFailureResetCheck);
          await tester.ensureVisible(checkboxLabel);
          await tester.pump();
          await tester.tap(checkboxLabel);
          await tester.pump();

          final resetButton = find.descendant(
            of: find.byType(StartupFailureResetSheet),
            matching: find.widgetWithText(AppFilledButton, S.current.reset),
          );
          final reset = tester.widget<AppFilledButton>(resetButton);
          expect(reset.onPressed, isNotNull);

          await tester.ensureVisible(resetButton);
          await tester.pump();
          await expectFullyTappable(
            tester,
            resetButton,
            within: find.byType(StartupFailureResetSheet),
            reason: 'StartupFailureResetSheet / ${cell.label}: Reset not tappable',
          );
        });
      });
    }
  });
}
