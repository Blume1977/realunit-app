import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/balance.dart';
import 'package:realunit_wallet/models/portfolio_value_point.dart';
import 'package:realunit_wallet/models/price_point.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/repository/transaction_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/models/transactions/dto/transactions_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pdf_service.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_referral_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/balance_cubit.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/pending_transactions_cubit.dart';
import 'package:realunit_wallet/screens/dashboard/dashboard_page.dart';
import 'package:realunit_wallet/screens/referral/referral_bind_error_dialog.dart';
import 'package:realunit_wallet/screens/referral/referral_bind_invite_recognized_dialog.dart';
import 'package:realunit_wallet/screens/referral/referral_bind_promo_dialog.dart';
import 'package:realunit_wallet/screens/referral/referral_bind_unavailable_dialog.dart';
import 'package:realunit_wallet/screens/referral/referral_error_message.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../../helper/helper.dart';

class _MockTransactionRepository extends Mock implements TransactionRepository {}

class _MockRealUnitPdfService extends Mock implements RealUnitPdfService {}

class _MockApiConfig extends Mock implements ApiConfig {}

class _MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class _MockBalanceCubit extends MockCubit<Balance> implements BalanceCubit {}

class _MockPendingTransactionsCubit extends MockCubit<List<TransactionDto>>
    implements PendingTransactionsCubit {}

