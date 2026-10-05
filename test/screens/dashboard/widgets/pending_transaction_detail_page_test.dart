import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/pending_transaction_detail_page.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/pending_transaction_row.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/themes.dart';

import '../../../helper/helper.dart';

TransactionDto _buy() => TransactionDto(
  type: TransactionType.buy,
  inputAmount: 5000,
  inputAsset: 'CHF',
  outputAmount: 50,
  outputAsset: 'REALU',
  state: TransactionState.processing,
  date: DateTime.utc(2026, 5, 15, 10),
  sourceAccount: 'CH9300762011623852957',
  targetAccount: '0x1111111111111111111111111111111111111111',
);

void main() {
  group('$PendingTransactionDetailPage', () {
    testWidgets(
      'buy shows amount, status and IBAN and hides wallet and receipt',
      (tester) async {
        await tester.pumpApp(
          PendingTransactionDetailPage(
            args: PendingTransactionDetailArgs(transaction: _buy()),
          ),
          locale: const Locale('de'),
        );

        expect(find.text('Kauf'), findsOneWidget);
        expect(find.text('5000.00 CHF'), findsOneWidget);
        expect(find.text('Betrag in REALU'), findsOneWidget);
        expect(find.text('ca. 50.00'), findsOneWidget);
        expect(find.text('In Bearbeitung'), findsOneWidget);
        expect(
          find.text(
            '15.05.2026 | ${DateTime.utc(2026, 5, 15, 10).toLocal().hour}:00',
          ),
          findsOneWidget,
        );
        expect(find.text('CH9300762011623852957'), findsNothing);
        expect(find.text('IBAN'), findsNothing);
        expect(
          find.text('0x1111111111111111111111111111111111111111'),
          findsNothing,
        );
        expect(find.text('Beleg'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
      },
    );

    testWidgets('buy waiting for the bank payment says so', (tester) async {
      await tester.pumpApp(
        const PendingTransactionDetailPage(
          args: PendingTransactionDetailArgs(
            transaction: TransactionDto(
              type: TransactionType.buy,
              inputAmount: 5000,
              inputAsset: 'CHF',
              state: TransactionState.waitingForPayment,
            ),
          ),
        ),
        locale: const Locale('de'),
      );

      expect(find.text('Warte auf Zahlung'), findsOneWidget);
      expect(find.text('Warte auf Eingang der REALU'), findsNothing);
    });

    testWidgets(
      'sell waiting for the tokens names the tokens and marks the payout as approximate',
      (tester) async {
        await tester.pumpApp(
          const PendingTransactionDetailPage(
            args: PendingTransactionDetailArgs(
              transaction: TransactionDto(
                type: TransactionType.sell,
                inputAmount: 30,
                inputAsset: 'REALU',
                outputAmount: 2970,
                outputAsset: 'CHF',
                state: TransactionState.waitingForPayment,
              ),
            ),
          ),
          locale: const Locale('de'),
        );

        expect(find.text('Warte auf Eingang der REALU'), findsOneWidget);
        expect(find.text('Warte auf Zahlung'), findsNothing);
        expect(find.text('Betrag in CHF'), findsOneWidget);
        expect(find.text('ca. 2970.00'), findsOneWidget);
      },
    );

    testWidgets('sell with wallet target shows no IBAN', (tester) async {
      await tester.pumpApp(
        const PendingTransactionDetailPage(
          args: PendingTransactionDetailArgs(
            transaction: TransactionDto(
              type: TransactionType.sell,
              targetAccount: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
        locale: const Locale('de'),
      );

      expect(find.text('IBAN'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
    });

    testWidgets('tapping PendingTransactionRow opens the detail page', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: PendingTransactionRow(transaction: _buy()),
            ),
            routes: [
              GoRoute(
                name: AppRoutes.transactionDetail,
                path: 'transactionDetail',
                builder: (_, state) {
                  final extra = state.extra as PendingTransactionDetailArgs;
                  return PendingTransactionDetailPage(args: extra);
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

      await tester.tap(find.byType(PendingTransactionRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PendingTransactionDetailPage), findsOneWidget);
      expect(find.text('5000.00 CHF'), findsOneWidget);
    });
  });
}
