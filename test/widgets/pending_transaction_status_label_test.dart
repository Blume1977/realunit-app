import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';
import 'package:realunit_wallet/widgets/pending_transaction_status_label.dart';

import '../helper/helper.dart';

void main() {
  Future<String> labelOf(
    WidgetTester tester,
    TransactionDto transaction, {
    Locale locale = const Locale('de'),
  }) async {
    late String label;
    await tester.pumpApp(
      Builder(
        builder: (context) {
          label = pendingTransactionStatusLabel(context, transaction);
          return const SizedBox.shrink();
        },
      ),
      locale: locale,
    );
    return label;
  }

  group('pendingTransactionStatusLabel', () {
    testWidgets('a buy waits for the payment', (tester) async {
      const transaction = TransactionDto(
        type: TransactionType.buy,
        state: TransactionState.waitingForPayment,
      );

      expect(await labelOf(tester, transaction), 'Warte auf Zahlung');
    });

    for (final type in [TransactionType.sell, TransactionType.swap]) {
      testWidgets('a ${type.value} waits for the tokens', (tester) async {
        final transaction = TransactionDto(type: type, state: TransactionState.waitingForPayment);

        expect(await labelOf(tester, transaction), 'Warte auf REALU');
      });
    }

    testWidgets('a transaction without a type waits for the payment', (tester) async {
      const transaction = TransactionDto(state: TransactionState.waitingForPayment);

      expect(await labelOf(tester, transaction), 'Warte auf Zahlung');
    });

    for (final state in [TransactionState.processing, TransactionState.payoutInProgress, null]) {
      testWidgets('a sell in state ${state?.value} is in processing', (tester) async {
        final transaction = TransactionDto(type: TransactionType.sell, state: state);

        expect(await labelOf(tester, transaction), 'In Bearbeitung');
      });
    }

    testWidgets('names the tokens in English', (tester) async {
      const transaction = TransactionDto(
        type: TransactionType.sell,
        state: TransactionState.waitingForPayment,
      );

      expect(
        await labelOf(tester, transaction, locale: const Locale('en')),
        'Waiting for REALU',
      );
    });
  });
}
