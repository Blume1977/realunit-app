import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/balance.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/repository/balance_repository.dart';
import 'package:realunit_wallet/packages/repository/supported_fiat_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_bank_account_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_brokerbot_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_price_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/bank_account/bank_account.dart';
import 'package:realunit_wallet/packages/service/dfx/models/bank_account/dto/bank_account_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_sell_payment_info_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_balance/sell_balance_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_converter/sell_converter_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_payment_info/sell_payment_info_cubit.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_selected_bank_account/sell_selected_bank_account_cubit.dart';
import 'package:realunit_wallet/screens/sell/sell_page.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/payment_info_error.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helper/helper.dart';

class _MockSellConverterCubit extends MockCubit<SellConverterState>
    implements SellConverterCubit {}

class _MockSellPaymentInfoCubit extends MockCubit<SellPaymentInfoState>
    implements SellPaymentInfoCubit {}

class _MockSellSelectedBankAccountCubit extends MockCubit<BankAccount?>
    implements SellSelectedBankAccountCubit {}

class _MockSellBalanceCubit extends MockCubit<Balance> implements SellBalanceCubit {}

class _MockDfxBrokerbotService extends Mock implements DfxBrokerbotService {}

class _MockDfxBankAccountService extends Mock implements DfxBankAccountService {}

class _MockDfxPriceService extends Mock implements DFXPriceService {}

class _MockRealUnitSellPaymentInfoService extends Mock
    implements RealUnitSellPaymentInfoService {}

class _MockBalanceRepository extends Mock implements BalanceRepository {}

class _MockSupportedFiatRepository extends Mock implements SupportedFiatRepository {}

class _MockApiConfig extends Mock implements ApiConfig {}

