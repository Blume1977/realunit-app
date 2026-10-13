import 'package:flutter/widgets.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';

/// Resolves the status line of a pending transaction.
///
/// "Waiting for payment" names what the transaction is waiting for: the customer's bank payment on
/// a buy, the customer's tokens on a sale or a payment with tokens. Every other pending state reads
/// "Processing".
String pendingTransactionStatusLabel(BuildContext context, TransactionDto transaction) {
  final s = S.of(context);

  if (transaction.state != TransactionState.waitingForPayment) return s.transactionPending;

  return switch (transaction.type) {
    TransactionType.sell || TransactionType.swap => s.transactionWaitingForTokens,
    _ => s.transactionWaitingForPayment,
  };
}
