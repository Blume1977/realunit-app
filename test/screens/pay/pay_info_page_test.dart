import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_info_page.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_page.dart';
import 'package:realunit_wallet/screens/pay/pay_scan_page.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_diagram.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';

import '../../helper/helper.dart';

class _BitboxWallet extends Fake implements BitboxWallet {
  @override
  WalletType get walletType => WalletType.bitbox;
}

class _FakeLocationsClient implements http.Client {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response('no', 500);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(stubMobileScannerChannel);

  Widget hosted(Widget child, {AWallet? wallet}) {
    final home = MockHomeBloc();
    when(() => home.state).thenReturn(
      HomeState(
        hasWallet: true,
        openWallet:
            wallet ??
            SoftwareViewWallet(1, 'Software', '0x0000000000000000000000000000000000000001'),
      ),
    );
    return BlocProvider<HomeBloc>.value(value: home, child: child);
  }

  group('$PayInfoPage', () {
    testWidgets('shows the OpenCryptoPay exchange disclosure', (tester) async {
      final client = _FakeLocationsClient();
      final router = GoRouter(
        initialLocation: '/pay',
        routes: [
          GoRoute(
            path: '/pay',
            name: AppRoutes.pay,
            builder: (_, _) => hosted(const PayInfoPage()),
          ),
          GoRoute(
            path: '/payLocations',
            name: AppRoutes.payLocations,
            builder: (_, _) => PayLocationsPage(httpClient: client),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
        ),
      );

      expect(find.text(S.current.payInfoTitle), findsOneWidget);
      expect(find.byType(PayFlowDiagram), findsOneWidget);
      expect(find.text(S.current.payInfoBody), findsOneWidget);
      expect(find.text(S.current.payInfoLocationsLink), findsOneWidget);
      await tester.tap(find.text(S.current.payInfoLocationsLink));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PayLocationsPage), findsOneWidget);
      expect(find.text(S.current.next), findsOneWidget);
      // Payment is not made with the shares. The proceeds, minus the fee, are
      // received as ZCHF, and only whole shares are sold. The round-up is not
      // credited to the wallet.
      expect(
        S.current.payInfoBody,
        anyOf(
          contains('nicht mit Ihren Aktien'),
          contains('do not pay with your shares'),
        ),
      );
      expect(S.current.payInfoBody, contains('ZCHF'));
      expect(
        S.current.payInfoBody,
        anyOf(contains('verkaufen Sie REALU'), contains('you sell REALU')),
      );
      expect(
        S.current.payInfoBody,
        anyOf(contains('ganze Aktien'), contains('whole shares')),
      );
      expect(
        S.current.payInfoBody,
        anyOf(contains('nicht gutgeschrieben'), contains('not credited to you')),
      );
      expect(S.current.payInfoBody, isNot(contains('bleibt als ZCHF')));
      expect(S.current.payInfoBody, isNot(contains('stays as ZCHF')));
    });

    testWidgets('continues to the scanner with the initial payload', (tester) async {
      const initialPayload = 'payload-from-deeplink';
      await tester.pumpApp(hosted(const PayInfoPage(initialPayload: initialPayload)));

      await tester.tap(find.text(S.current.next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final page = tester.widget<PayScanPage>(find.byType(PayScanPage));
      expect(page.initialPayload, initialPayload);
    });

    testWidgets('BitBox has no pay option and no scanner', (tester) async {
      await tester.pumpApp(hosted(const PayInfoPage(), wallet: _BitboxWallet()));

      expect(find.text(S.current.payFailurePayUnavailable), findsOneWidget);
      expect(find.byType(PayFlowDiagram), findsNothing);
      expect(find.text(S.current.payInfoLocationsLink), findsNothing);
      expect(find.text(S.current.next), findsNothing);
      expect(find.byType(PayScanPage), findsNothing);
    });
  });
}
