import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/legal/steps/legal_disclaimer_step.dart';

import '../../../helper/helper.dart';

void main() {
  group('$LegalDisclaimerStep', () {
    testWidgets('step 0: renders title, body and the advertising disclaimer',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpApp(const LegalDisclaimerStep(step: 0));

      // title + body + the advertising/prospectus disclaimer. The i18n
      // strings change with locale, so we only pin the structure (three
      // Text widgets).
      expect(find.byType(Text), findsNWidgets(3));
    });

    testWidgets('step 1: renders the *Title2 / *Text2 pair', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpApp(const LegalDisclaimerStep(step: 1));

      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('step 0 vs step 1 produce different titles', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpApp(const LegalDisclaimerStep(step: 0));
      final firstTitle = tester.widgetList<Text>(find.byType(Text)).first.data;

      await tester.pumpApp(const LegalDisclaimerStep(step: 1));
      final secondTitle = tester.widgetList<Text>(find.byType(Text)).first.data;

      expect(firstTitle, isNotNull);
      expect(secondTitle, isNotNull);
      expect(firstTitle, isNot(secondTitle));
    });

    testWidgets('advertising disclaimer renders on step 0 but not on step 1',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pin the actual disclaimer, not just a Text count: it carries the
      // realunit.ch prospectus link, which both locales share (the path after
      // the host differs per locale). It must appear on step 0 and be absent
      // on step 1.
      await tester.pumpApp(const LegalDisclaimerStep(step: 0));
      expect(
        find.textContaining('https://realunit.ch/'),
        findsOneWidget,
      );

      await tester.pumpApp(const LegalDisclaimerStep(step: 1));
      expect(
        find.textContaining('https://realunit.ch/'),
        findsNothing,
      );
    });
  });
}
