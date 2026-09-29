import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/balance.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/repository/balance_repository.dart';
import 'package:realunit_wallet/packages/repository/supported_fiat_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_bank_account_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_brokerbot_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_price_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/bank_account/bank_account.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_sell_payment_info_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_balance/sell_balance_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_converter/sell_converter_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_payment_info/sell_payment_info_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_selected_bank_account/sell_selected_bank_account_cubit.dart';
import 'package:realunit_wallet/screens/sell/sell_page.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_add_bank_account_sheet.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_bank_account_field.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_button.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_converter.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_max_amount_button.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/helper.dart';

class MockSellConverterCubit extends MockCubit<SellConverterState> implements SellConverterCubit {}

class MockSellPaymentInfoCubit extends MockCubit<SellPaymentInfoState>
    implements SellPaymentInfoCubit {}

class MockSellSelectedBankAccountCubit extends MockCubit<BankAccount?>
    implements SellSelectedBankAccountCubit {}

class MockSellBalanceCubit extends MockCubit<Balance> implements SellBalanceCubit {}

class MockDfxBrokerbotService extends Mock implements DfxBrokerbotService {}

class MockDfxBankAccountService extends Mock implements DfxBankAccountService {}

class MockDfxPriceService extends Mock implements DFXPriceService {}

class MockRealUnitSellPaymentInfoService extends Mock implements RealUnitSellPaymentInfoService {}

class MockBalanceRepository extends Mock implements BalanceRepository {}

class MockSupportedFiatRepository extends Mock implements SupportedFiatRepository {}

class MockApiConfig extends Mock implements ApiConfig {}

class MockAppStore extends Mock implements AppStore {}

class MockWallet extends Mock implements SoftwareWallet {}

