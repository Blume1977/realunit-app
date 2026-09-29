import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/sell_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_status_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_process/pay_process_cubit.dart';

class _MockPayService extends Mock implements RealUnitPayService {}

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock implements AWallet {}

Eip7702Data _delegation() => Eip7702Data.fromJson({
  'relayerAddress': '0xrelay',
  'delegationManagerAddress': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  'delegatorAddress': '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b',
  'userNonce': 1,
  'domain': {
    'name': 'DelegationManager',
    'version': '1',
    'chainId': 1,
    'verifyingContract': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  },
  'types': {
    'Delegation': [
      {'name': 'delegate', 'type': 'address'},
    ],
    'Caveat': [
      {'name': 'enforcer', 'type': 'address'},
    ],
  },
  'message': {
    'delegate': '0xrelay',
    'delegator': '0x1111111111111111111111111111111111111111',
    'authority': '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'caveats': <dynamic>[],
    'salt': 1,
  },
  'tokenAddress': '0x553C7f9C780316FC1D34b8e14ac2465Ab22a090B',
  'amountWei': '2',
  'depositAddress': '',
});

SwapPaymentInfo _swap({
  bool isValid = true,
  String? error,
  bool withDelegation = true,
}) => SwapPaymentInfo(
  id: 99,
  amount: 2,
  estimatedAmount: 2.4,
  targetAsset: 'ZCHF',
  ethBalance: 0,
  requiredGasEth: 0.01,
  isValid: isValid,
  error: error,
  eip7702: withDelegation ? _delegation() : null,
);

