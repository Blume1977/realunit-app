import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_page.dart';
import 'package:realunit_wallet/styles/themes.dart';

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.error,
    required this.restart,
    required this.resetWallet,
    required this.languageCode,
  });

  final Object error;
  final Future<void> Function() restart;
  final Future<void> Function() resetWallet;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: realUnitTheme,
      locale: Locale(languageCode),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlocProvider<StartupFailureCubit>(
        create: (_) => StartupFailureCubit(
          error: error,
          restart: restart,
          resetWallet: resetWallet,
        ),
        child: const StartupFailurePage(),
      ),
    );
  }
}