void main() {
  late SellConverterCubit converterCubit;
  late SellPaymentInfoCubit sellPaymentInfoCubit;
  late SellSelectedBankAccountCubit sellSelectedBankAccountCubit;
  late SellBalanceCubit sellBalanceCubit;

  setUpAll(() {
    registerFallbackValue(
      Balance(
        chainId: 1,
        contractAddress: '0x0',
        walletAddress: '0x0',
        balance: BigInt.zero,
        asset: realUnitAsset,
      ),
    );
  });

  setUp(() {
    converterCubit = MockSellConverterCubit();
    sellPaymentInfoCubit = MockSellPaymentInfoCubit();
    sellSelectedBankAccountCubit = MockSellSelectedBankAccountCubit();
    sellBalanceCubit = MockSellBalanceCubit();

    when(() => converterCubit.state).thenReturn(const SellConverterState());
    when(() => sellPaymentInfoCubit.state).thenReturn(const SellPaymentInfoInitial());
    when(
      () => sellPaymentInfoCubit.getPaymentInfo(
        amount: any(named: 'amount'),
        iban: any(named: 'iban'),
        currency: Currency.chf,
      ),
    ).thenAnswer((_) => Future.value());
    when(() => sellSelectedBankAccountCubit.state).thenReturn(null);
    when(() => sellBalanceCubit.state).thenReturn(
      Balance(
        chainId: 1,
        contractAddress: '0x0',
        walletAddress: '0x0',
        balance: BigInt.zero,
        asset: realUnitAsset,
      ),
    );
  });

  Future<void> setupDependencyInjection() async {
    SharedPreferences.setMockInitialValues({});
    final getIt = GetIt.instance;
    final apiConfig = MockApiConfig();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    final appStore = MockAppStore();
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    when(() => appStore.wallet).thenReturn(MockWallet());
    when(() => appStore.primaryAddress).thenReturn('0x0000000000000000000000000000000000000000');
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<DfxBrokerbotService>(MockDfxBrokerbotService());
    getIt.registerSingleton<DfxBankAccountService>(MockDfxBankAccountService());
    getIt.registerSingleton<DFXPriceService>(MockDfxPriceService());
    getIt.registerSingleton<RealUnitSellPaymentInfoService>(MockRealUnitSellPaymentInfoService());
    getIt.registerSingleton<SharedPreferences>(await SharedPreferences.getInstance());
    final balanceRepository = MockBalanceRepository();
    when(() => balanceRepository.watchBalance(any())).thenAnswer(
      (_) => Stream.value(
        Balance(
          chainId: 1,
          contractAddress: '0x0',
          walletAddress: '0x0',
          balance: BigInt.zero,
          asset: realUnitAsset,
        ),
      ),
    );
    when(() => balanceRepository.saveBalance(any())).thenAnswer((_) async {});
    getIt.registerSingleton<BalanceRepository>(balanceRepository);

    final fiatRepo = MockSupportedFiatRepository();
    when(() => fiatRepo.getSellable()).thenAnswer((_) async => const [Currency.chf]);
    when(() => fiatRepo.getBuyable()).thenAnswer((_) async => const [Currency.chf, Currency.eur]);
    when(() => fiatRepo.getAll()).thenAnswer((_) async => const [Currency.chf, Currency.eur]);
    getIt.registerSingleton<SupportedFiatRepository>(fiatRepo);
  }

  setUpAll(() async => await setupDependencyInjection());

  tearDownAll(() async => await GetIt.instance.reset());

  Widget buildSubject(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: converterCubit),
        BlocProvider.value(value: sellPaymentInfoCubit),
        BlocProvider.value(value: sellSelectedBankAccountCubit),
        BlocProvider.value(value: sellBalanceCubit),
      ],
      child: const SellView(),
    );
  }

  group('$SellPage', () {
    testWidgets('renders $SellView', (tester) async {
      final settings = MockSettingsBloc();
      when(() => settings.state).thenReturn(const SettingsState());
      whenListen(
        settings,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(),
      );
      await tester.pumpApp(
        BlocProvider<SettingsBloc>.value(
          value: settings,
          child: const SellPage(),
        ),
      );

      expect(find.byType(SellView), findsOne);
    });
  });

  group('$SellView', () {
    testWidgets('renders initially correctly', (tester) async {
      await tester.pumpApp(buildSubject(const SellView()));

      expect(find.byType(SellConverter), findsOne);
      expect(find.byType(SellBankAccountField), findsOne);
      expect(find.byType(SellButton), findsOne);
    });

    testWidgets('$SellBankAccountField opens $SellAddBankAccountSheet', (tester) async {
      await tester.pumpApp(buildSubject(const SellView()));

      await tester.tap(find.byType(SellBankAccountField));
      await tester.pump();

      expect(find.byType(SellAddBankAccountSheet), findsOne);
    });

    group('$SellMaxAmountButton', () {
      testWidgets(('is shown when balance is bigger than 0'), (tester) async {
        when(() => sellBalanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.one,
            asset: realUnitAsset,
          ),
        );

        await tester.pumpApp(buildSubject(const SellView()));

        expect(find.byType(SellMaxAmountButton), findsOne);
      });

      testWidgets(('is not shown when balance is 0'), (tester) async {
        when(() => sellBalanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.zero,
            asset: realUnitAsset,
          ),
        );

        await tester.pumpApp(buildSubject(const SellView()));

        expect(find.byType(SellMaxAmountButton), findsNothing);
      });
    });

    group('$SellButton', () {
      testWidgets('is initially disabled button', (tester) async {
        when(() => sellPaymentInfoCubit.state).thenReturn(const SellPaymentInfoInitial());
        await tester.pumpApp(buildSubject(const SellView()));

        expect(
          find.byWidgetPredicate(
            (Widget widget) => widget is AppFilledButton && widget.onPressed == null,
          ),
          findsOne,
        );
      });

      testWidgets('shows loading state if SellPaymentInfoState is loading', (tester) async {
        when(() => sellPaymentInfoCubit.state).thenReturn(const SellPaymentInfoLoading());
        await tester.pumpApp(buildSubject(const SellView()));

        expect(find.byType(CupertinoActivityIndicator), findsOne);
      });

      testWidgets('is disabled button when minimum amount is not met', (tester) async {
        // Non-integer min: the traded amount is quantized with .round() before
        // it is sent, so the displayed value must round UP to the smallest
        // whole amount that still satisfies the server-side minimum.
        final minAmount = 10.4;
        final currency = Currency.chf;

        when(
          () => sellPaymentInfoCubit.state,
        ).thenReturn(
          SellPaymentInfoMinAmountNotMet(
            minAmount: minAmount,
            currency: currency,
          ),
        );

        await tester.pumpApp(buildSubject(const SellView()));

        expect(
          find.text(S.current.sellMinAmount('${minAmount.ceil()}', currency.code)),
          findsOne,
        );
        expect(
          find.byWidgetPredicate(
            (Widget widget) => widget is AppFilledButton && widget.onPressed == null,
          ),
          findsOne,
        );
      });

      testWidgets('is enabled button when amount and bankaccount are given', (tester) async {
        whenListen(
          converterCubit,
          Stream.fromIterable([
            const SellConverterState(fiatText: '5.00', sharesText: '0.10', loading: true),
            const SellConverterState(fiatText: '5.00', sharesText: '0.50', loading: false),
          ]),
          initialState: const SellConverterState(fiatText: '1.00', sharesText: '0.10'),
        );

        when(
          () => sellSelectedBankAccountCubit.state,
        ).thenReturn(const BankAccount(id: 1, iban: 'CH12 3456 7890 1234 5678 9'));

        await tester.pumpApp(buildSubject(const SellView()));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (Widget widget) => widget is AppFilledButton && widget.onPressed != null,
          ),
          findsOne,
        );
      });
    });
  });
}
