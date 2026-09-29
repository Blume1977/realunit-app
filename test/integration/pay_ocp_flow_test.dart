// Cross-layer integration tests for the OpenCryptoPay pay flow.
//
// These tests stitch together the layers that a 1 EUR / 0.95 ZCHF merchant
// bill touches end-to-end. That bill is the original screenshot bug (quote
// showed 0 REALU sold vs ~0.95 ZCHF needed, Pay disabled) and the leftover
// sweep (the pay unsigned-tx `amountWei` is the full ZCHF balance, not the
// 0.95 quote):
//
//   PayQuoteCubit / PayProcessCubit
//     → FakeBitboxCredentials.signToSignature (BitBox boundary, no real
//       BLE/USB stack)
//     → RealUnitPayService (real production class)
//     → MockClient (last-mile HTTP boundary stand-in)
//
// We deliberately wire up the real RealUnitPayService instead of stubbing
// it — the goal is to pin the contract between the cubits and the service
// AND the wire-format the service produces. The MockClient plays the fixed
// API: PUT /v1/realunit/swap with targetAmount 0.95 returns amount: 1,
// isValid: true. The app does not ceil shares locally; Ready displays the
// JSON `amount`. PayProcessCubit signs that confirmed quote (id 99) and
// does not request a second swap.
//
// They run headless (no device, no simulator, no live merchant QR), so they
// live under `test/integration/` and run as part of `flutter test`.

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web3dart/web3dart.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/cache_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/api_client.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/service/session_cache.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/packages/wallet/wallet_account.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_process/pay_process_cubit.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_quote/pay_quote_cubit.dart';

import '../helper/fake_bitbox_credentials.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock implements AWallet {}

class _MockWalletAccount extends Mock implements AWalletAccount {}

class _MockWalletService extends Mock implements WalletService {}

class _MockCacheRepository extends Mock implements CacheRepository {}

const _paymentLinkId = 'pl_realunit_ocp_1eur';
const _lnurlpPath = '/v1/lnurlp/pl_realunit_ocp_1eur';
const _swapPath = '/v1/realunit/swap';
const _payConfirmPath = '/v1/realunit/pay/99/confirm';
const _payStatusPath = '/v1/realunit/pay/pl_realunit_ocp_1eur/status';

const _testPrivateKeyHex =
    'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';
final _softwareKey = EthPrivateKey.fromHex(_testPrivateKeyHex);

Map<String, dynamic> _delegationJson() => {
  'relayerAddress': '0x1111111111111111111111111111111111111111',
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
    'Delegation': <Map<String, dynamic>>[],
    'Caveat': <Map<String, dynamic>>[],
  },
  'message': {
    'delegate': '0x1111111111111111111111111111111111111111',
    'delegator': _softwareKey.address.hexEip55.toLowerCase(),
    'authority':
        '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'caveats': <dynamic>[],
    'salt': 1,
  },
  'tokenAddress': '0x553C7f9C780316FC1D34b8e14ac2465Ab22a090B',
  'amountWei': '1',
  'depositAddress': '',
};

Map<String, dynamic> _lnurlpJson() => {
  'requestedAmount': {'asset': 'EUR', 'amount': 1},
  'quote': {
    'id': 'plq_1eur',
    'expiration': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
  },
  'transferAmounts': [
    {
      'method': 'Ethereum',
      'assets': [
        {'asset': 'ZCHF', 'amount': 0.95},
      ],
    },
  ],
};

Map<String, dynamic> _swapInfoJson({
  required num amount,
  required bool isValid,
  String? error,
}) => {
  'id': 99,
  'uid': 'MOCK-UID',
  'routeId': 7,
  'timestamp': '2026-06-03T00:00:00.000Z',
  'amount': amount,
  'estimatedAmount': 1.05,
  'targetAsset': 'ZCHF',
  'minVolume': 1,
  'maxVolume': 1000,
  'minVolumeTarget': 95,
  'maxVolumeTarget': 95000,
  'ethBalance': 1.0,
  'requiredGasEth': 0.001,
  'isValid': isValid,
  if (error != null) 'error': error,
  if (isValid) 'ethereumTransactionFeeChf': 0.05,
  if (isValid) 'ethereumTransactionFeeRealu': 0.01234567,
};

