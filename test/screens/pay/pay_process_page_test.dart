import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_blockchain_api_service.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_faucet_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_process/pay_process_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_process_page.dart';
import 'package:realunit_wallet/screens/transaction_history/completed_transaction.dart';

import '../../helper/helper.dart';

class _MockPayProcessCubit extends MockCubit<PayProcessState> implements PayProcessCubit {}

class _MockPayService extends Mock implements RealUnitPayService {}

class _MockFaucetService extends Mock implements DfxFaucetService {}

class _MockBlockchainService extends Mock implements DfxBlockchainApiService {}

class _MockWalletService extends Mock implements WalletService {}

class _MockAppStore extends Mock implements AppStore {}

class _MockApiConfig extends Mock implements ApiConfig {}

class _MockWallet extends Mock implements SoftwareWallet {}

// The paying step is reached only when the quote carries a delegation.
// These tests never sign it; the confirm stub never returns.
const _delegation = Eip7702Data(
  relayerAddress: '0x1',
  delegationManagerAddress: '0x2',
  delegatorAddress: '0x3',
  userNonce: 0,
  domain: Eip7702Domain(
    name: 'DelegationManager',
    version: '1',
    chainId: 1,
    verifyingContract: '0x4',
  ),
  types: Eip7702Types(delegation: [], caveat: []),
  message: Eip7702Message(
    delegate: '0x5',
    delegator: '0x6',
    authority: '0x7',
    caveats: [],
    salt: 0,
  ),
  tokenAddress: '0x8',
  amountWei: '1',
  depositAddress: '',
);

const _swap = SwapPaymentInfo(
  id: 99,
  amount: 1,
  estimatedAmount: 1.05,
  targetAsset: 'ZCHF',
  ethBalance: 1,
  requiredGasEth: 0.001,
  isValid: true,
  ethereumTransactionFeeChf: 0.05,
  ethereumTransactionFeeRealu: 0.01234567,
  eip7702: _delegation,
);

