// Responsive matrix gate for TransactionDetailView back-to-dashboard CTA.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/receipt/transaction_history_receipt_cubit.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_detail_page.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';
import 'package:realunit_wallet/styles/themes.dart';

import '../../helper/helper.dart';

class _MockReceiptCubit extends MockCubit<TransactionHistoryReceiptState>
    implements TransactionHistoryReceiptCubit {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

Transaction _tx() => Transaction(
  height: 0,
  txId: 'tx-42',
  chainId: realUnitAsset.chainId,
  senderAddress: '0x1111111111111111111111111111111111111111',
  receiverAddress: '0x2222222222222222222222222222222222222222',
  amount: BigInt.from(20),
  asset: realUnitAsset,
  type: TransactionTypes.tokenTransfer,
  note: '',
  data: null,
  timestamp: DateTime.utc(2026, 8, 24, 10),
);

void main() {
  late _MockReceiptCubit receiptCubit;
  late _MockSettingsBloc settings;

  setUpAll(() {
    registerFallbackValue(Currency.chf);
    registerFallbackValue(Language.en);
  });

  setUp(() {
    receiptCubit = _MockReceiptCubit();
    when(
      () => receiptCubit.state,
    ).thenReturn(const TransactionHistoryReceiptInitial());
    whenListen(
      receiptCubit,
      const Stream<TransactionHistoryReceiptState>.empty(),
      initialState: const TransactionHistoryReceiptInitial(),
    );
    when(
      () => receiptCubit.generateReceipt(
        any(),
        currency: any(named: 'currency'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => receiptCubit.generateExchangeReceipt(any()),
    ).thenAnswer((_) async {});

    settings = _MockSettingsBloc();
    const settingsState = SettingsState(language: Language.de);
    when(() => settings.state).thenReturn(settingsState);
    whenListen(
      settings,
      const Stream<SettingsState>.empty(),
      initialState: settingsState,
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    MediaQueryData mediaQuery,
  ) async {
    await tester.binding.setSurfaceSize(mediaQuery.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          name: AppRoutes.dashboard,
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('dashboard-home')),
          routes: [
            GoRoute(
              name: AppRoutes.transactionDetail,
              path: 'transactionDetail',
              builder: (_, state) {
                final args = state.extra! as TransactionDetailArgs;
                return MultiBlocProvider(
                  providers: [
                    BlocProvider<TransactionHistoryReceiptCubit>.value(
                      value: receiptCubit,
                    ),
                    BlocProvider<SettingsBloc>.value(value: settings),
                  ],
                  child: TransactionDetailView(args: args),
                );
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: mediaQuery,
        child: MaterialApp.router(
          theme: realUnitTheme,
          locale: const Locale('de'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    router.goNamed(
      AppRoutes.transactionDetail,
      extra: TransactionDetailArgs(
        transaction: _tx(),
        walletAddress: '0x1111111111111111111111111111111111111111',
        returnToDashboard: true,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TransactionDetailView responsive matrix (full device × textScale)', () {
    for (final cell in kFullResponsiveMatrix) {
      testWidgets(cell.id, (tester) async {
        await withTargetPlatform(cell.device.platform, () async {
          await expectNoLayoutOverflow(
            tester,
            () async {
              await pumpScreen(tester, cell.mediaQuery);
            },
            reason: 'overflow on ${cell.label}',
          );

          await expectFullyTappable(
            tester,
            find.text('Zurück zum Hauptscreen'),
            within: find.byType(TransactionDetailView),
            reason: '${cell.label}: CTA not tappable',
          );
        });
      });
    }
  });
}
