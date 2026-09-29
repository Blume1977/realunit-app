import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_blockchain_api_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_faucet_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_quote/pay_quote_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_process_page.dart';
import 'package:realunit_wallet/screens/pay/pay_quote_page.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

import '../../helper/helper.dart';

class _MockPayQuoteCubit extends MockCubit<PayQuoteState> implements PayQuoteCubit {}

class _MockPayService extends Mock implements RealUnitPayService {}

class _MockFaucetService extends Mock implements DfxFaucetService {}

class _MockBlockchainService extends Mock implements DfxBlockchainApiService {}

class _MockWalletService extends Mock implements WalletService {}

class _MockAppStore extends Mock implements AppStore {}

class _MockApiConfig extends Mock implements ApiConfig {}

class _MockWallet extends Mock implements SoftwareWallet {}

void main() {
  late _MockPayQuoteCubit quoteCubit;

  // One REALU pays 1.20 CHF. Bill 2.00 CHF, fee 0.05 CHF, so 2 shares
  // pay 2.40 CHF. One share would not cover 2.05 CHF.
  const readySwap = SwapPaymentInfo(
    id: 99,
    amount: 2,
    estimatedAmount: 2.4,
    targetAsset: 'ZCHF',
    ethBalance: 1.0,
    requiredGasEth: 0.001,
    isValid: true,
    ethereumTransactionFeeChf: 0.05,
    ethereumTransactionFeeRealu: 0.05 / 1.2,
  );

  final ready = PayQuoteReady(
    paymentLinkId: 'pl_realunit_ocp_sepolia',
    quoteId: 'plq_realunit_ocp_sepolia',
    fiatAsset: 'CHF',
    fiatAmount: 2,
    zchfAmount: 2.0,
    expiresAt: DateTime.utc(2099),
    merchantName: 'Café Zürich',
    swap: readySwap,
  );

  setUpAll(() {
    final getIt = GetIt.instance;

    // PayQuotePage resolves the pay service from getIt and creates the cubit
    // without load(); a route gate calls load() after the route animation
    // completes (immediately when pumped as home). The load throws a typed
    // error here so the page builds deterministically (PayQuoteError) without
    // a live backend.
    final payService = _MockPayService();
    when(() => payService.getPaymentDetails(any())).thenThrow(
      const ApiException(code: 'TEST', message: 'no backend in widget test'),
    );
    getIt.registerSingleton<RealUnitPayService>(payService);

    // The confirm button pushes PayProcessPage, which resolves a full service
    // graph from getIt; its route gate starts the cubit after animation.
    // A debug wallet makes start() settle immediately (signatureUnsupported)
    // without touching the chain.
    getIt.registerSingleton<DfxFaucetService>(_MockFaucetService());
    getIt.registerSingleton<DfxBlockchainApiService>(_MockBlockchainService());
    getIt.registerSingleton<WalletService>(_MockWalletService());
    final appStore = _MockAppStore();
    final apiConfig = _MockApiConfig();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    final wallet = _MockWallet();
    when(() => wallet.walletType).thenReturn(WalletType.debug);
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    getIt.registerSingleton<AppStore>(appStore);
  });

  tearDownAll(() async => GetIt.instance.reset());

  setUp(() {
    quoteCubit = _MockPayQuoteCubit();
    when(() => quoteCubit.state).thenReturn(const PayQuoteLoading());
  });

  Widget buildSubject({SettingsBloc? settings}) {
    final settingsBloc = settings ?? MockSettingsBloc();
    if (settings == null) {
      when(() => settingsBloc.state).thenReturn(const SettingsState());
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<PayQuoteCubit>.value(value: quoteCubit),
      ],
      child: const PayQuoteView(),
    );
  }

  group('$PayQuotePage', () {
    testWidgets('builds its own cubit and renders $PayQuoteView', (tester) async {
      final settingsBloc = MockSettingsBloc();
      when(() => settingsBloc.state).thenReturn(const SettingsState());
      await tester.pumpApp(
        BlocProvider<SettingsBloc>.value(
          value: settingsBloc,
          child: const PayQuotePage(paymentLinkId: 'pl_abc'),
        ),
      );

      expect(find.byType(PayQuoteView), findsOne);
    });
  });

  group('$PayQuoteView', () {
    testWidgets('loading state shows a $CupertinoActivityIndicator', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteLoading());
      await tester.pumpApp(buildSubject());

      expect(find.byType(CupertinoActivityIndicator), findsOne);
    });

    testWidgets('ready state shows the REALU total and the four-line breakdown', (tester) async {
      when(() => quoteCubit.state).thenReturn(
        PayQuoteReady(
          paymentLinkId: ready.paymentLinkId,
          quoteId: ready.quoteId,
          fiatAsset: ready.fiatAsset,
          fiatAmount: ready.fiatAmount,
          zchfAmount: ready.zchfAmount,
          merchantName: ready.merchantName,
          expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
          swap: ready.swap,
        ),
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () async {
        await tester.pumpApp(buildSubject());
      });

      expect(find.text(S.current.payQuoteMerchant), findsOne);
      expect(find.text('Café Zürich'), findsOne);
      expect(find.text(S.current.youPay), findsOne);
      expect(find.text('2 REALU'), findsOne);
      expect(find.text('05:00'), findsOne);
      expect(find.text(S.current.payQuoteRequested), findsOne);
      expect(find.text('2.00 CHF'), findsOne);
      expect(find.text('1.66666667 REALU'), findsOne);
      expect(find.text(S.current.payQuoteRealuFees), findsOne);
      expect(find.text('0.05 CHF'), findsOne);
      expect(find.text('0.04166667 REALU'), findsOne);
      expect(find.text(S.current.payQuoteRounding), findsOne);
      expect(find.text('0.35 CHF'), findsOne);
      expect(find.text('0.29166667 REALU'), findsOne);
      expect(find.text(S.current.payQuoteTotal), findsOne);
      expect(find.text('2.40 CHF'), findsOne);
      expect(find.text('2.00 REALU'), findsOne);
      expect(find.text(S.current.payConfirmButton), findsOne);
    });

    testWidgets('euro receipt keeps the franc amount the till requested', (tester) async {
      when(() => quoteCubit.state).thenReturn(
        PayQuoteReady(
          paymentLinkId: ready.paymentLinkId,
          quoteId: ready.quoteId,
          fiatAsset: ready.fiatAsset,
          fiatAmount: ready.fiatAmount,
          zchfAmount: ready.zchfAmount,
          merchantName: ready.merchantName,
          expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
          swap: ready.swap,
          billEur: 1.84,
          feeEur: 0.04,
          roundingEur: 0.28,
          totalEur: 2.16,
        ),
      );
      final settingsBloc = MockSettingsBloc();
      when(() => settingsBloc.state).thenReturn(
        const SettingsState(language: Language.de, currency: Currency.eur),
      );
      await withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () async {
        await tester.pumpApp(buildSubject(settings: settingsBloc));
      });

      expect(find.text('2.00 CHF'), findsOne);
      expect(find.text('1.84 EUR'), findsOne);
      expect(find.text('0.04 EUR'), findsOne);
      expect(find.text('0.28 EUR'), findsOne);
      expect(find.text('2.16 EUR'), findsOne);
      expect(find.text('0.05 CHF'), findsNothing);
      expect(find.text('0.35 CHF'), findsNothing);
      expect(find.text('2.40 CHF'), findsNothing);
    });

    testWidgets('ready state shows merchant and REALU swap details when present', (tester) async {
      when(() => quoteCubit.state).thenReturn(
        PayQuoteReady(
          paymentLinkId: 'pl_realunit_ocp_sepolia',
          quoteId: 'plq_realunit_ocp_sepolia',
          fiatAsset: 'CHF',
          fiatAmount: 2,
          zchfAmount: 2.0,
          merchantName: 'Café Zürich',
          merchantCity: 'Zürich',
          expiresAt: DateTime.utc(2099),
          swap: readySwap,
        ),
      );
      await tester.pumpApp(buildSubject());

      expect(find.text('Café Zürich'), findsOne);
      expect(find.text('Zürich'), findsNothing);
      expect(find.text('2 REALU'), findsOne);
      expect(find.text('1.66666667 REALU'), findsOne);
      expect(find.text('0.29166667 REALU'), findsOne);
    });

    testWidgets('confirm button navigates to the process step', (tester) async {
      when(() => quoteCubit.state).thenReturn(ready);
      await tester.pumpApp(buildSubject());

      await tester.tap(find.text(S.current.payConfirmButton));
      // The process page renders a CupertinoActivityIndicator that animates
      // forever, so pumpAndSettle would time out; pump fixed frames to drive
      // the push transition instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PayProcessView), findsOne);
    });

    testWidgets('double-tap on Pay does not push two process routes', (tester) async {
      when(() => quoteCubit.state).thenReturn(ready);
      await tester.pumpApp(buildSubject());

      await tester.tap(find.text(S.current.payConfirmButton));
      await tester.tap(find.text(S.current.payConfirmButton), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Offstage: a second pushed route would hide the first; count both.
      expect(find.byType(PayProcessView, skipOffstage: false), findsOne);
    });

    testWidgets('Pay re-enables after the process route pops', (tester) async {
      when(() => quoteCubit.state).thenReturn(ready);
      await tester.pumpApp(buildSubject());

      await tester.tap(find.text(S.current.payConfirmButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PayProcessView), findsOne);

      // Debug wallet fails before the swap and shows a result sheet. Pop the
      // sheet; the process route then pops with swapCompleted=false so Pay
      // re-enables. Avoid tap(): the sheet is taller than the default test
      // surface, so Close is outside the hit box.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      navigator.pop(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PayProcessView), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, S.current.payConfirmButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('expired state shows the re-scan message', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteExpired());
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.payFailureQuoteExpired), findsOne);
    });

    testWidgets('unavailable state shows the unavailable message', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteUnavailable());
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.payQuoteUnavailable), findsOne);
    });

    testWidgets('error state shows the API message 1:1', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteError('boom'));
      await tester.pumpApp(buildSubject());

      expect(find.text('boom'), findsOne);
      expect(find.text(S.current.payFailureGeneric), findsNothing);
      expect(find.text(S.current.payConfirmButton), findsNothing);
    });

    testWidgets('error state without API text falls back to the generic copy', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteError(''));
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.payFailureGeneric), findsOne);
      expect(find.text(S.current.payConfirmButton), findsNothing);
    });

    testWidgets('error state retry button re-invokes load()', (tester) async {
      when(() => quoteCubit.state).thenReturn(const PayQuoteError('boom'));
      when(() => quoteCubit.load()).thenAnswer((_) async {});
      await tester.pumpApp(buildSubject());

      await tester.tap(find.byKey(const ValueKey('payQuoteRetryButton')));
      await tester.pump();

      verify(() => quoteCubit.load()).called(1);
    });
  });
}
