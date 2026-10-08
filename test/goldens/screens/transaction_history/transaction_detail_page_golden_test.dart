import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/dfx_transaction.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/receipt/transaction_history_receipt_cubit.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_detail_page.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

import '../../../helper/helper.dart';

class _MockTransactionHistoryReceiptCubit
    extends MockCubit<TransactionHistoryReceiptState>
    implements TransactionHistoryReceiptCubit {}

void main() {
  // The timestamp is formatted in the runner's local zone, same as the other
  // transaction-history goldens. This test does not commit a PNG; the
  // regenerate workflow does.

  late MockSettingsBloc settingsBloc;
  late _MockTransactionHistoryReceiptCubit receiptCubit;

  final sale = DfxTransaction(
    dfxId: 1,
    inputAmount: 20,
    inputAsset: 'REALU',
    outputAmount: 1980,
    outputAsset: 'CHF',
    height: 0,
    txId: 'tx-sale-sheet',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x1111111111111111111111111111111111111111',
    receiverAddress: '0x2222222222222222222222222222222222222222',
    amount: BigInt.from(20),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.sale,
    note: '',
    data: null,
    timestamp: DateTime.utc(2026, 8, 24, 10),
  );

  final saleWithoutHash = DfxTransaction(
    dfxId: 1,
    inputAmount: 20,
    inputAsset: 'REALU',
    outputAmount: 1980,
    outputAsset: 'CHF',
    height: 0,
    txId: '',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x1111111111111111111111111111111111111111',
    receiverAddress: '0x2222222222222222222222222222222222222222',
    amount: BigInt.from(20),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.sale,
    note: '',
    data: null,
    timestamp: DateTime.utc(2026, 8, 24, 10),
  );

  final purchase = DfxTransaction(
    dfxId: 2,
    inputAmount: 5000,
    inputAsset: 'CHF',
    outputAmount: 50,
    outputAsset: 'REALU',
    height: 0,
    txId: 'tx-purchase-detail',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x2222222222222222222222222222222222222222',
    receiverAddress: '0x1111111111111111111111111111111111111111',
    amount: BigInt.from(50),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.purchase,
    note: '',
    data: null,
    timestamp: DateTime.utc(2026, 5, 20, 10),
  );

  final received = Transaction(
    height: 0,
    txId: 'tx-received-detail',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x2222222222222222222222222222222222222222',
    receiverAddress: '0x1111111111111111111111111111111111111111',
    amount: BigInt.from(10),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.transferIn,
    note: null,
    data: null,
    timestamp: DateTime.utc(2026, 5, 19, 12),
  );

  final sent = Transaction(
    height: 0,
    txId: 'tx-sent-detail',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x1111111111111111111111111111111111111111',
    receiverAddress: '0x2222222222222222222222222222222222222222',
    amount: BigInt.from(10),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.transferOut,
    note: '',
    data: null,
    timestamp: DateTime.utc(2026, 5, 18, 14),
  );

  final sentWithoutHash = Transaction(
    height: 0,
    txId: '',
    chainId: realUnitAsset.chainId,
    senderAddress: '0x1111111111111111111111111111111111111111',
    receiverAddress: '0x2222222222222222222222222222222222222222',
    amount: BigInt.from(10),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    category: TransferCategory.transferOut,
    note: '',
    data: null,
    timestamp: DateTime.utc(2026, 5, 18, 14),
  );

  final referral = Transaction(
    height: 0,
    txId: 'tx-referral-detail',
    chainId: realUnitAsset.chainId,
    senderAddress: kReferralPayoutSenderAddress,
    receiverAddress: '0x1111111111111111111111111111111111111111',
    amount: BigInt.from(20),
    asset: realUnitAsset,
    type: TransactionTypes.referralPayout,
    note: '',
    data: '246.50',
    timestamp: DateTime.utc(2026, 5, 20, 10),
  );

  setUpAll(() {
    registerFallbackValue(Currency.chf);
    registerFallbackValue(Language.en);
  });

  setUp(() {
    settingsBloc = MockSettingsBloc();
    when(
      () => settingsBloc.state,
    ).thenReturn(const SettingsState(language: Language.de));

    receiptCubit = _MockTransactionHistoryReceiptCubit();
    when(
      () => receiptCubit.state,
    ).thenReturn(const TransactionHistoryReceiptInitial());
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
  });

  group('$TransactionDetailView', () {
    goldenTest(
      'sale detail page with two receipt buttons',
      fileName: 'transaction_detail_sale',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Verkauf'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('RealUnit-Verkauf'), findsOneWidget);
        expect(find.text('Tausch ZCHF in CHF/EUR'), findsOneWidget);
        expect(find.text('Betrag in CHF'), findsOneWidget);
        expect(find.text('1980.00'), findsOneWidget);
        expect(find.text('tx-sale-sheet'), findsNothing);
        expect(find.text('Absender'), findsNothing);
        expect(find.text('Empfänger'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: sale,
              walletAddress: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'purchase detail page',
      fileName: 'transaction_detail_purchase',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Kauf'), findsOneWidget);
        expect(find.text('+ 50 REALU'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('Beleg'), findsOneWidget);
        expect(find.text('Betrag in CHF'), findsOneWidget);
        expect(find.text('5000.00'), findsOneWidget);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(find.text('Tausch ZCHF in CHF/EUR'), findsNothing);
        expect(
          find.text('0x1111111111111111111111111111111111111111'),
          findsNothing,
        );
        expect(find.text('tx-purchase-detail'), findsNothing);
        expect(
          find.text('Beleg konnte nicht erstellt werden.'),
          findsNothing,
        );
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: purchase,
              walletAddress: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'received transfer detail page',
      fileName: 'transaction_detail_received',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Empfangen'), findsOneWidget);
        expect(find.text('+ 10 REALU'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('Beleg'), findsOneWidget);
        expect(find.text('Betrag in CHF'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(
          find.text('0x1111111111111111111111111111111111111111'),
          findsNothing,
        );
        expect(find.text('tx-received-detail'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: received,
              walletAddress: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'sent transfer detail page',
      fileName: 'transaction_detail_sent',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Gesendet'), findsOneWidget);
        expect(find.text('- 10 REALU'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('Beleg'), findsOneWidget);
        expect(find.text('Betrag in CHF'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(
          find.text('0x1111111111111111111111111111111111111111'),
          findsNothing,
        );
        expect(find.text('tx-sent-detail'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: sent,
              walletAddress: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'referral payout detail page',
      fileName: 'transaction_detail_referral',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Empfehlungsprämie'), findsOneWidget);
        expect(find.text('+ 20 REALU'), findsOneWidget);
        expect(find.textContaining('246.50'), findsOneWidget);
        expect(find.textContaining('Gutschrift'), findsOneWidget);
        expect(find.text('Belege'), findsNothing);
        expect(find.text('Beleg'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(find.text('tx-referral-detail'), findsNothing);
        expect(find.byType(AppFilledButton), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: referral,
              walletAddress: '0x1111111111111111111111111111111111111111',
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'sale detail page with back-to-main button',
      fileName: 'transaction_detail_back_to_main',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Verkauf'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('Zurück zum Hauptscreen'), findsOneWidget);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: sale,
              walletAddress: '0x1111111111111111111111111111111111111111',
              returnToDashboard: true,
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'sent transfer detail page with back-to-main button',
      fileName: 'transaction_detail_sent_back_to_main',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Gesendet'), findsOneWidget);
        expect(find.text('- 10 REALU'), findsOneWidget);
        expect(find.text('Belege'), findsOneWidget);
        expect(find.text('Beleg'), findsOneWidget);
        expect(find.text('Zurück zum Hauptscreen'), findsOneWidget);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(find.text('Tausch ZCHF in CHF/EUR'), findsNothing);
        expect(find.text('Verkauf'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: sent,
              walletAddress: '0x1111111111111111111111111111111111111111',
              returnToDashboard: true,
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'sale detail without a receipt and with the back-to-main button',
      fileName: 'transaction_detail_sale_no_receipt_back_to_main',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Verkauf'), findsOneWidget);
        expect(find.text('- 20 REALU'), findsOneWidget);
        expect(find.text('Zurück zum Hauptscreen'), findsOneWidget);
        expect(find.text('Belege'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(find.text('Tausch ZCHF in CHF/EUR'), findsNothing);
        expect(find.text('Beleg'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: saleWithoutHash,
              walletAddress: '0x1111111111111111111111111111111111111111',
              returnToDashboard: true,
            ),
          ),
        ),
      ),
    );

    // This test does not commit a PNG; the regenerate workflow writes it.
    goldenTest(
      'sent transfer detail without a receipt and with the back-to-main button',
      fileName: 'transaction_detail_sent_no_receipt_back_to_main',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        expect(find.text('Gesendet'), findsOneWidget);
        expect(find.text('- 10 REALU'), findsOneWidget);
        expect(find.text('Zurück zum Hauptscreen'), findsOneWidget);
        expect(find.text('Belege'), findsNothing);
        expect(find.text('Beleg'), findsNothing);
        expect(find.text('RealUnit-Verkauf'), findsNothing);
        expect(find.text('Verkauf'), findsNothing);
      },
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryReceiptCubit>.value(
              value: receiptCubit,
            ),
          ],
          child: TransactionDetailView(
            args: TransactionDetailArgs(
              transaction: sentWithoutHash,
              walletAddress: '0x1111111111111111111111111111111111111111',
              returnToDashboard: true,
            ),
          ),
        ),
      ),
    );
  });
}
