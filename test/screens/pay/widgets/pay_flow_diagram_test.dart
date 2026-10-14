import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_diagram.dart';

import '../../../helper/helper.dart';

// The page hosts the diagram in a scroll view; the stacked layout at large
// text scales is taller than a test window.
void main() {
  group('$PayFlowDiagram', () {
    testWidgets('names the three stations and explains both steps', (tester) async {
      await tester.pumpApp(const Scaffold(body: SingleChildScrollView(child: PayFlowDiagram())));

      expect(find.text(S.current.payFlowShareholder), findsOneWidget);
      expect(find.text(S.current.payFlowZchf), findsOneWidget);
      expect(find.text(S.current.payFlowMerchant), findsOneWidget);
      expect(find.text(S.current.payFlowStep1), findsOneWidget);
      expect(find.text(S.current.payFlowStep2), findsOneWidget);
      // The step numbers appear on the arrows and in the legend.
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('2'), findsNWidgets(2));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });

    testWidgets('lays the stations out in a row at the default text scale', (tester) async {
      await tester.pumpApp(const Scaffold(body: SingleChildScrollView(child: PayFlowDiagram())));

      expect(find.byKey(PayFlowDiagram.horizontalKey), findsOneWidget);
      expect(find.byKey(PayFlowDiagram.verticalKey), findsNothing);
    });

    testWidgets('stacks the stations at a large text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpApp(const Scaffold(body: SingleChildScrollView(child: PayFlowDiagram())));

      expect(find.byKey(PayFlowDiagram.verticalKey), findsOneWidget);
      expect(find.byKey(PayFlowDiagram.horizontalKey), findsNothing);
      expect(find.text(S.current.payFlowStep2), findsOneWidget);
    });
  });
}