void main() {
  late _MockPayProcessCubit processCubit;

  setUpAll(() {
    final getIt = GetIt.instance;
    // PayProcessPage resolves a full service graph from getIt and creates
    // the cubit without start(); a route gate starts it after the route
    // animation completes (immediately when pumped as home). A software
    // wallet whose confirm never returns stays on the paying step.
    registerFallbackValue(_swap);
    final payService = _MockPayService();
    when(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    ).thenAnswer((_) => Completer<String>().future);
    getIt.registerSingleton<RealUnitPayService>(payService);
    getIt.registerSingleton<DfxFaucetService>(_MockFaucetService());
    getIt.registerSingleton<DfxBlockchainApiService>(_MockBlockchainService());
    getIt.registerSingleton<WalletService>(_MockWalletService());
    final appStore = _MockAppStore();
    final apiConfig = _MockApiConfig();
    when(() => apiConfig.asset).thenReturn(realUnitAsset);
    final wallet = _MockWallet();
    when(() => wallet.walletType).thenReturn(WalletType.software);
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => appStore.apiConfig).thenReturn(apiConfig);
    getIt.registerSingleton<AppStore>(appStore);
  });

  tearDownAll(() async => GetIt.instance.reset());

  setUp(() {
    processCubit = _MockPayProcessCubit();
    when(() => processCubit.state).thenReturn(const PayProcessInitial());
    when(() => processCubit.swapCompleted).thenReturn(false);
  });

  Widget buildSubject() => BlocProvider<PayProcessCubit>.value(
    value: processCubit,
    child: const PayProcessView(),
  );

  group('$PayProcessPage', () {
    testWidgets('builds its own cubit and renders $PayProcessView', (tester) async {
      await tester.pumpApp(
        const PayProcessPage(paymentLinkId: 'pl_abc', quoteId: 'quote_xyz', swap: _swap),
      );
      // The route gate starts the cubit after the home route is settled; pump
      // a frame so start() can emit (the sheet animation is not awaited here).
      await tester.pump();

      expect(find.byType(PayProcessView), findsOne);
    });

    testWidgets('keeps preparing UI during route slide; starts only after animation completes', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    TimedMaterialPageRoute<void>(
                      transitionDuration: const Duration(milliseconds: 300),
                      builder: (_) => const PayProcessPage(
                        paymentLinkId: 'pl_abc',
                        quoteId: 'quote_xyz',
                        swap: _swap,
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(); // flush the post-frame callback
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PayProcessView), findsOne);
      expect(
        find.text(S.current.payPreparingSwap, skipOffstage: false),
        findsOne,
      );
      expect(
        find.text(S.current.payFailureTitle, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(S.current.close, skipOffstage: false),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(S.current.payPaying, skipOffstage: false), findsOne);
      expect(find.text(S.current.payFailureTitle, skipOffstage: false), findsNothing);
      expect(find.byIcon(Icons.error_rounded), findsNothing);
    });
  });

  group('$PayProcessView progress labels', () {
    Future<void> expectLabel(WidgetTester tester, PayProcessState state, String label) async {
      when(() => processCubit.state).thenReturn(state);
      await tester.pumpApp(buildSubject());

      expect(find.byType(CupertinoActivityIndicator), findsOne);
      expect(find.text(label), findsOne);
    }

    testWidgets('initial shows preparing-swap', (tester) async {
      await expectLabel(tester, const PayProcessInitial(), S.current.payPreparingSwap);
    });

    testWidgets('preparing-swap label', (tester) async {
      await expectLabel(tester, const PayProcessPreparingSwap(), S.current.payPreparingSwap);
    });

    testWidgets('waiting-for-eth label', (tester) async {
      await expectLabel(tester, const PayProcessWaitingForEth(), S.current.payWaitingForEth);
    });

    testWidgets('swapping label', (tester) async {
      await expectLabel(tester, const PayProcessSwapping(), S.current.paySwapping);
    });

    testWidgets('refreshing-quote label', (tester) async {
      await expectLabel(tester, const PayProcessRefreshingQuote(), S.current.payRefreshingQuote);
    });

    testWidgets('paying label', (tester) async {
      await expectLabel(tester, const PayProcessPaying(), S.current.payPaying);
    });

    testWidgets('awaiting-settlement label', (tester) async {
      await expectLabel(
        tester,
        const PayProcessAwaitingSettlement('0xtx'),
        S.current.payAwaitingSettlement,
      );
    });

    testWidgets('success label', (tester) async {
      await expectLabel(
        tester,
        const PayProcessSuccess(txHash: '0xpay', shareAmount: 2),
        S.current.paySuccess,
      );
    });

    testWidgets('failure hides spinner and outcome title', (tester) async {
      when(() => processCubit.state).thenReturn(
        const PayProcessFailure(PayProcessFailureReason.generic),
      );
      await tester.pumpApp(buildSubject());

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.text(S.current.payFailureTitle), findsNothing);
    });

    testWidgets('a wallet without pay does not use the failure title', (tester) async {
      await expectLabel(tester, const PayProcessNotOffered(), S.current.payPreparingSwap);
      expect(find.text(S.current.payFailureTitle), findsNothing);
      expect(find.text(S.current.payFailurePayUnavailable), findsNothing);
    });
  });

  // The result sheets are modal bottom sheets shown from the listener.
  // Pump fixed frames to open the sheet.
  // A phone-sized surface keeps the sheet inside the test viewport
  // (mirrors the logout-sheet test convention).
  Future<void> pumpWithState(WidgetTester tester, PayProcessState terminal) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    whenListen(
      processCubit,
      Stream<PayProcessState>.fromIterable([terminal]),
      initialState: const PayProcessSwapping(),
    );
    await tester.pumpApp(buildSubject());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Pushes [PayProcessView] onto a navigator so the `push<bool>` result can
  /// be captured. Phone-sized surface matches [pumpWithState] so result sheets
  /// fit the hit box.
  Future<void> pumpPushedView(
    WidgetTester tester, {
    required void Function(bool? result) onPopped,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => BlocProvider<PayProcessCubit>.value(
                      value: processCubit,
                      child: const PayProcessView(),
                    ),
                  ),
                );
                onPopped(result);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpPushedWithState(
    WidgetTester tester,
    PayProcessState terminal, {
    required void Function(bool? result) onPopped,
  }) async {
    whenListen(
      processCubit,
      Stream<PayProcessState>.fromIterable([terminal]),
      initialState: const PayProcessSwapping(),
    );
    await pumpPushedView(tester, onPopped: onPopped);
    // Incoming route animation + sheet open (same extra pumps as the
    // TimedMaterialPageRoute page test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('$PayProcessView result sheet', () {
    testWidgets('success pops PayProcessCompleted from the resolver', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tx = Transaction(
        height: 0,
        txId: '0xpay',
        chainId: realUnitAsset.chainId,
        senderAddress: '0xwallet',
        receiverAddress: kReferralPayoutSenderAddress,
        amount: BigInt.from(2),
        asset: realUnitAsset,
        type: TransactionTypes.tokenTransfer,
        category: TransferCategory.payment,
        note: '',
        data: null,
        timestamp: DateTime.utc(2026, 10, 8),
      );
      Object? popped;
      CompletedTransactionRequest? requested;
      whenListen(
        processCubit,
        Stream<PayProcessState>.fromIterable([
          const PayProcessSuccess(txHash: '0xpay', shareAmount: 2),
        ]),
        initialState: const PayProcessSwapping(),
      );
      await tester.pumpApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Object>(
                    MaterialPageRoute<Object>(
                      builder: (_) => BlocProvider<PayProcessCubit>.value(
                        value: processCubit,
                        child: PayProcessView(
                          resolveCompleted: (request) async {
                            requested = request;
                            return CompletedTransaction(
                              transaction: tx,
                              walletAddress: '0xwallet',
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(popped, isA<PayProcessCompleted>());
      final completed = popped! as PayProcessCompleted;
      expect(completed.transaction, same(tx));
      expect(requested?.txHash, '0xpay');
      expect(requested?.category, TransferCategory.payment);
      expect(completed.walletAddress, '0xwallet');
    });

    testWidgets('generic failure message', (tester) async {
      await pumpWithState(
        tester,
        const PayProcessFailure(PayProcessFailureReason.generic),
      );

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.text(S.current.payFailureTitle), findsOne);
      expect(find.text(S.current.payFailureGeneric), findsOne);
    });

    testWidgets('generic failure with API message shows the API text 1:1', (tester) async {
      await pumpWithState(
        tester,
        const PayProcessFailure(
          PayProcessFailureReason.generic,
          message: 'Price source is temporarily unavailable',
        ),
      );

      expect(find.text('Price source is temporarily unavailable'), findsOne);
      expect(find.text(S.current.payFailureGeneric), findsNothing);
    });
  });

  group('$PayProcessView wallet without pay', () {
    testWidgets('leaves without a failure sheet', (tester) async {
      bool? popped = false;
      var didPop = false;
      await pumpPushedWithState(
        tester,
        const PayProcessNotOffered(),
        onPopped: (result) {
          didPop = true;
          popped = result;
        },
      );

      expect(find.text(S.current.payFailureTitle, skipOffstage: false), findsNothing);
      expect(find.text(S.current.payFailurePayUnavailable, skipOffstage: false), findsNothing);
      expect(find.byIcon(Icons.error_rounded), findsNothing);
      expect(find.byType(PayProcessView), findsNothing);
      expect(didPop, isTrue);
      expect(popped, isNull);
    });
  });

  group('$PayProcessView swapCompleted pop', () {
    testWidgets('failure sheet after a completed swap pops the process route with true', (
      tester,
    ) async {
      when(() => processCubit.swapCompleted).thenReturn(true);

      bool? popped;
      await pumpPushedWithState(
        tester,
        const PayProcessFailure(PayProcessFailureReason.generic),
        onPopped: (result) => popped = result,
      );

      expect(find.text(S.current.close), findsOne);
      // pumpPushedWithState nests an extra navigator; Close lands off-screen.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop(); // dismiss the sheet
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PayProcessView), findsNothing);
      expect(popped, isTrue);
    });

    testWidgets('failure sheet before a swap pops the process route with false', (tester) async {
      bool? popped;
      await pumpPushedWithState(
        tester,
        const PayProcessFailure(PayProcessFailureReason.generic),
        onPopped: (result) => popped = result,
      );

      expect(find.text(S.current.close), findsOne);
      // pumpPushedWithState nests an extra navigator; Close lands off-screen.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop(); // dismiss the sheet
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PayProcessView), findsNothing);
      expect(popped, isFalse);
    });
  });
}
