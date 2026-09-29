import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_info_page.dart';
import 'package:realunit_wallet/screens/pay/pay_scan_page.dart';

import '../../helper/helper.dart';

class _BitboxWallet extends Fake implements BitboxWallet {
  @override
  WalletType get walletType => WalletType.bitbox;
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
      await tester.pumpApp(hosted(const PayInfoPage()));

      expect(find.text(S.current.payInfoTitle), findsOneWidget);
      expect(find.text(S.current.payInfoBody), findsOneWidget);
      expect(find.text(S.current.next), findsOneWidget);
      expect(
        S.current.payInfoBody,
        anyOf(contains('ganze REALU'), contains('whole REALU shares')),
      );
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
      expect(find.text(S.current.next), findsNothing);
      expect(find.byType(PayScanPage), findsNothing);
    });
  });
}
