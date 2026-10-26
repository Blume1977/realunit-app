import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/sections/dashboard_actions.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/widgets/action_button.dart';

import '../../../../helper/helper.dart';

class _BitboxWallet extends Fake implements BitboxWallet {
  @override
  WalletType get walletType => WalletType.bitbox;
}

class _DebugWallet extends Fake implements DebugWallet {
  @override
  WalletType get walletType => WalletType.debug;
}

void main() {
  late List<String> pushedRoutes;
  late MockSettingsBloc settingsBloc;
  late MockHomeBloc homeBloc;

  HomeState homeWith(AWallet wallet) => HomeState(
    hasWallet: true,
    openWallet: wallet,
  );

  setUp(() {
    pushedRoutes = <String>[];
    settingsBloc = MockSettingsBloc();
    homeBloc = MockHomeBloc();
    when(() => homeBloc.state).thenReturn(
      homeWith(SoftwareViewWallet(1, 'Software', '0x0000000000000000000000000000000000000001')),
    );
  });

  GoRouter buildRouter() {
    GoRoute target(String name, String path) => GoRoute(
      name: name,
      path: path,
      builder: (_, _) {
        pushedRoutes.add(name);
        return Scaffold(body: Text('ROUTE:$name'));
      },
    );

    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsBloc>.value(value: settingsBloc),
                BlocProvider<HomeBloc>.value(value: homeBloc),
              ],
              child: const DashboardActions(),
            ),
          ),
        ),
        target(AppRoutes.buy, '/buy'),
        target(AppRoutes.sell, '/sell'),
        target(AppRoutes.pay, '/pay'),
      ],
    );
  }

  Future<void> pumpActions(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [S.delegate, GlobalMaterialLocalizations.delegate],
        supportedLocales: S.delegate.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder actionButtonByLabel(String label) =>
      find.byWidgetPredicate((w) => w is ActionButton && w.label == label);

  group('$DashboardActions', () {
    group('locked (default)', () {
      setUp(() {
        when(() => settingsBloc.state).thenReturn(const SettingsState());
      });

      testWidgets('renders only the buy and sell action buttons', (tester) async {
        await pumpActions(tester);

        expect(actionButtonByLabel(S.current.buy), findsOneWidget);
        expect(actionButtonByLabel(S.current.sell), findsOneWidget);
        expect(actionButtonByLabel(S.current.pay), findsNothing);
        expect(actionButtonByLabel(S.current.send), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(2));
      });

      testWidgets('buy button pushes the buy route', (tester) async {
        await pumpActions(tester);
        await tester.tap(actionButtonByLabel(S.current.buy));
        await tester.pumpAndSettle();
        expect(pushedRoutes, [AppRoutes.buy]);
      });

      testWidgets('sell button pushes the sell route', (tester) async {
        await pumpActions(tester);
        await tester.tap(actionButtonByLabel(S.current.sell));
        await tester.pumpAndSettle();
        expect(pushedRoutes, [AppRoutes.sell]);
      });
    });

    group('unlocked', () {
      setUp(() {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(walletFeaturePay: true, payAccess: AccountPayAccess.allowed),
        );
      });

      testWidgets('renders the buy, sell and pay action buttons', (tester) async {
        await pumpActions(tester);

        expect(actionButtonByLabel(S.current.buy), findsOneWidget);
        expect(actionButtonByLabel(S.current.sell), findsOneWidget);
        expect(actionButtonByLabel(S.current.pay), findsOneWidget);
        expect(actionButtonByLabel(S.current.send), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(3));
      });

      testWidgets('renders the expected icons for each action', (tester) async {
        await pumpActions(tester);

        expect(find.byIcon(Icons.add_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.do_not_disturb_on_rounded), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
      });

      testWidgets('buy button pushes the buy route', (tester) async {
        await pumpActions(tester);
        await tester.tap(actionButtonByLabel(S.current.buy));
        await tester.pumpAndSettle();
        expect(pushedRoutes, [AppRoutes.buy]);
      });

      testWidgets('sell button pushes the sell route', (tester) async {
        await pumpActions(tester);
        await tester.tap(actionButtonByLabel(S.current.sell));
        await tester.pumpAndSettle();
        expect(pushedRoutes, [AppRoutes.sell]);
      });

      testWidgets('pay button pushes the pay route', (tester) async {
        await pumpActions(tester);
        await tester.tap(actionButtonByLabel(S.current.pay));
        await tester.pumpAndSettle();
        expect(pushedRoutes, [AppRoutes.pay]);
      });
    });

    group('BitBox', () {
      setUp(() {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(walletFeaturePay: true, payAccess: AccountPayAccess.allowed),
        );
        when(() => homeBloc.state).thenReturn(homeWith(_BitboxWallet()));
      });

      testWidgets('does not offer pay even when the insider switch is on', (tester) async {
        await pumpActions(tester);

        expect(actionButtonByLabel(S.current.buy), findsOneWidget);
        expect(actionButtonByLabel(S.current.sell), findsOneWidget);
        expect(actionButtonByLabel(S.current.pay), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(2));
      });
    });

    group('debug wallet', () {
      setUp(() {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(walletFeaturePay: true, payAccess: AccountPayAccess.allowed),
        );
        when(() => homeBloc.state).thenReturn(homeWith(_DebugWallet()));
      });

      testWidgets('does not offer pay', (tester) async {
        await pumpActions(tester);
        expect(actionButtonByLabel(S.current.pay), findsNothing);
      });
    });

    group('account pay access', () {
      testWidgets('hides pay while the account access is still unknown', (tester) async {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(walletFeaturePay: true),
        );
        await pumpActions(tester);

        expect(actionButtonByLabel(S.current.buy), findsOneWidget);
        expect(actionButtonByLabel(S.current.sell), findsOneWidget);
        expect(actionButtonByLabel(S.current.pay), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(2));
      });

      testWidgets('hides pay when the API does not allow it for the account', (tester) async {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(walletFeaturePay: true, payAccess: AccountPayAccess.notAllowed),
        );
        await pumpActions(tester);

        expect(actionButtonByLabel(S.current.pay), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(2));
      });
    });

    group('showPayAction', () {
      test('software wallet with the switch on and an allowed account', () {
        expect(
          showPayAction(
            walletFeaturePay: true,
            walletType: WalletType.software,
            payAccess: AccountPayAccess.allowed,
          ),
          isTrue,
        );
      });

      test('bitbox, debug, and a missing wallet stay off', () {
        for (final walletType in [WalletType.bitbox, WalletType.debug, null]) {
          expect(
            showPayAction(
              walletFeaturePay: true,
              walletType: walletType,
              payAccess: AccountPayAccess.allowed,
            ),
            isFalse,
          );
        }
        expect(
          showPayAction(
            walletFeaturePay: false,
            walletType: WalletType.software,
            payAccess: AccountPayAccess.allowed,
          ),
          isFalse,
        );
      });

      test('an unknown or refused account access stays off', () {
        for (final payAccess in [AccountPayAccess.unknown, AccountPayAccess.notAllowed]) {
          expect(
            showPayAction(
              walletFeaturePay: true,
              walletType: WalletType.software,
              payAccess: payAccess,
            ),
            isFalse,
          );
        }
      });
    });

    group('transitions', () {
      testWidgets(
        'rebuilds from locked to unlocked when the bloc emits without a remount '
        '(pins context.watch, a regression to context.read would not react)',
        (tester) async {
          final controller = StreamController<SettingsState>();
          addTearDown(controller.close);
          whenListen(
            settingsBloc,
            controller.stream,
            initialState: const SettingsState(),
          );

          await pumpActions(tester);

          expect(actionButtonByLabel(S.current.pay), findsNothing);
          expect(actionButtonByLabel(S.current.send), findsNothing);

          controller.add(
            const SettingsState(walletFeaturePay: true, payAccess: AccountPayAccess.allowed),
          );
          // Two pumps: the first delivers the stream event (async broadcast
          // delivery updates the mock's state and marks the element dirty),
          // the second builds the frame that shows the unlocked buttons.
          await tester.pump();
          await tester.pump();

          expect(actionButtonByLabel(S.current.pay), findsOneWidget);
          expect(actionButtonByLabel(S.current.send), findsNothing);
        },
      );
    });
  });
}