void main() {
  late _MockSellConverterCubit converterCubit;
  late _MockSellPaymentInfoCubit paymentInfoCubit;
  late _MockSellSelectedBankAccountCubit selectedBankAccountCubit;
  late _MockSellBalanceCubit balanceCubit;

  Balance zeroBalance() => Balance(
        chainId: 1,
        contractAddress: '0x0',
        walletAddress: '0x0',
        balance: BigInt.zero,
        asset: realUnitAsset,
      );

  setUpAll(() async {
    registerFallbackValue(zeroBalance());

    SharedPreferences.setMockInitialValues({});
    final getIt = GetIt.instance;
    final apiConfig = _MockApiConfig();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    final appStore = MockAppStore();
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    when(() => appStore.wallet).thenReturn(MockSoftwareWallet());
    when(() => appStore.primaryAddress).thenReturn(
      '0x0000000000000000000000000000000000000000',
    );
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<DfxBrokerbotService>(_MockDfxBrokerbotService());
    getIt.registerSingleton<DfxBankAccountService>(_MockDfxBankAccountService());
    getIt.registerSingleton<DFXPriceService>(_MockDfxPriceService());
    getIt.registerSingleton<RealUnitSellPaymentInfoService>(
      _MockRealUnitSellPaymentInfoService(),
    );
    getIt.registerSingleton<SharedPreferences>(await SharedPreferences.getInstance());
    final balanceRepository = _MockBalanceRepository();
    when(() => balanceRepository.watchBalance(any()))
        .thenAnswer((_) => Stream.value(zeroBalance()));
    when(() => balanceRepository.saveBalance(any())).thenAnswer((_) async {});
    getIt.registerSingleton<BalanceRepository>(balanceRepository);

    final fiatRepo = _MockSupportedFiatRepository();
    when(() => fiatRepo.getSellable()).thenAnswer((_) async => const [Currency.chf]);
    when(() => fiatRepo.getBuyable())
        .thenAnswer((_) async => const [Currency.chf, Currency.eur]);
    when(() => fiatRepo.getAll())
        .thenAnswer((_) async => const [Currency.chf, Currency.eur]);
    getIt.registerSingleton<SupportedFiatRepository>(fiatRepo);
  });

  setUp(() {
    converterCubit = _MockSellConverterCubit();
    paymentInfoCubit = _MockSellPaymentInfoCubit();
    selectedBankAccountCubit = _MockSellSelectedBankAccountCubit();
    balanceCubit = _MockSellBalanceCubit();

    when(() => converterCubit.state).thenReturn(const SellConverterState());
    when(() => converterCubit.onSharesChanged(any())).thenAnswer((_) async {});
    when(() => paymentInfoCubit.state).thenReturn(const SellPaymentInfoInitial());
    when(() => selectedBankAccountCubit.state).thenReturn(null);
    when(() => balanceCubit.state).thenReturn(zeroBalance());
  });

  tearDown(() {
    final service = GetIt.instance<DfxBankAccountService>();
    if (service is Mock) reset(service);
  });

  tearDownAll(() async => GetIt.instance.reset());

  Widget buildSubject() => MultiBlocProvider(
        providers: [
          BlocProvider<SellConverterCubit>.value(value: converterCubit),
          BlocProvider<SellPaymentInfoCubit>.value(value: paymentInfoCubit),
          BlocProvider<SellSelectedBankAccountCubit>.value(value: selectedBankAccountCubit),
          BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
        ],
        child: const SellView(),
      );

  group('$SellView', () {
    goldenTest(
      'no bank account, zero balance',
      fileName: 'sell_no_account_zero_balance',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () => wrapForGolden(buildSubject()),
    );

    goldenTest(
      'with balance',
      fileName: 'sell_with_balance',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'holding after Kauf — Max fills 85194',
      fileName: 'sell_holding_kauf',
      constraints: phoneConstraints,
      whilePerforming: (tester) async {
        await tester.tap(find.text('MAX'));
        await tester.pump();
        return null;
      },
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(85194),
            asset: realUnitAsset,
          ),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'holding after Verkauf — Max fills 77994',
      fileName: 'sell_holding_verkauf',
      constraints: phoneConstraints,
      whilePerforming: (tester) async {
        await tester.tap(find.text('MAX'));
        await tester.pump();
        return null;
      },
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(77994),
            asset: realUnitAsset,
          ),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'payment info loading',
      fileName: 'sell_payment_info_loading',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      // Loading state renders a CircularProgressIndicator — its animation
      // never settles, so pumpAndSettle (default in precacheImages) hits
      // its timeout. pumpOnce captures the first frame without waiting.
      pumpBeforeTest: pumpOnce,
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        when(() => paymentInfoCubit.state)
            .thenReturn(const SellPaymentInfoLoading());
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'kyc required failure',
      fileName: 'sell_kyc_required',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        when(() => paymentInfoCubit.state).thenReturn(
          const SellPaymentInfoFailure(PaymentInfoError.kycRequired),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'min amount not met failure',
      fileName: 'sell_min_amount_not_met',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        when(() => paymentInfoCubit.state).thenReturn(
          const SellPaymentInfoMinAmountNotMet(
            minAmount: 10,
            currency: Currency.chf,
          ),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'unknown error failure',
      fileName: 'sell_unknown_error',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        when(() => paymentInfoCubit.state).thenReturn(
          const SellPaymentInfoFailure(PaymentInfoError.unknown),
        );
        return wrapForGolden(buildSubject());
      },
    );

    // Without an API message the red snackbar carries the app's own text, never
    // a technical one. The snackbar cannot pumpAndSettle, so deliver the
    // emission and advance a fixed 500ms past its entrance.
    goldenTest(
      'unknown error without an API message shows the app text',
      fileName: 'sell_failure_generic',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      pumpBeforeTest: (tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
      builder: () {
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        whenListen(
          paymentInfoCubit,
          Stream<SellPaymentInfoState>.value(
            const SellPaymentInfoFailure(PaymentInfoError.unknown),
          ),
          initialState: const SellPaymentInfoInitial(),
        );
        return wrapForGolden(buildSubject());
      },
    );

    goldenTest(
      'share count in the quote does not match the request',
      fileName: 'sell_share_count_mismatch',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () {
        whenListen(
          converterCubit,
          Stream<SellConverterState>.value(
            const SellConverterState(sharesText: '100', fiatText: '100'),
          ),
          initialState: const SellConverterState(loading: true),
        );
        when(() => selectedBankAccountCubit.state).thenReturn(
          const BankAccount(
            id: 1,
            iban: 'CH9300762011623852957',
            name: 'Raiffeisen',
            isActive: true,
            isDefault: true,
          ),
        );
        when(() => GetIt.instance<DfxBankAccountService>().getBankAccounts()).thenAnswer(
          (_) async => const [
            BankAccountDto(
              id: 1,
              iban: 'CH9300762011623852957',
              label: 'Raiffeisen',
              isActive: true,
              isDefault: true,
            ),
          ],
        );
        when(() => balanceCubit.state).thenReturn(
          Balance(
            chainId: 1,
            contractAddress: '0x0',
            walletAddress: '0x0',
            balance: BigInt.from(1000000000000000000),
            asset: realUnitAsset,
          ),
        );
        when(() => paymentInfoCubit.state).thenReturn(
          const SellPaymentInfoFailure(PaymentInfoError.shareCountMismatch),
        );
        return wrapForGolden(buildSubject());
      },
    );
  });
}
