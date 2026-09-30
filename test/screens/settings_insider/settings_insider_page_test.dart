import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/settings_insider/settings_insider_page.dart';

import '../../helper/helper.dart';

void main() {
  late MockSettingsBloc settingsBloc;

  setUp(() async {
    await GetIt.instance.reset();
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(const SettingsState());
    GetIt.instance.registerSingleton<SettingsBloc>(settingsBloc);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pumpPage(WidgetTester tester) {
    return tester.pumpWidget(wrapForGolden(const SettingsInsiderPage()));
  }

  testWidgets('AppBar title is settingsInsiderFeatures', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(S.current.settingsInsiderFeatures),
      ),
      findsOneWidget,
    );
  });

  testWidgets('four feature rows and Switches are present and default off', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(S.current.pay), findsOneWidget);
    expect(find.text(S.current.send), findsOneWidget);
    expect(find.text(S.current.settingsInsiderReferral), findsOneWidget);
    expect(find.text(S.current.settingsInsiderBonus), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(4));
    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isFalse);
  });

  testWidgets(
    'tapping Pay text dispatches SetInsiderFeatureEnabledEvent(pay, true) once',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.pay));
      await tester.pump();

      verify(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, true),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'tapping Send text dispatches SetInsiderFeatureEnabledEvent(send, true) once',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.send));
      await tester.pump();

      verify(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.send, true),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'tapping Referral text dispatches SetInsiderFeatureEnabledEvent(referral, true) once',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.settingsInsiderReferral));
      await tester.pump();

      verify(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.referral, true),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'tapping Bonus text dispatches SetInsiderFeatureEnabledEvent(bonus, true) once',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.settingsInsiderBonus));
      await tester.pump();

      verify(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.bonus, true),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'tapping the Pay Switch dispatches SetInsiderFeatureEnabledEvent(pay, true) once',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(0), warnIfMissed: false);
      await tester.pump();

      verify(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, true),
        ),
      ).called(1);
    },
  );

  testWidgets('when insiderPayEnabled is true, Switch.value is true', (
    tester,
  ) async {
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(insiderPayEnabled: true),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isFalse);
  });

  testWidgets('when insiderSendEnabled is true, Switch.value is true', (
    tester,
  ) async {
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(insiderSendEnabled: true),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isFalse);
  });

  testWidgets('when insiderReferralEnabled is true, Switch.value is true', (
    tester,
  ) async {
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(insiderReferralEnabled: true),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isFalse);
  });

  testWidgets('when insiderBonusEnabled is true, Switch.value is true', (
    tester,
  ) async {
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(insiderBonusEnabled: true),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isTrue);
  });

  testWidgets(
    'when all four are centrally enabled, switches stay on and Pay tap does not dispatch',
    (tester) async {
      when(() => settingsBloc.state).thenReturn(
        const SettingsState(
          walletFeaturePay: true,
          walletFeatureSend: true,
          walletFeaturePromoCode: true,
          walletFeatureReferral: true,
          walletFeaturePayCentral: true,
          walletFeatureSendCentral: true,
          walletFeaturePromoCodeCentral: true,
          walletFeatureReferralCentral: true,
        ),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isTrue);
      expect(find.text(S.current.settingsInsiderCentrallyEnabled), findsNWidgets(4));

      await tester.tap(find.text(S.current.pay));
      await tester.pump();

      verifyNever(
        () => settingsBloc.add(
          const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, false),
        ),
      );
    },
  );
}
