import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_info_page.dart';
import 'package:realunit_wallet/styles/themes.dart';

import '../../helper/helper.dart';

Future<void> _pumpScreen(
  WidgetTester tester,
  MatrixCell cell,
  Widget child,
) async {
  await tester.binding.setSurfaceSize(cell.mediaQuery.size);
  addTearDown(() async => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: cell.mediaQuery,
      child: MaterialApp(
        theme: realUnitTheme,
        locale: const Locale('de'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late MockHomeBloc homeBloc;

  setUpAll(stubMobileScannerChannel);

  setUp(() {
    homeBloc = MockHomeBloc();
    when(() => homeBloc.state).thenReturn(
      HomeState(
        hasWallet: true,
        openWallet: SoftwareViewWallet(
          1,
          'Software',
          '0x0000000000000000000000000000000000000001',
        ),
      ),
    );
  });

  group('PayInfoPage responsive matrix (full device × textScale)', () {
    for (final cell in kFullResponsiveMatrix) {
      testWidgets(cell.id, (tester) async {
        await withTargetPlatform(cell.device.platform, () async {
          await expectNoLayoutOverflow(
            tester,
            () => _pumpScreen(
              tester,
              cell,
              BlocProvider<HomeBloc>.value(value: homeBloc, child: const PayInfoPage()),
            ),
            reason: 'PayInfoPage overflow / ${cell.label}',
          );

          await expectFullyTappable(
            tester,
            find.widgetWithText(FilledButton, S.current.next),
            within: find.byType(PayInfoPage),
            reason: 'PayInfoPage / ${cell.label}: Continue CTA not tappable',
          );
        });
      });
    }
  });
}
