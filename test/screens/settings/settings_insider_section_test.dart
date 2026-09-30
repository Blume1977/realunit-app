import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_summary_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_referral_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/settings/settings_page.dart';
import 'package:realunit_wallet/screens/settings/widgets/settings_section.dart';
import 'package:realunit_wallet/setup/routing/routes/settings_routes.dart';

import '../../helper/helper.dart';

void main() {
  late MockSettingsBloc settingsBloc;
  late MockHomeBloc homeBloc;
  late MockSoftwareWallet wallet;
  late MockRealUnitReferralService referral;

  setUp(() async {
    await GetIt.instance.reset();
    settingsBloc = MockSettingsBloc();
    homeBloc = MockHomeBloc();
    wallet = MockSoftwareWallet();
    referral = MockRealUnitReferralService();

    when(() => wallet.walletType).thenReturn(WalletType.software);
    when(() => settingsBloc.state).thenReturn(const SettingsState());
    when(() => homeBloc.state).thenReturn(HomeState(openWallet: wallet));
    when(() => referral.getSummary()).thenAnswer(
      (_) async => const ReferralSummaryDto(
        eligible: false,
        termsAccepted: false,
        openCount: 0,
        creditedCount: 0,
        realuSum: 0,
        chfSum: 0,
      ),
    );
    GetIt.instance.registerSingleton<SettingsBloc>(settingsBloc);
    GetIt.instance.registerSingleton<RealUnitReferralService>(referral);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pumpSettings(WidgetTester tester) {
    return tester.pumpWidget(
      wrapForGolden(
        BlocProvider<HomeBloc>.value(
          value: homeBloc,
          child: const SettingsPage(unavailablePollInterval: Duration.zero),
        ),
      ),
    );
  }

  List<String> firstSectionTitles(WidgetTester tester) {
    final section = tester.widget<SettingsSections>(find.byType(SettingsSections).first);
    return section.settings.map((option) => option.title).toList();
  }

  testWidgets('locked: no insider features title and no Switch', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text(S.current.settingsInsiderFeatures), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets(
    'unlocked software wallet: Insider Funktionen row before Wallet-Sicherung, no Switch, no Pay',
    (tester) async {
      when(() => settingsBloc.state)
          .thenReturn(const SettingsState(insiderFeaturesUnlocked: true));

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(S.current.settingsInsiderFeatures), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text(S.current.pay), findsNothing);
      expect(
        firstSectionTitles(tester),
        containsAllInOrder([
          S.current.walletAddress,
          S.current.settingsInsiderFeatures,
          S.current.settingsWalletBackup,
        ]),
      );
      expect(find.text(S.current.settingsNetwork), findsNothing);
    },
  );

  testWidgets(
    'unlocked with networkOptionsEnabled: currency, network, tax report',
    (tester) async {
      when(() => settingsBloc.state).thenReturn(
        const SettingsState(
          insiderFeaturesUnlocked: true,
          networkOptionsEnabled: true,
        ),
      );

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(
        firstSectionTitles(tester),
        containsAllInOrder([
          S.current.settingsCurrency,
          S.current.settingsNetwork,
          S.current.settingsTaxReport,
        ]),
      );
    },
  );

  testWidgets('tapping Insider Funktionen pushes SettingsRoutes.insider', (tester) async {
    when(() => settingsBloc.state)
        .thenReturn(const SettingsState(insiderFeaturesUnlocked: true));

    final pushedRoutes = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<HomeBloc>.value(
            value: homeBloc,
            child: const SettingsPage(unavailablePollInterval: Duration.zero),
          ),
        ),
        GoRoute(
          name: SettingsRoutes.insider,
          path: '/settings/insider',
          builder: (_, _) {
            pushedRoutes.add(SettingsRoutes.insider);
            return const Scaffold(body: Text('ROUTE:insider'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('de'),
        routerConfig: router,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(S.current.settingsInsiderFeatures));
    await tester.tap(find.text(S.current.settingsInsiderFeatures));
    await tester.pumpAndSettle();

    expect(pushedRoutes, [SettingsRoutes.insider]);
  });

  testWidgets('tapping Netzwerk pushes SettingsRoutes.network', (tester) async {
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(
        insiderFeaturesUnlocked: true,
        networkOptionsEnabled: true,
      ),
    );

    final pushedRoutes = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<HomeBloc>.value(
            value: homeBloc,
            child: const SettingsPage(unavailablePollInterval: Duration.zero),
          ),
        ),
        GoRoute(
          name: SettingsRoutes.network,
          path: '/settings/network',
          builder: (_, _) {
            pushedRoutes.add(SettingsRoutes.network);
            return const Scaffold(body: Text('ROUTE:network'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('de'),
        routerConfig: router,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(S.current.settingsNetwork));
    await tester.tap(find.text(S.current.settingsNetwork));
    await tester.pumpAndSettle();

    expect(pushedRoutes, [SettingsRoutes.network]);
  });

  testWidgets(
    'bitbox wallet + unlocked: Insider Funktionen row present; Wallet-Sicherung stays hidden',
    (tester) async {
      final bitbox = MockBitboxWallet();
      when(() => bitbox.walletType).thenReturn(WalletType.bitbox);
      when(() => homeBloc.state).thenReturn(HomeState(openWallet: bitbox));
      when(() => settingsBloc.state)
          .thenReturn(const SettingsState(insiderFeaturesUnlocked: true));

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(S.current.settingsInsiderFeatures), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text(S.current.pay), findsNothing);
      expect(find.text(S.current.settingsWalletBackup), findsNothing);
      expect(
        firstSectionTitles(tester),
        containsAllInOrder([
          S.current.walletAddress,
          S.current.settingsInsiderFeatures,
        ]),
      );
      expect(
        firstSectionTitles(tester),
        isNot(contains(S.current.settingsWalletBackup)),
      );
    },
  );
}
