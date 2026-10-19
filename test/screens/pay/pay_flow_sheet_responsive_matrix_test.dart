// Responsive matrix for PayFlowSheet.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_sheet.dart';
import 'package:realunit_wallet/styles/themes.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

import '../../helper/helper.dart';

void main() {
  /// Pumps the sheet the way production shows it: [PayFlowSheet.show] with
  /// [isScrollControlled] true.
  Future<void> pumpModalSheet(WidgetTester tester, MatrixCell cell) async {
    await tester.binding.setSurfaceSize(cell.device.size);
    addTearDown(() async => await tester.binding.setSurfaceSize(null));

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
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PayFlowSheet.show(context),
                  child: const Text('open-sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
  }

  group('PayFlowSheet close-only responsive matrix (full device × textScale)', () {
    for (final cell in kFullResponsiveMatrix) {
      testWidgets(cell.id, (tester) async {
        await withTargetPlatform(cell.device.platform, () async {
          await expectNoLayoutOverflow(
            tester,
            () => pumpModalSheet(tester, cell),
            reason: 'overflow on PayFlowSheet / ${cell.label}',
          );

          expect(find.byType(PayFlowSheet), findsOneWidget);
          await expectFullyTappable(
            tester,
            find.widgetWithText(AppFilledButton, S.current.close),
            within: find.byType(PayFlowSheet),
            reason: 'PayFlowSheet / ${cell.label}: Close not tappable',
          );
        });
      });
    }
  });
}
