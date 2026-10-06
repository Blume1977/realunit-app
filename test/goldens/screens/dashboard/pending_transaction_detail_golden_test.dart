import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/pending_transaction_detail_page.dart';

import '../../../helper/helper.dart';

void main() {
  // This test does not commit a PNG; the regenerate workflow writes it.

  final buy = TransactionDto(
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

  final sell = TransactionDto(
    type: TransactionType.sell,
    inputAmount: 30,
    inputAsset: 'REALU',
    outputAmount: 2970,
    outputAsset: 'CHF',
    state: TransactionState.waitingForPayment,
    date: DateTime.utc(2026, 5, 20, 12),
    sourceAccount: 'CH9300762011623852957',
    targetAccount: '0x1111111111111111111111111111111111111111',
  );

  final buyWaitingForPayment = TransactionDto(
    type: TransactionType.buy,
    inputAmount: 5000,
    inputAsset: 'CHF',
    outputAmount: 50,
    outputAsset: 'REALU',
    state: TransactionState.waitingForPayment,
    date: DateTime.utc(2026, 5, 15, 10),
    sourceAccount: 'CH9300762011623852957',
    targetAccount: '0x1111111111111111111111111111111111111111',
  );

  goldenTest(
    'pending transaction detail',
    fileName: 'pending_transaction_detail',
    constraints: phoneConstraints,
    pumpBeforeTest: (tester) async {
      await tester.pump();
      expect(find.text('Kauf'), findsOneWidget);
      expect(find.text('5000.00 CHF'), findsOneWidget);
      expect(find.text('In Bearbeitung'), findsOneWidget);
      expect(find.text('Betrag in REALU'), findsOneWidget);
      expect(find.text('ca. 50.00'), findsOneWidget);
      expect(find.text('CH9300762011623852957'), findsNothing);
      expect(find.text('IBAN'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
    },
    builder: () => wrapForGolden(
      PendingTransactionDetailPage(
        args: PendingTransactionDetailArgs(transaction: buy),
      ),
    ),
  );

  // This test does not commit a PNG; the regenerate workflow writes it.
  goldenTest(
    'pending sell transaction detail',
    fileName: 'pending_transaction_detail_sell',
    constraints: phoneConstraints,
    pumpBeforeTest: (tester) async {
      await tester.pump();
      expect(find.text('Verkauf'), findsOneWidget);
      expect(find.text('30.00 REALU'), findsOneWidget);
      expect(find.text('Warte auf REALU'), findsOneWidget);
      expect(find.text('Warte auf Zahlung'), findsNothing);
      expect(find.text('Betrag in CHF'), findsOneWidget);
      expect(find.text('ca. 2970.00'), findsOneWidget);
      expect(find.text('CH9300762011623852957'), findsNothing);
      expect(find.text('IBAN'), findsNothing);
      expect(
        find.text('0x1111111111111111111111111111111111111111'),
        findsNothing,
      );
      expect(find.text('Beleg'), findsNothing);
      expect(find.text('RealUnit-Verkauf'), findsNothing);
    },
    builder: () => wrapForGolden(
      PendingTransactionDetailPage(
        args: PendingTransactionDetailArgs(transaction: sell),
      ),
    ),
  );

  // This test does not commit a PNG; the regenerate workflow writes it.
  goldenTest(
    'pending buy transaction detail waiting for payment',
    fileName: 'pending_transaction_detail_waiting_for_payment',
    constraints: phoneConstraints,
    pumpBeforeTest: (tester) async {
      await tester.pump();
      expect(find.text('Kauf'), findsOneWidget);
      expect(find.text('5000.00 CHF'), findsOneWidget);
      expect(find.text('Warte auf Zahlung'), findsOneWidget);
      expect(find.text('Warte auf REALU'), findsNothing);
      expect(find.text('Betrag in REALU'), findsOneWidget);
      expect(find.text('ca. 50.00'), findsOneWidget);
    },
    builder: () => wrapForGolden(
      PendingTransactionDetailPage(
        args: PendingTransactionDetailArgs(transaction: buyWaitingForPayment),
      ),
    ),
  );
}
