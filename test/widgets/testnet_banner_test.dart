import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/widgets/testnet_banner.dart';

import '../helper/helper.dart';

void main() {
  late MockSettingsBloc settingsBloc;

  setUp(() {
    settingsBloc = MockSettingsBloc();
  });

  Future<void> pumpBanner(WidgetTester tester, SettingsState state) {
    when(() => settingsBloc.state).thenReturn(state);
    return tester.pumpWidget(
      BlocProvider<SettingsBloc>.value(
        value: settingsBloc,
        child: wrapForGolden(
          const TestnetBanner(child: Text('wallet-body')),
          locale: const Locale('en'),
        ),
      ),
    );
  }

  testWidgets('mainnet shows the child without a banner', (tester) async {
    await pumpBanner(tester, const SettingsState());
    await tester.pumpAndSettle();

    expect(find.text(S.current.testnetBanner), findsNothing);
    expect(find.text('wallet-body'), findsOneWidget);
  });

  testWidgets('testnet shows the banner and the child', (tester) async {
    await pumpBanner(
      tester,
      const SettingsState(networkMode: NetworkMode.testnet),
    );
    await tester.pumpAndSettle();

    expect(find.text(S.current.testnetBanner), findsOneWidget);
    expect(find.text('Testnet — not real funds'), findsOneWidget);
    expect(find.text('wallet-body'), findsOneWidget);
  });
}
