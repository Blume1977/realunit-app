import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/dfx_transaction.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/transaction_row.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/receipt/transaction_history_receipt_cubit.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_detail_page.dart';
import 'package:realunit_wallet/screens/transaction_history/widgets/transaction_history_row.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';
import 'package:realunit_wallet/styles/themes.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/frozen_chf_label.dart';

class _MockReceiptCubit extends MockCubit<TransactionHistoryReceiptState>
    implements TransactionHistoryReceiptCubit {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

Transaction _tx({
  TransferCategory? category,
  String txId = 'tx-42',
  TransactionTypes type = TransactionTypes.tokenTransfer,
  String note = '',
}) => Transaction(
  height: 0,
  txId: txId,
  chainId: realUnitAsset.chainId,
  senderAddress: '0x1111111111111111111111111111111111111111',
  receiverAddress: '0x2222222222222222222222222222222222222222',
  amount: BigInt.from(20),
  asset: realUnitAsset,
  type: type,
  category: category,
  note: note,
  data: null,
  timestamp: DateTime.utc(2026, 8, 24, 10),
);

DfxTransaction _dfxTx({
  TransferCategory? category,
  String txId = 'tx-42',
  BigInt? amount,
  double? inputAmount,
  String? inputAsset,
  double? outputAmount,
  String? outputAsset,
}) => DfxTransaction(
  dfxId: 1,
  inputAmount: inputAmount,
  inputAsset: inputAsset,
  outputAmount: outputAmount,
  outputAsset: outputAsset,
  height: 0,
  txId: txId,
  chainId: realUnitAsset.chainId,
  senderAddress: '0x1111111111111111111111111111111111111111',
  receiverAddress: '0x2222222222222222222222222222222222222222',
  amount: amount ?? BigInt.from(20),
  asset: realUnitAsset,
  type: TransactionTypes.tokenTransfer,
  category: category,
  note: '',
  data: null,
  timestamp: DateTime.utc(2026, 8, 24, 10),
);

Transaction _referral() => Transaction(
  height: 0,
  txId: 'referral-payout-7',
  chainId: realUnitAsset.chainId,
  senderAddress: kReferralPayoutSenderAddress,
  receiverAddress: '0xabc',
  amount: BigInt.from(20),
  asset: realUnitAsset,
  type: TransactionTypes.referralPayout,
  note: '',
  data: '246.5',
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
    when(
      () => receiptCubit.generatePaymentReceipt(any(), language: any(named: 'language')),
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

  Future<void> pumpDetail(
    WidgetTester tester,
    Transaction tx, {
    String walletAddress = '0x1111111111111111111111111111111111111111',
    bool returnToDashboard = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: realUnitTheme,
        locale: const Locale('de'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
            BlocProvider<SettingsBloc>.value(value: settings),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: tx,
              walletAddress: walletAddress,
              returnToDashboard: returnToDashboard,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpRowRoute(WidgetTester tester, Widget row) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<SettingsBloc>.value(
            value: settings,
            child: Scaffold(body: row),
          ),
          routes: [
            GoRoute(
              name: AppRoutes.transactionDetail,
              path: 'transactionDetail',
              builder: (_, state) {
                final args = state.extra! as TransactionDetailArgs;
                return Scaffold(body: Text(args.transaction.txId));
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
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
    );
  }

  testWidgets(
    'sale shows two receipt buttons and each starts its own receipt',
    (tester) async {
      await pumpDetail(tester, _tx(category: TransferCategory.sale));

      expect(find.text('RealUnit-Verkauf'), findsOneWidget);
      expect(find.text('Auszahlung (DFX AG)'), findsOneWidget);
      expect(find.text('Beleg'), findsNothing);
      expect(find.text('Betrag in CHF'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
      expect(find.text('tx-42'), findsNothing);

      await tester.tap(find.text('RealUnit-Verkauf'));
      await tester.pump();

      verify(
        () => receiptCubit.generateReceipt(
          'tx-42',
          currency: Currency.chf,
          language: Language.de,
        ),
      ).called(1);
      verifyNever(() => receiptCubit.generateExchangeReceipt(any()));

      await tester.tap(find.text('Auszahlung (DFX AG)'));
      await tester.pump();

      verify(() => receiptCubit.generateExchangeReceipt('tx-42')).called(1);
      expect(find.text('RealUnit-Verkauf'), findsOneWidget);
      expect(find.text('Auszahlung (DFX AG)'), findsOneWidget);
    },
  );

  testWidgets(
    'payment shows the sale receipt and the payment receipt, and no DFX payout',
    (tester) async {
      await pumpDetail(tester, _tx(category: TransferCategory.payment));

      expect(find.text('Verkauf und Zahlung'), findsOneWidget);
      expect(find.text('Verkaufsbeleg'), findsOneWidget);
      expect(find.text('Zahlungsbeleg'), findsOneWidget);
      // No DFX payout statement: the proceeds paid the bill, nothing was paid out
      expect(find.text('Auszahlung (DFX AG)'), findsNothing);
      expect(find.text('Beleg'), findsNothing);

      await tester.tap(find.text('Verkaufsbeleg'));
      await tester.pump();
      verify(
        () => receiptCubit.generateReceipt(
          'tx-42',
          currency: Currency.chf,
          language: Language.de,
        ),
      ).called(1);

      await tester.tap(find.text('Zahlungsbeleg'));
      await tester.pump();
      verify(() => receiptCubit.generatePaymentReceipt('tx-42', language: Language.de)).called(1);
      verifyNever(() => receiptCubit.generateExchangeReceipt(any()));
    },
  );

  testWidgets(
    'sale DfxTransaction names the sale proceeds and the payout, without sender or tx id',
    (tester) async {
      await pumpDetail(
        tester,
        _dfxTx(
          category: TransferCategory.sale,
          inputAmount: 2000,
          inputAsset: 'ZCHF',
          outputAmount: 1980.2,
          outputAsset: 'CHF',
        ),
      );

      expect(find.text('Verkaufserlös in ZCHF'), findsOneWidget);
      expect(find.text('2000.00'), findsOneWidget);
      expect(find.text('Auszahlung in CHF'), findsOneWidget);
      expect(find.text('1980.20'), findsOneWidget);
      expect(find.textContaining('Betrag in'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
      expect(find.text('tx-42'), findsNothing);
      expect(find.text('RealUnit-Verkauf'), findsOneWidget);
      expect(find.text('Auszahlung (DFX AG)'), findsOneWidget);
    },
  );

  testWidgets(
    'sale DfxTransaction does not repeat the REALU amount of the title as a field',
    (tester) async {
      await pumpDetail(
        tester,
        _dfxTx(
          category: TransferCategory.sale,
          inputAmount: 20,
          inputAsset: 'REALU',
          outputAmount: 1980,
          outputAsset: 'EUR',
        ),
      );

      expect(find.textContaining('Verkaufserlös in'), findsNothing);
      expect(find.text('Auszahlung in EUR'), findsOneWidget);
      expect(find.text('1980.00'), findsOneWidget);
    },
  );

  testWidgets(
    'purchase shows a single Beleg button that generates the RealUnit receipt',
    (tester) async {
      await pumpDetail(tester, _tx(category: TransferCategory.purchase));

      expect(find.text('Beleg'), findsOneWidget);
      expect(find.text('RealUnit-Verkauf'), findsNothing);
      expect(find.text('Auszahlung (DFX AG)'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
      expect(find.text('tx-42'), findsNothing);

      await tester.tap(find.text('Beleg'));
      await tester.pump();

      verify(
        () => receiptCubit.generateReceipt(
          'tx-42',
          currency: Currency.chf,
          language: Language.de,
        ),
      ).called(1);
      verifyNever(() => receiptCubit.generateExchangeReceipt(any()));
    },
  );

  testWidgets(
    'purchase DfxTransaction shows the bank amount in CHF and one Beleg button',
    (tester) async {
      await pumpDetail(
        tester,
        _dfxTx(
          category: TransferCategory.purchase,
          amount: BigInt.from(50),
          inputAmount: 5000,
          inputAsset: 'CHF',
          outputAmount: 50,
          outputAsset: 'REALU',
        ),
      );

      expect(find.text('Betrag in CHF'), findsOneWidget);
      expect(find.text('5000.00'), findsOneWidget);
      expect(find.textContaining('Auszahlung in'), findsNothing);
      expect(find.textContaining('Verkaufserlös in'), findsNothing);
      expect(find.text('Beleg'), findsOneWidget);
      expect(find.text('RealUnit-Verkauf'), findsNothing);
      expect(find.text('Auszahlung (DFX AG)'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'token transfer that is not a DfxTransaction does not show Betrag in',
    (tester) async {
      await pumpDetail(tester, _tx());

      expect(find.textContaining('Betrag in'), findsNothing);
    },
  );

  testWidgets(
    'shows the date in the Swiss notation with the local time',
    (tester) async {
      final transaction = _tx();

      await pumpDetail(tester, transaction);

      expect(
        find.text(
          DateFormat('dd.MM.yyyy | H:mm').format(transaction.timestamp.toLocal()),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Aug'), findsNothing);
    },
  );

  testWidgets('referral payout shows FrozenChfLabel and no receipt buttons', (
    tester,
  ) async {
    await pumpDetail(tester, _referral(), walletAddress: '0xabc');

    expect(find.text('referral-payout-7'), findsNothing);
    expect(find.byType(FrozenChfLabel), findsOneWidget);
    expect(find.text('Beleg'), findsNothing);
    expect(find.text('RealUnit-Verkauf'), findsNothing);
    expect(find.text('Auszahlung (DFX AG)'), findsNothing);
    expect(find.byType(AppFilledButton), findsNothing);
  });

  testWidgets(
    'transaction with a note shows Notiz and Dividende without sender or tx id',
    (tester) async {
      await pumpDetail(
        tester,
        _tx(category: TransferCategory.purchase, note: 'Dividende'),
      );

      expect(find.text('Notiz'), findsOneWidget);
      expect(find.text('Dividende'), findsOneWidget);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
      expect(find.text('tx-42'), findsNothing);
    },
  );

  testWidgets(
    'purchase receipt button is loading when cubit is already loading',
    (tester) async {
      when(
        () => receiptCubit.state,
      ).thenReturn(const TransactionHistoryReceiptLoading());
      whenListen(
        receiptCubit,
        const Stream<TransactionHistoryReceiptState>.empty(),
        initialState: const TransactionHistoryReceiptLoading(),
      );

      await pumpDetail(tester, _tx(category: TransferCategory.purchase));

      final button = tester.widget<AppFilledButton>(
        find.byType(AppFilledButton),
      );
      expect(button.state, FilledButtonState.loading);
    },
  );

  testWidgets(
    'sale receipt buttons stay idle when cubit is loading and nothing was tapped',
    (tester) async {
      when(
        () => receiptCubit.state,
      ).thenReturn(const TransactionHistoryReceiptLoading());
      whenListen(
        receiptCubit,
        const Stream<TransactionHistoryReceiptState>.empty(),
        initialState: const TransactionHistoryReceiptLoading(),
      );

      await pumpDetail(tester, _tx(category: TransferCategory.sale));

      expect(find.byType(AppFilledButton), findsNWidgets(2));
      for (final button in tester.widgetList<AppFilledButton>(
        find.byType(AppFilledButton),
      )) {
        expect(button.state, FilledButtonState.idle);
        expect(button.onPressed, isNull);
      }
    },
  );

  testWidgets(
    'tapping the payment receipt loads only that button and keeps the sale receipt idle',
    (tester) async {
      final states = StreamController<TransactionHistoryReceiptState>();
      addTearDown(states.close);
      whenListen(
        receiptCubit,
        states.stream,
        initialState: const TransactionHistoryReceiptInitial(),
      );

      await pumpDetail(tester, _tx(category: TransferCategory.payment));
      await tester.tap(find.text('Zahlungsbeleg'));
      when(
        () => receiptCubit.state,
      ).thenReturn(const TransactionHistoryReceiptLoading());
      states.add(const TransactionHistoryReceiptLoading());
      await tester.pump();

      final buttons = tester.widgetList<AppFilledButton>(find.byType(AppFilledButton)).toList();
      expect(buttons, hasLength(2));
      expect(buttons[0].state, FilledButtonState.idle);
      expect(buttons[1].state, FilledButtonState.loading);
      for (final button in buttons) {
        expect(button.onPressed, isNull);
      }
    },
  );

  testWidgets('failure shows a SnackBar with the cubit message', (
    tester,
  ) async {
    whenListen(
      receiptCubit,
      Stream<TransactionHistoryReceiptState>.value(
        const TransactionHistoryReceiptFailure(
          'Beleg konnte nicht erstellt werden.',
        ),
      ),
      initialState: const TransactionHistoryReceiptInitial(),
    );

    await pumpDetail(tester, _tx(category: TransferCategory.purchase));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Beleg konnte nicht erstellt werden.'), findsOneWidget);
  });

  testWidgets('tapping a history row opens the detail route', (tester) async {
    await pumpRowRoute(
      tester,
      TransactionHistoryRowView(
        transaction: _tx(
          category: TransferCategory.sale,
          txId: 'tx-history-sale',
        ),
        walletAddress: '0x1111111111111111111111111111111111111111',
        isOutbound: true,
      ),
    );

    expect(find.byIcon(Icons.file_download_outlined), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('tx-history-sale'), findsOneWidget);
  });

  testWidgets('tapping a dashboard transfer row opens the detail route', (
    tester,
  ) async {
    await pumpRowRoute(
      tester,
      TransactionRow(
        transaction: _tx(
          category: TransferCategory.purchase,
          txId: 'tx-dash-transfer',
        ),
        walletAddress: '0x1111111111111111111111111111111111111111',
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('tx-dash-transfer'), findsOneWidget);
  });

  testWidgets(
    'hides the back-to-main button when returnToDashboard is false',
    (tester) async {
      await pumpDetail(tester, _tx());

      expect(find.text(S.current.transactionDetailBackToMain), findsNothing);
    },
  );

  testWidgets('shows the back-to-main button when returnToDashboard is true', (
    tester,
  ) async {
    await pumpDetail(tester, _tx(), returnToDashboard: true);

    expect(find.text(S.current.transactionDetailBackToMain), findsOneWidget);
  });

  testWidgets('back-to-main button lands on the dashboard route', (
    tester,
  ) async {
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
      MaterialApp.router(
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

    expect(find.text(S.current.transactionDetailBackToMain), findsOneWidget);

    await tester.tap(find.text(S.current.transactionDetailBackToMain));
    await tester.pumpAndSettle();

    expect(find.text('dashboard-home'), findsOneWidget);
  });

  testWidgets(
    'token transfer with an empty txId does not show a receipt',
    (tester) async {
      await pumpDetail(tester, _tx(txId: ''));

      expect(find.text(S.current.transactionReceipt), findsNothing);
    },
  );

  testWidgets(
    'token transfer with a confirmed sentinel txId does not show a receipt',
    (tester) async {
      await pumpDetail(tester, _tx(txId: 'confirmed'));

      expect(find.text(S.current.transactionReceipt), findsNothing);
    },
  );

  testWidgets('token transfer with a normal txId still shows a receipt', (
    tester,
  ) async {
    await pumpDetail(tester, _tx());

    expect(find.text(S.current.transactionReceipt), findsOneWidget);
  });

  testWidgets('tapping a referral payout row opens the detail route', (
    tester,
  ) async {
    await pumpRowRoute(
      tester,
      ReferralPayoutTransactionRow(
        transaction: _referral(),
        walletAddress: '0x1111111111111111111111111111111111111111',
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('referral-payout-7'), findsOneWidget);
  });
}