void main() {
  const walletAddress = '0xcabd3f4b10a7089986e708d19140bfc98e5880c0';
  const counterparty = '0x1234567890abcdef1234567890abcdef12345678';

  late _MockDashboardBloc dashboardBloc;
  late _MockBalanceCubit balanceCubit;
  late _MockPendingTransactionsCubit pendingTxCubit;
  late MockSettingsBloc settingsBloc;
  final transactionRepository = _MockTransactionRepository();

  final priceChart = <PricePoint>[
    PricePoint(asset: realUnitAsset, price: BigInt.from(148), time: DateTime.utc(2025, 11)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(150), time: DateTime.utc(2025, 12)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(149), time: DateTime.utc(2026, 1)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(152), time: DateTime.utc(2026, 2)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(151), time: DateTime.utc(2026, 3)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(155), time: DateTime.utc(2026, 4)),
    PricePoint(asset: realUnitAsset, price: BigInt.from(153), time: DateTime.utc(2026, 5)),
  ];

  final portfolioHistory = <PortfolioValuePoint>[
    PortfolioValuePoint(value: BigInt.from(14800), balance: BigInt.from(100), time: DateTime.utc(2025, 11)),
    PortfolioValuePoint(value: BigInt.from(15000), balance: BigInt.from(100), time: DateTime.utc(2025, 12)),
    PortfolioValuePoint(value: BigInt.from(14900), balance: BigInt.from(100), time: DateTime.utc(2026, 1)),
    PortfolioValuePoint(value: BigInt.from(15200), balance: BigInt.from(100), time: DateTime.utc(2026, 2)),
    PortfolioValuePoint(value: BigInt.from(15100), balance: BigInt.from(100), time: DateTime.utc(2026, 3)),
    PortfolioValuePoint(value: BigInt.from(15500), balance: BigInt.from(100), time: DateTime.utc(2026, 4)),
    PortfolioValuePoint(value: BigInt.from(15300), balance: BigInt.from(100), time: DateTime.utc(2026, 5)),
  ];

  final recentBuy = Transaction(
    height: 200,
    txId: '0xrecent1',
    chainId: 1,
    senderAddress: counterparty,
    receiverAddress: walletAddress,
    amount: BigInt.from(99),
    asset: realUnitAsset,
    type: TransactionTypes.tokenTransfer,
    note: null,
    data: null,
    timestamp: DateTime.utc(2026, 8, 14, 10, 26),
  );

  setUpAll(() {
    final getIt = GetIt.instance;
    final apiConfig = _MockApiConfig();
    final appStore = MockAppStore();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    when(() => appStore.primaryAddress).thenReturn(walletAddress);
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<RealUnitPdfService>(_MockRealUnitPdfService());
    getIt.registerSingleton<TransactionRepository>(transactionRepository);
    getIt.registerSingleton<RealUnitReferralService>(
      MockRealUnitReferralService(),
    );
  });

  tearDownAll(() async => GetIt.instance.reset());

  setUp(() {
    dashboardBloc = _MockDashboardBloc();
    balanceCubit = _MockBalanceCubit();
    pendingTxCubit = _MockPendingTransactionsCubit();
    settingsBloc = MockSettingsBloc();

    when(() => dashboardBloc.state).thenReturn(
      DashboardState(
        price: BigInt.from(138),
        priceChart: priceChart,
        portfolioHistory: portfolioHistory,
        currency: Currency.chf,
      ),
    );
    when(() => balanceCubit.state).thenReturn(
      Balance(
        chainId: realUnitAsset.chainId,
        contractAddress: realUnitAsset.address,
        walletAddress: walletAddress,
        balance: BigInt.from(99),
        asset: realUnitAsset,
      ),
    );
    when(() => balanceCubit.asset).thenReturn(realUnitAsset);
    when(() => pendingTxCubit.state).thenReturn(const <TransactionDto>[]);
    when(() => settingsBloc.state).thenReturn(const SettingsState());
    when(() => transactionRepository.watchTransactionsOfAssets(any(), any(), any()))
        .thenAnswer((_) => Stream.value([recentBuy]));
  });

  Widget dashboard() => MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
          BlocProvider<BalanceCubit>.value(value: balanceCubit),
          BlocProvider<PendingTransactionsCubit>.value(value: pendingTxCubit),
        ],
        child: const DashboardView(),
      );

  Widget overlay(String token) => wrapForGolden(
        Stack(
          fit: StackFit.expand,
          children: [
            dashboard(),
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(child: ReferralBindErrorDialog(token: token)),
          ],
        ),
      );

  group('$ReferralBindErrorDialog', () {
    goldenTest(
      'invalid or expired on the live dashboard',
      fileName: 'referral_bind_error_invalid',
      constraints: phoneConstraints,
      builder: () => overlay(referralInvalidMessage),
    );

    goldenTest(
      'already registered (first RealUnit purchase done)',
      fileName: 'referral_bind_error_already_registered',
      constraints: phoneConstraints,
      builder: () => overlay(referralAlreadyRegisteredMessage),
    );

    goldenTest(
      'already bound',
      fileName: 'referral_bind_error_already_bound',
      constraints: phoneConstraints,
      builder: () => overlay(referralAlreadyBoundMessage),
    );

    goldenTest(
      'self-referral',
      fileName: 'referral_bind_error_self_referral',
      constraints: phoneConstraints,
      builder: () => overlay(referralSelfReferralMessage),
    );

    goldenTest(
      'spent',
      fileName: 'referral_bind_error_spent',
      constraints: phoneConstraints,
      builder: () => overlay(referralSpentMessage),
    );
  });

  goldenTest(
    'invite recognized on the live dashboard',
    fileName: 'referral_bind_invite_recognized',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      Stack(
        fit: StackFit.expand,
        children: [
          dashboard(),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          const Center(
            child: ReferralBindInviteRecognizedDialog(inviterName: 'Björn'),
          ),
        ],
      ),
    ),
  );

  goldenTest(
    'promo campaign text on the live dashboard',
    fileName: 'referral_bind_promo',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      Stack(
        fit: StackFit.expand,
        children: [
          dashboard(),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          const Center(
            child: ReferralBindPromoDialog(
              campaignText: 'Beispieltext der Aktion.',
              textLang: 'de',
            ),
          ),
        ],
      ),
    ),
  );

  goldenTest(
    'unavailable code check on the live dashboard',
    fileName: 'referral_bind_unavailable',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      Stack(
        fit: StackFit.expand,
        children: [
          dashboard(),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: ReferralBindUnavailableDialog(
              retrying: false,
              onRetry: () {},
              onClose: () {},
            ),
          ),
        ],
      ),
    ),
  );

  goldenTest(
    'unavailable code check while retrying',
    // The loading button hosts a CupertinoActivityIndicator; freeze it on the
    // first frame instead of letting pumpAndSettle time out.
    pumpBeforeTest: pumpOnce,
    fileName: 'referral_bind_unavailable_retrying',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      Stack(
        fit: StackFit.expand,
        children: [
          dashboard(),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: ReferralBindUnavailableDialog(
              retrying: true,
              onRetry: () {},
              onClose: () {},
            ),
          ),
        ],
      ),
    ),
  );
}
