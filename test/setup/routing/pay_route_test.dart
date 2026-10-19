import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_info_page.dart';
import 'package:realunit_wallet/screens/pay/pay_scan_page.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/setup/routing/router_config.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';

import '../../helper/helper.dart';

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class _BitboxWallet extends Fake implements BitboxWallet {
  @override
  WalletType get walletType => WalletType.bitbox;
}

final _softwareWallet = SoftwareViewWallet(
  1,
  'Software',
  '0x0000000000000000000000000000000000000001',
);

void main() {
  late _MockHomeBloc homeBloc;

  setUpAll(() {
    // /pay lands on PayInfoPage (no camera). The stub stays so a later
    // Continue onto PayScanPage in other tests does not throw MissingPluginException.
    stubMobileScannerChannel();
  });

  setUp(() {
    homeBloc = _MockHomeBloc();
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeState(),
    );
  });

  // Mirrors the production wiring in main.dart: the routed pages read their
  // blocs from above MaterialApp.router, so HomeBloc (used by the initial
  // /home route) is provided here. Navigation then drives the real
  // `routerConfig` to the /pay GoRoute under test.
  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<HomeBloc>.value(
        value: homeBloc,
        child: MaterialApp.router(
          routerConfig: routerConfig,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the pay route builds PayInfoPage', (tester) async {
    await pumpRouter(tester);

    routerConfig.goNamed(AppRoutes.pay);
    await tester.pumpAndSettle();

    expect(find.byType(PayInfoPage), findsOneWidget);

    // Restore the router to its initial location so the global singleton
    // does not leak the /pay location into any later test.
    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });

  testWidgets(
    'the pay route passes a String extra through as initialPayload',
    (tester) async {
      await pumpRouter(tester);

      routerConfig.pushNamed(
        AppRoutes.pay,
        extra: 'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
      );
      // A single pump is not enough for an imperative pushNamed to land in
      // the tree yet, and pumpAndSettle is unsafe here (PayScanView shows an
      // indefinitely-animating CupertinoActivityIndicator once initialPayload
      // is set). Two plain pumps reliably lands the pushed route.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<PayInfoPage>(find.byType(PayInfoPage)).initialPayload,
        'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
      );

      addTearDown(() => routerConfig.goNamed(AppRoutes.home));
    },
  );

  testWidgets(
    'the pay route guards a non-String extra to null (never an unchecked cast)',
    (tester) async {
      await pumpRouter(tester);

      routerConfig.pushNamed(AppRoutes.pay, extra: 42);
      // Same reasoning as the test above: two plain pumps, no pumpAndSettle.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<PayInfoPage>(find.byType(PayInfoPage)).initialPayload,
        isNull,
      );

      addTearDown(() => routerConfig.goNamed(AppRoutes.home));
    },
  );

  Future<void> installPayIntroPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    if (getIt.isRegistered<SettingsRepository>()) {
      await getIt.unregister<SettingsRepository>();
    }
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt.unregister<SharedPreferences>();
    }
    getIt.registerSingleton<SharedPreferences>(prefs);
    getIt.registerSingleton<SettingsRepository>(SettingsRepository(prefs));
    addTearDown(() async {
      if (getIt.isRegistered<SettingsRepository>()) {
        await getIt.unregister<SettingsRepository>();
      }
      if (getIt.isRegistered<SharedPreferences>()) {
        await getIt.unregister<SharedPreferences>();
      }
    });
  }

  testWidgets('a software wallet sees the pay intro once', (tester) async {
    await installPayIntroPrefs(const {});
    await pumpRouter(tester);
    when(() => homeBloc.state).thenReturn(HomeState(hasWallet: true, openWallet: _softwareWallet));

    routerConfig.goNamed(AppRoutes.pay);
    await tester.pumpAndSettle();

    expect(find.byType(PayInfoPage), findsOneWidget);
    expect(find.text(S.current.payInfoTitle), findsOneWidget);
    expect(getIt<SettingsRepository>().payIntroSeen, isTrue);

    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });

  testWidgets('the next pay tap opens the scanner and keeps the payload', (tester) async {
    await installPayIntroPrefs(const {'payIntroSeen': true});
    await pumpRouter(tester);
    when(() => homeBloc.state).thenReturn(HomeState(hasWallet: true, openWallet: _softwareWallet));

    routerConfig.pushNamed(AppRoutes.pay, extra: 'not-a-payment-link');
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PayInfoPage), findsNothing);
    expect(
      tester.widget<PayScanPage>(find.byType(PayScanPage)).initialPayload,
      'not-a-payment-link',
    );
    expect(find.text(S.current.payInfoLocationsLink), findsOneWidget);

    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });

  testWidgets('a BitBox wallet is not counted as having seen the intro', (tester) async {
    await installPayIntroPrefs(const {'payIntroSeen': true});
    await pumpRouter(tester);
    when(() => homeBloc.state).thenReturn(HomeState(hasWallet: true, openWallet: _BitboxWallet()));

    routerConfig.goNamed(AppRoutes.pay);
    await tester.pumpAndSettle();

    expect(find.byType(PayInfoPage), findsOneWidget);
    expect(find.byType(PayScanPage), findsNothing);
    expect(find.text(S.current.payFailurePayUnavailable), findsOneWidget);
    expect(getIt<SettingsRepository>().payIntroSeen, isTrue);

    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });

  testWidgets('a software wallet that loads after Pay still sees the intro once', (
    tester,
  ) async {
    await installPayIntroPrefs(const {});
    final states = StreamController<HomeState>();
    addTearDown(states.close);
    whenListen(homeBloc, states.stream, initialState: const HomeState());
    await pumpRouter(tester);

    routerConfig.goNamed(AppRoutes.pay);
    await tester.pumpAndSettle();

    expect(find.text(S.current.payFailurePayUnavailable), findsOneWidget);
    expect(find.text(S.current.payInfoBodyIntro), findsNothing);
    expect(getIt<SettingsRepository>().payIntroSeen, isFalse);

    final loaded = HomeState(hasWallet: true, openWallet: _softwareWallet);
    when(() => homeBloc.state).thenReturn(loaded);
    states.add(loaded);
    await tester.pump();
    await tester.pump();

    expect(find.text(S.current.payInfoBodyIntro), findsOneWidget);
    expect(find.byType(PayScanPage), findsNothing);
    expect(getIt<SettingsRepository>().payIntroSeen, isTrue);

    states.add(loaded);
    await tester.pump();

    expect(find.text(S.current.payInfoBodyIntro), findsOneWidget);
    expect(find.byType(PayScanPage), findsNothing);

    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });

  testWidgets('a scanner visit switches to the unavailable notice for BitBox', (
    tester,
  ) async {
    await installPayIntroPrefs(const {'payIntroSeen': true});
    final states = StreamController<HomeState>();
    addTearDown(states.close);
    final software = HomeState(hasWallet: true, openWallet: _softwareWallet);
    whenListen(homeBloc, states.stream, initialState: software);
    await pumpRouter(tester);

    routerConfig.goNamed(AppRoutes.pay);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PayScanPage), findsOneWidget);
    expect(getIt<SettingsRepository>().payIntroSeen, isTrue);

    final bitbox = HomeState(hasWallet: true, openWallet: _BitboxWallet());
    when(() => homeBloc.state).thenReturn(bitbox);
    states.add(bitbox);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(S.current.payFailurePayUnavailable), findsOneWidget);
    expect(find.byType(PayScanPage), findsNothing);
    expect(getIt<SettingsRepository>().payIntroSeen, isTrue);

    addTearDown(() => routerConfig.goNamed(AppRoutes.home));
  });
}
