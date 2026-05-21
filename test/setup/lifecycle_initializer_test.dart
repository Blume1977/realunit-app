import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/balance_service.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/screens/pin/bloc/auth/pin_auth_cubit.dart';
import 'package:realunit_wallet/setup/lifecycle_initializer.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockBalanceService extends Mock implements BalanceService {}

class _MockPinAuthCubit extends Mock implements PinAuthCubit {}

class _MockWalletService extends Mock implements WalletService {}

void main() {
  late _MockAppStore appStore;
  late _MockBalanceService balanceService;
  late _MockPinAuthCubit pinAuthCubit;
  late _MockWalletService walletService;

  setUp(() {
    appStore = _MockAppStore();
    balanceService = _MockBalanceService();
    pinAuthCubit = _MockPinAuthCubit();
    walletService = _MockWalletService();

    final getIt = GetIt.instance;
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<BalanceService>(balanceService);
    getIt.registerSingleton<PinAuthCubit>(pinAuthCubit);
    getIt.registerSingleton<WalletService>(walletService);

    when(() => walletService.lockCurrentWallet()).thenAnswer((_) async {});
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pumpLifecycle(WidgetTester tester) =>
      tester.pumpWidget(
        const LifecycleInitializer(
          child: SizedBox.shrink(),
        ),
      );

  testWidgets(
    'AppLifecycleState.hidden drops the mnemonic via WalletService.lockCurrentWallet',
    (tester) async {
      await pumpLifecycle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      verify(() => walletService.lockCurrentWallet()).called(1);
    },
  );

  testWidgets(
    'AppLifecycleState.paused does NOT lock the wallet — already covered by hidden',
    (tester) async {
      await pumpLifecycle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verifyNever(() => walletService.lockCurrentWallet());
    },
  );

  testWidgets(
    'AppLifecycleState.resumed does NOT call lockCurrentWallet',
    (tester) async {
      when(() => appStore.primaryAddress).thenReturn('0xabc');
      when(() => balanceService.updateBalance(any())).thenAnswer((_) async {});
      when(() => pinAuthCubit.onAppResumed()).thenAnswer((_) {});

      await pumpLifecycle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verifyNever(() => walletService.lockCurrentWallet());
    },
  );

  // The unawaited lock call must not turn a backgrounding-during-onboarding
  // into an unhandled async error: AppStore.wallet throws "No Wallet set"
  // before HomeBloc populates it, and Future errors that escape the lifecycle
  // hook would surface in Zone.handleUncaughtError.
  testWidgets(
    'AppLifecycleState.hidden swallows the no-wallet-set Exception',
    (tester) async {
      when(() => walletService.lockCurrentWallet())
          .thenThrow(Exception('No Wallet set'));

      await pumpLifecycle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      // Pump twice — once for the listener's synchronous dispatch, once for
      // the microtask the unawaited Future scheduled. If the error were
      // unhandled, tester.takeException() would expose it.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(() => walletService.lockCurrentWallet()).called(1);
    },
  );
}