void main() {
  late _MockAppStore appStore;
  late _MockWallet wallet;
  late _MockWalletAccount account;
  late _MockWalletService walletService;
  late SessionCache session;
  late FakeBitboxCredentials creds;

  setUp(() {
    appStore = _MockAppStore();
    wallet = _MockWallet();
    account = _MockWalletAccount();
    walletService = _MockWalletService();
    session = SessionCache(_MockCacheRepository());
    // Pre-seed an auth token so the service skips its sign-message round-trip.
    session.setAuthToken('jwt-test');

    creds = FakeBitboxCredentials(signDelay: Duration.zero);

    when(() => appStore.wallet).thenReturn(wallet);
    when(
      () => appStore.apiConfig,
    ).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    when(() => appStore.sessionCache).thenReturn(session);
    when(() => appStore.primaryAddress).thenReturn(creds.address.hexEip55);
    when(() => wallet.walletType).thenReturn(WalletType.bitbox);
    when(() => wallet.currentAccount).thenReturn(account);
    when(() => account.primaryAddress).thenReturn(creds);
    when(
      () => walletService.ensureCurrentWalletUnlocked(),
    ).thenAnswer((_) async {});
    when(() => walletService.lockCurrentWallet()).thenAnswer((_) async {});
  });

  // Build a real [RealUnitPayService] backed by [client]. The cubits talk to
  // this service object — there is no service-level stub between the cubit
  // and the HTTP boundary.
  RealUnitPayService buildPayService(http.Client client) {
    when(() => appStore.httpClient).thenReturn(RealUnitApiClient(client));
    return RealUnitPayService(appStore, walletService);
  }

  group(
    'pay OCP flow cross-layer: cubit → BitBox boundary → service → MockClient',
    () {
      test(
        '1 EUR / 0.95 ZCHF quote with a 1-share swap preview becomes PayQuoteReady',
        () async {
          // Original screenshot bug: 0 REALU sold / grey Pay. The MockClient
          // plays the fixed API (targetAmount 0.95 → amount: 1, isValid: true).
          // Ready with 1 share is the fix — the harness does not ceil locally.
          Map<String, dynamic>? swapBody;
          final client = MockClient((request) async {
            if (request.method == 'GET' && request.url.path == _lnurlpPath) {
              return http.Response(jsonEncode(_lnurlpJson()), 200);
            }
            if (request.method == 'PUT' && request.url.path == _swapPath) {
              swapBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode(_swapInfoJson(amount: 1, isValid: true)),
                200,
              );
            }
            fail('unexpected ${request.method} ${request.url.path}');
          });

          final cubit = PayQuoteCubit(buildPayService(client), _paymentLinkId);
          await cubit.load();

          expect(cubit.state, isA<PayQuoteReady>());
          final state = cubit.state as PayQuoteReady;
          expect(state.fiatAsset, 'EUR');
          expect(state.fiatAmount, 1);
          expect(state.zchfAmount, 0.95);
          expect(state.swap.amount, 1);
          expect(state.swap.estimatedAmount, 1.05);
          expect(state.swap.id, 99);
          expect(state.swap.ethereumTransactionFeeChf, 0.05);
          expect(state.swap.ethereumTransactionFeeRealu, 0.01234567);

          expect(swapBody, isNotNull);
          expect(swapBody!['targetAmount'], 0.95);
          expect(swapBody!.containsKey('amount'), isFalse);

          await cubit.close();
        },
      );

      test('invalid 0-share swap preview is PayQuoteError, never Ready', () async {
        // Same lnurlp bill; the API returns amount: 0 / isValid: false. The app
        // surfaces AmountTooLow 1:1 and does not invent a 1-share Ready state.
        final client = MockClient((request) async {
          if (request.method == 'GET' && request.url.path == _lnurlpPath) {
            return http.Response(jsonEncode(_lnurlpJson()), 200);
          }
          if (request.method == 'PUT' && request.url.path == _swapPath) {
            return http.Response(
              jsonEncode(
                _swapInfoJson(amount: 0, isValid: false, error: 'AmountTooLow'),
              ),
              200,
            );
          }
          fail('unexpected ${request.method} ${request.url.path}');
        });

        final cubit = PayQuoteCubit(buildPayService(client), _paymentLinkId);
        await cubit.load();

        expect(cubit.state, isA<PayQuoteError>());
        expect(cubit.state, isNot(isA<PayQuoteReady>()));
        expect((cubit.state as PayQuoteError).message, 'AmountTooLow');

        await cubit.close();
      });

      test('BitBox pay never calls the API', () async {
        when(() => wallet.walletType).thenReturn(WalletType.bitbox);
        final client = MockClient((request) async {
          fail('unexpected ${request.method} ${request.url.path}');
        });
        final cubit = PayProcessCubit(
          payService: buildPayService(client),
          appStore: appStore,
          paymentLinkId: _paymentLinkId,
          quoteId: 'plq_1eur',
          swap: SwapPaymentInfo(
            id: 99,
            amount: 1,
            estimatedAmount: 1.05,
            targetAsset: 'ZCHF',
            ethBalance: 0,
            requiredGasEth: 0.01,
            isValid: true,
            eip7702: Eip7702Data.fromJson(_delegationJson()),
          ),
        );

        await cubit.start();

        expect(
          (cubit.state as PayProcessFailure).reason,
          PayProcessFailureReason.payUnavailable,
        );
        expect(cubit.swapCompleted, isFalse);
        await cubit.close();
      });

      test(
        'software wallet confirms through the sell relayer and never funds ETH',
        () {
          fakeAsync((async) {
            void drain() {
              for (var i = 0; i < 40; i++) {
                async.flushMicrotasks();
                async.elapse(Duration.zero);
              }
            }

            Map<String, dynamic>? confirmBody;
            final client = MockClient((request) async {
              final path = request.url.path;
              if (request.method == 'PUT' && path == _payConfirmPath) {
                confirmBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(jsonEncode({'txHash': '0xrelayed'}), 200);
              }
              if (request.method == 'GET' && path == _payStatusPath) {
                return http.Response(jsonEncode({'status': 'Completed'}), 200);
              }
              fail('unexpected ${request.method} ${request.url.path}');
            });

            when(() => wallet.walletType).thenReturn(WalletType.software);
            when(() => account.primaryAddress).thenReturn(_softwareKey);
            when(
              () => appStore.apiConfig,
            ).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
            final cubit = PayProcessCubit(
              payService: buildPayService(client),
              appStore: appStore,
              paymentLinkId: _paymentLinkId,
              quoteId: 'plq_1eur',
              swap: SwapPaymentInfo(
                id: 99,
                amount: 1,
                estimatedAmount: 1.05,
                targetAsset: 'ZCHF',
                ethBalance: 0,
                requiredGasEth: 0.01,
                isValid: true,
                eip7702: Eip7702Data.fromJson(_delegationJson()),
              ),
            );
            cubit.start();
            drain();

            expect(cubit.state, isA<PayProcessAwaitingSettlement>());
            expect(confirmBody, isNotNull);
            expect(confirmBody!['paymentLinkId'], _paymentLinkId);
            expect(confirmBody!['quoteId'], 'plq_1eur');
            expect(confirmBody!.containsKey('txHash'), isFalse);
            final delegation =
                (confirmBody!['eip7702'] as Map<String, dynamic>)['delegation']
                    as Map<String, dynamic>;
            expect(
              delegation['delegate'],
              '0x1111111111111111111111111111111111111111',
            );
            expect(delegation['signature'], isNotEmpty);

            async.elapse(const Duration(seconds: 3));
            drain();
            expect(
              cubit.state,
              anyOf(
                isA<PayProcessSuccess>(),
                isA<PayProcessAwaitingSettlement>(),
              ),
            );

            cubit.close();
            async.flushTimers();
          });
        },
      );
    },
  );
}
