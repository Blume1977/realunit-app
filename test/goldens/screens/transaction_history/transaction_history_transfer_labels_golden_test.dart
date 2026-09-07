import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/repository/transaction_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pdf_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/filter/transaction_history_filter_cubit.dart';
import 'package:realunit_wallet/screens/transaction_history/transaction_history_page.dart';

import '../../../helper/helper.dart';

// Recategorises the #967 baseline under the same fileName
// `transaction_history_transfer_labels`: the four rows stay in place, but
// inbound 10 is now Empfangen (transferIn) instead of Kauf, so GitHub's
// pixel-diff shows Kauf/Empfangen/Gesendet/Verkauf.

class _MockTransactionHistoryFilterCubit
    extends MockCubit<TransactionHistoryFilterState>
    implements TransactionHistoryFilterCubit {}

class _MockTransactionRepository extends Mock implements TransactionRepository {}

class _MockRealUnitPdfService extends Mock implements RealUnitPdfService {}

class _MockApiConfig extends Mock implements ApiConfig {}

void main() {
  const walletAddress = '0xcabd3f4b10a7089986e708d19140bfc98e5880c0';
  const counterparty = '0x1234567890abcdef1234567890abcdef12345678';

  late MockSettingsBloc settingsBloc;
  final transactionRepository = _MockTransactionRepository();

  // decimals of realUnitAsset is 0 → amounts are plain share counts.
  Transaction inbound(
    String txId,
    int shares,
    DateTime timestamp, {
    TransferCategory? category,
  }) =>
      Transaction(
        height: 200,
        txId: txId,
        chainId: 1,
        senderAddress: counterparty,
        receiverAddress: walletAddress,
        amount: BigInt.from(shares),
        asset: realUnitAsset,
        type: TransactionTypes.tokenTransfer,
        category: category,
        note: null,
        data: null,
        timestamp: timestamp,
      );

  Transaction outbound(
    String txId,
    int shares,
    DateTime timestamp, {
    TransferCategory? category,
  }) =>
      Transaction(
        height: 199,
        txId: txId,
        chainId: 1,
        senderAddress: walletAddress,
        receiverAddress: counterparty,
        amount: BigInt.from(shares),
        asset: realUnitAsset,
        type: TransactionTypes.tokenTransfer,
        category: category,
        note: null,
        data: null,
        timestamp: timestamp,
      );

  final transactions = <Transaction>[
    inbound(
      '0xtx1',
      100,
      DateTime.utc(2026, 5, 20, 10, 30),
      category: TransferCategory.purchase,
    ),
    inbound(
      '0xtx2',
      10,
      DateTime.utc(2026, 5, 19, 12),
      category: TransferCategory.transferIn,
    ),
    outbound(
      '0xtx3',
      10,
      DateTime.utc(2026, 5, 18, 14),
      category: TransferCategory.transferOut,
    ),
    outbound(
      '0xtx4',
      20,
      DateTime.utc(2026, 5, 15, 9, 15),
      category: TransferCategory.sale,
    ),
  ];

  final pinnedClock = Clock.fixed(DateTime.utc(2026, 5, 23));

  setUpAll(() {
    final getIt = GetIt.instance;
    final apiConfig = _MockApiConfig();
    final appStore = MockAppStore();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    when(() => appStore.primaryAddress).thenReturn(walletAddress);
    when(() => transactionRepository.watchTransactionsOfAssets(any(), any()))
        .thenAnswer((_) => const Stream<List<Transaction>>.empty());
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<RealUnitPdfService>(_MockRealUnitPdfService());
    getIt.registerSingleton<TransactionRepository>(transactionRepository);
  });

  tearDownAll(() async => GetIt.instance.reset());

  setUp(() {
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(const SettingsState());
  });

  group('$TransactionHistoryView', () {
    late _MockTransactionHistoryFilterCubit filterCubit;

    setUp(() {
      filterCubit = _MockTransactionHistoryFilterCubit();
      when(() => filterCubit.state).thenReturn(TransactionHistoryFilterState());
    });

    Widget buildSubject() => MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TransactionHistoryFilterCubit>.value(
              value: filterCubit,
            ),
          ],
          child: TransactionHistoryView(walletAddress: walletAddress),
        );

    goldenTest(
      'API category labels purchase, received, sent, sale',
      fileName: 'transaction_history_transfer_labels',
      constraints: phoneConstraints,
      builder: () {
        when(() => filterCubit.state).thenReturn(
          TransactionHistoryFilterState(
            all: transactions,
            filtered: transactions,
          ),
        );
        return withClock(pinnedClock, () => wrapForGolden(buildSubject()));
      },
    );
  });
}