void main() {
  late _MockPayService payService;
  late _MockAppStore appStore;
  late _MockWallet wallet;

  setUpAll(() {
    registerFallbackValue(_swap());
  });

  setUp(() {
    payService = _MockPayService();
    appStore = _MockAppStore();
    wallet = _MockWallet();

    when(
      () => appStore.apiConfig,
    ).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => wallet.walletType).thenReturn(WalletType.software);
    when(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    ).thenAnswer((_) async => '0xpay');
    when(() => payService.getPayStatus(any())).thenAnswer(
      (_) async => const RealUnitOcpPayStatusDto(status: OcpPaymentStatus.completed),
    );
  });

  PayProcessCubit build({SwapPaymentInfo? swap}) => PayProcessCubit(
    payService: payService,
    appStore: appStore,
    paymentLinkId: 'pl_abc',
    quoteId: 'quote_xyz',
    swap: swap ?? _swap(),
  );

  test('debug wallet fails before any confirm', () async {
    when(() => wallet.walletType).thenReturn(WalletType.debug);

    final cubit = build();
    await cubit.start();

    expect(
      (cubit.state as PayProcessFailure).reason,
      PayProcessFailureReason.signatureUnsupported,
    );
    expect(cubit.swapCompleted, isFalse);
    verifyNever(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    );
    await cubit.close();
  });

  test('BitBox has no pay option and never asks the relayer', () async {
    when(() => wallet.walletType).thenReturn(WalletType.bitbox);

    final cubit = build();
    await cubit.start();

    expect(
      (cubit.state as PayProcessFailure).reason,
      PayProcessFailureReason.payUnavailable,
    );
    expect(cubit.swapCompleted, isFalse);
    verifyNever(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    );
    await cubit.close();
  });

  test('invalid quote is not confirmed', () async {
    final cubit = build(swap: _swap(isValid: false, error: 'AmountTooLow'));
    await cubit.start();

    final state = cubit.state as PayProcessFailure;
    expect(state.reason, PayProcessFailureReason.generic);
    expect(state.message, 'AmountTooLow');
    verifyNever(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    );
    await cubit.close();
  });

  test('a quote without a delegation is not confirmed', () async {
    final cubit = build(swap: _swap(withDelegation: false));
    await cubit.start();

    expect(
      (cubit.state as PayProcessFailure).reason,
      PayProcessFailureReason.generic,
    );
    verifyNever(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    );
    await cubit.close();
  });

  test(
    'software wallet confirms once through the sell relayer and then polls',
    () {
      fakeAsync((async) {
        final cubit = build();
        cubit.start();
        async.flushMicrotasks();

        expect(cubit.state, isA<PayProcessAwaitingSettlement>());
        expect((cubit.state as PayProcessAwaitingSettlement).txId, '0xpay');
        expect(cubit.swapCompleted, isTrue);
        verify(
          () => payService.confirmOcpPay(
            swap: any(named: 'swap'),
            paymentLinkId: 'pl_abc',
            quoteId: 'quote_xyz',
          ),
        ).called(1);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(cubit.state, isA<PayProcessSuccess>());

        cubit.close();
        async.flushTimers();
      });
    },
  );

  test('a rejected confirm leaves the quote retryable', () async {
    when(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    ).thenThrow(
      const PayConfirmNotSubmittedException(
        'payout short',
        apiMessage: 'payout short',
      ),
    );

    final cubit = build();
    await cubit.start();

    final state = cubit.state as PayProcessFailure;
    expect(state.message, 'payout short');
    expect(cubit.swapCompleted, isFalse);
    await cubit.close();
  });

  test('a local confirm failure does not show an English sentence', () async {
    when(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    ).thenThrow(
      const PayConfirmNotSubmittedException(
        'Confirm did not return a transaction hash',
      ),
    );

    final cubit = build();
    await cubit.start();

    final state = cubit.state as PayProcessFailure;
    expect(state.reason, PayProcessFailureReason.generic);
    expect(state.message, isNull);
    expect(cubit.swapCompleted, isFalse);
    await cubit.close();
  });

  test('an already-confirmed sale polls instead of selling again', () {
    fakeAsync((async) {
      when(
        () => payService.confirmOcpPay(
          swap: any(named: 'swap'),
          paymentLinkId: any(named: 'paymentLinkId'),
          quoteId: any(named: 'quoteId'),
        ),
      ).thenThrow(
        const AlreadyConfirmedException(
          code: 'CONFLICT',
          message: 'already confirmed',
        ),
      );

      final cubit = build();
      cubit.start();
      async.flushMicrotasks();

      expect(cubit.state, isA<PayProcessAwaitingSettlement>());
      expect(cubit.swapCompleted, isTrue);
      verify(
        () => payService.confirmOcpPay(
          swap: any(named: 'swap'),
          paymentLinkId: any(named: 'paymentLinkId'),
          quoteId: any(named: 'quoteId'),
        ),
      ).called(1);

      cubit.close();
      async.flushTimers();
    });
  });

  test(
    'a dropped confirm is retried without treating the quote as unused',
    () async {
      var calls = 0;
      when(
        () => payService.confirmOcpPay(
          swap: any(named: 'swap'),
          paymentLinkId: any(named: 'paymentLinkId'),
          quoteId: any(named: 'quoteId'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException(code: 'NETWORK', message: 'timeout');
        }
        return '0xpay';
      });

      final cubit = build();
      await cubit.start();

      expect(cubit.state, isA<PayProcessPayRetry>());
      expect(cubit.swapCompleted, isTrue);

      await cubit.retryPay();
      expect(cubit.state, isA<PayProcessAwaitingSettlement>());
      expect(calls, 2);
      await cubit.close();
    },
  );

  test('retry does nothing before a confirm has been attempted', () async {
    final cubit = build();
    await cubit.retryPay();

    expect(cubit.state, isA<PayProcessInitial>());
    verifyNever(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    );
    await cubit.close();
  });

  test('a terminal unpaid status offers retry and does not confirm again', () {
    fakeAsync((async) {
      when(() => payService.getPayStatus(any())).thenAnswer(
        (_) async => const RealUnitOcpPayStatusDto(status: OcpPaymentStatus.expired),
      );

      final cubit = build();
      cubit.start();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(cubit.state, isA<PayProcessPayRetry>());
      verify(
        () => payService.confirmOcpPay(
          swap: any(named: 'swap'),
          paymentLinkId: any(named: 'paymentLinkId'),
          quoteId: any(named: 'quoteId'),
        ),
      ).called(1);

      cubit.close();
      async.flushTimers();
    });
  });

  test('a confirm that already left keeps the API message on retry', () async {
    var calls = 0;
    when(
      () => payService.confirmOcpPay(
        swap: any(named: 'swap'),
        paymentLinkId: any(named: 'paymentLinkId'),
        quoteId: any(named: 'quoteId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const ApiException(code: 'NETWORK', message: 'timeout');
      }
      throw const PayConfirmNotSubmittedException(
        'payout short',
        apiMessage: 'payout short',
      );
    });

    final cubit = build();
    await cubit.start();
    await cubit.retryPay();

    final state = cubit.state as PayProcessPayRetry;
    expect(state.message, 'payout short');
    await cubit.close();
  });

  test('polling gives up while the payment stays pending', () {
    fakeAsync((async) {
      when(() => payService.getPayStatus(any())).thenAnswer(
        (_) async => const RealUnitOcpPayStatusDto(status: OcpPaymentStatus.pending),
      );

      final cubit = build();
      cubit.start();
      async.flushMicrotasks();
      for (var i = 0; i < 40; i++) {
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
      }

      expect(cubit.state, isA<PayProcessPayRetry>());
      cubit.close();
      async.flushTimers();
    });
  });

  test('polling gives up when status keeps failing', () {
    fakeAsync((async) {
      when(
        () => payService.getPayStatus(any()),
      ).thenThrow(Exception('status down'));

      final cubit = build();
      cubit.start();
      async.flushMicrotasks();
      for (var i = 0; i < 40; i++) {
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
      }

      expect(cubit.state, isA<PayProcessPayRetry>());
      cubit.close();
      async.flushTimers();
    });
  });
}
