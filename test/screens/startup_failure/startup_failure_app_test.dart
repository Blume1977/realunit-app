import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_app.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_page.dart';
import 'package:realunit_wallet/setup/startup/startup_exceptions.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

void main() {
  Future<void> pumpSubject(
    WidgetTester tester, {
    required Object error,
    required String languageCode,
  }) async {
    await tester.pumpWidget(
      StartupFailureApp(
        error: error,
        restart: () async {},
        resetWallet: () async {},
        languageCode: languageCode,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders StartupFailurePage', (tester) async {
    await pumpSubject(
      tester,
      error: Exception('boom'),
      languageCode: 'en',
    );

    expect(find.byType(StartupFailurePage), findsOneWidget);
  });

  testWidgets('languageCode de shows German title', (tester) async {
    await pumpSubject(
      tester,
      error: Exception('boom'),
      languageCode: 'de',
    );

    expect(find.text(S.current.startupFailureTitle), findsOneWidget);
    expect(find.text('Die App konnte nicht gestartet werden'), findsOneWidget);
  });

  testWidgets('languageCode en shows English title', (tester) async {
    await pumpSubject(
      tester,
      error: Exception('boom'),
      languageCode: 'en',
    );

    expect(find.text(S.current.startupFailureTitle), findsOneWidget);
    expect(find.text('The app could not be started'), findsOneWidget);
  });

  testWidgets('DatabaseKeyMissingException shows reset button', (tester) async {
    await pumpSubject(
      tester,
      error: const DatabaseKeyMissingException(walletConfigured: true),
      languageCode: 'en',
    );

    expect(
      find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
      findsOneWidget,
    );
  });

  testWidgets('generic error does not show reset button', (tester) async {
    await pumpSubject(
      tester,
      error: Exception('boom'),
      languageCode: 'en',
    );

    expect(
      find.widgetWithText(AppFilledButton, S.current.settingsDeleteWallet),
      findsNothing,
    );
  });
}
