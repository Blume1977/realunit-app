import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/settings_insider/settings_insider_page.dart';

import '../../../helper/helper.dart';

void main() {
  late MockSettingsBloc settingsBloc;

  setUp(() {
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(
      const SettingsState(insiderFeaturesUnlocked: true),
    );
  });

  setUpAll(() {
    GetIt.instance.registerSingleton<SettingsBloc>(MockSettingsBloc());
  });

  tearDownAll(() async {
    await GetIt.instance.reset();
  });

  Widget buildSubject() {
    if (GetIt.instance.isRegistered<SettingsBloc>()) {
      GetIt.instance.unregister<SettingsBloc>();
    }
    GetIt.instance.registerSingleton<SettingsBloc>(settingsBloc);

    return wrapForGolden(const SettingsInsiderPage());
  }

  group('$SettingsInsiderPage', () {
    goldenTest(
      'pay toggle off',
      fileName: 'settings_insider_page_default',
      constraints: phoneConstraints,
      builder: buildSubject,
    );

    goldenTest(
      'all five switches on',
      fileName: 'settings_insider_page_enabled',
      constraints: phoneConstraints,
      builder: () {
        when(() => settingsBloc.state).thenReturn(
          const SettingsState(
            insiderFeaturesUnlocked: true,
            networkOptionsEnabled: true,
            insiderPayEnabled: true,
            insiderSendEnabled: true,
            insiderReferralEnabled: true,
            insiderBonusEnabled: true,
          ),
        );
        return buildSubject();
      },
    );
  });
}
