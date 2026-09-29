import 'dart:convert';

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
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/sell_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/service/session_cache.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/packages/wallet/wallet_account.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock implements AWallet {}

class _MockAccount extends Mock implements AWalletAccount {}

class _MockCacheRepository extends Mock implements CacheRepository {}

class _MockWalletService extends Mock implements WalletService {}

const _testPrivateKeyHex = 'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';
final _privKey = EthPrivateKey.fromHex(_testPrivateKeyHex);

Map<String, dynamic> _delegationJson({
  String? delegator,
  int chainId = 1,
  String amountWei = '2',
}) => {
  'relayerAddress': '0x1111111111111111111111111111111111111111',
  'delegationManagerAddress': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  'delegatorAddress': '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b',
  'userNonce': 1,
  'domain': {
    'name': 'DelegationManager',
    'version': '1',
    'chainId': chainId,
    'verifyingContract': '0xdb9b1e94b5b69df7e401ddbede43491141047db3',
  },
  'types': {
    'Delegation': <Map<String, dynamic>>[],
    'Caveat': <Map<String, dynamic>>[],
  },
  'message': {
    'delegate': '0x1111111111111111111111111111111111111111',
    'delegator': delegator ?? _privKey.address.hexEip55.toLowerCase(),
    'authority': '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'caveats': <dynamic>[],
    'salt': 1,
  },
  'tokenAddress': '0x553C7f9C780316FC1D34b8e14ac2465Ab22a090B',
  'amountWei': amountWei,
  'depositAddress': '',
};

SwapPaymentInfo _swap({Eip7702Data? eip7702, double amount = 2}) => SwapPaymentInfo(
  id: 99,
  amount: amount,
  estimatedAmount: 2.4,
  targetAsset: 'ZCHF',
  ethBalance: 0,
  requiredGasEth: 0.01,
  isValid: true,
  eip7702: eip7702,
);

void main() {
  late _MockAppStore appStore;
  late _MockWallet wallet;
  late _MockAccount account;
  late _MockWalletService walletService;
  late SessionCache session;

  setUp(() {
    appStore = _MockAppStore();
    wallet = _MockWallet();
    account = _MockAccount();
    walletService = _MockWalletService();
    session = SessionCache(_MockCacheRepository());
    session.setAuthToken('jwt-1');

    when(
      () => appStore.apiConfig,
    ).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    when(() => appStore.sessionCache).thenReturn(session);
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => wallet.currentAccount).thenReturn(account);
    when(() => account.primaryAddress).thenReturn(_privKey);
    when(
      () => walletService.ensureCurrentWalletUnlocked(),
    ).thenAnswer((_) async {});
    when(() => walletService.lockCurrentWallet()).thenAnswer((_) async {});
  });

  RealUnitPayService build(http.Client client) {
    when(() => appStore.httpClient).thenReturn(RealUnitApiClient(client));
    return RealUnitPayService(appStore, walletService);
  }

  Future<String> confirm(RealUnitPayService service) => service.confirmOcpPay(
    swap: _swap(eip7702: Eip7702Data.fromJson(_delegationJson())),
    paymentLinkId: 'pl_abc',
    quoteId: 'quote_xyz',
  );

  test('signs the delegation and posts the relayer confirm', () async {
    Map<String, dynamic>? body;
    String? path;
    final client = MockClient((request) async {
      path = request.url.path;
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'txHash': '0xrelayed'}), 200);
    });

    final txHash = await confirm(build(client));

    expect(txHash, '0xrelayed');
    expect(path, '/v1/realunit/pay/99/confirm');
    expect(body!['paymentLinkId'], 'pl_abc');
    expect(body!['quoteId'], 'quote_xyz');
    expect(body!.containsKey('txHash'), isFalse);
    final delegation =
        (body!['eip7702'] as Map<String, dynamic>)['delegation'] as Map<String, dynamic>;
    final authorization =
        (body!['eip7702'] as Map<String, dynamic>)['authorization'] as Map<String, dynamic>;
    expect(delegation['signature'], startsWith('0x'));
    expect(authorization['yParity'], isA<int>());
    verify(() => walletService.lockCurrentWallet()).called(1);
  });

  test('missing delegation never calls the network', () async {
    final client = MockClient((_) async => fail('network'));
    expect(
      () => build(client).confirmOcpPay(
        swap: _swap(),
        paymentLinkId: 'pl_abc',
        quoteId: 'quote_xyz',
      ),
      throwsA(isA<PayConfirmNotSubmittedException>()),
    );
    verifyNever(() => walletService.ensureCurrentWalletUnlocked());
  });

  test(
    'a delegation for another wallet is rejected before the request',
    () async {
      final client = MockClient((_) async => fail('network'));
      await expectLater(
        build(client).confirmOcpPay(
          swap: _swap(
            eip7702: Eip7702Data.fromJson(
              _delegationJson(
                delegator: '0x0000000000000000000000000000000000000002',
              ),
            ),
          ),
          paymentLinkId: 'pl_abc',
          quoteId: 'quote_xyz',
        ),
        throwsA(isA<PayConfirmNotSubmittedException>()),
      );
      verify(() => walletService.lockCurrentWallet()).called(1);
    },
  );

  test('a 400 from the relayer is not a submitted sale', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'statusCode': 400,
          'message': 'Brokerbot payout does not cover the payment',
        }),
        400,
      ),
    );
    await expectLater(
      confirm(build(client)),
      throwsA(
        isA<PayConfirmNotSubmittedException>()
            .having((e) => e.message, 'message', contains('does not cover'))
            .having(
              (e) => e.apiMessage,
              'apiMessage',
              contains('does not cover'),
            ),
      ),
    );
  });

  test('a signing failure is not a submitted sale', () async {
    when(() => wallet.currentAccount).thenThrow(Exception('locked'));
    final client = MockClient((_) async => fail('network'));

    await expectLater(
      confirm(build(client)),
      throwsA(isA<PayConfirmNotSubmittedException>()),
    );
  });

  test('a chain id that is not the RealUnit chain is rejected', () async {
    final client = MockClient((_) async => fail('network'));

    await expectLater(
      build(client).confirmOcpPay(
        swap: _swap(eip7702: Eip7702Data.fromJson(_delegationJson(chainId: 2))),
        paymentLinkId: 'pl_abc',
        quoteId: 'quote_xyz',
      ),
      throwsA(isA<PayConfirmNotSubmittedException>()),
    );
  });

  test('an amount that is not the quoted shares is rejected', () async {
    final client = MockClient((_) async => fail('network'));

    await expectLater(
      build(client).confirmOcpPay(
        swap: _swap(
          eip7702: Eip7702Data.fromJson(_delegationJson(amountWei: '1')),
        ),
        paymentLinkId: 'pl_abc',
        quoteId: 'quote_xyz',
      ),
      throwsA(isA<PayConfirmNotSubmittedException>()),
    );
  });

  test('a blank transaction hash is not a submitted sale', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'txHash': '   '}), 200),
    );
    await expectLater(
      confirm(build(client)),
      throwsA(
        isA<PayConfirmNotSubmittedException>().having(
          (e) => e.apiMessage,
          'apiMessage',
          isNull,
        ),
      ),
    );
  });

  test(
    'a 409 already confirmed is the sell replay, not a second sale',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'statusCode': 409,
            'message': 'Transaction request is already confirmed',
          }),
          409,
        ),
      );
      await expectLater(
        confirm(build(client)),
        throwsA(isA<AlreadyConfirmedException>()),
      );
    },
  );

  test('a 500 after the request left the device stays an API error', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'statusCode': 500, 'message': 'relayer down'}),
        500,
      ),
    );
    await expectLater(confirm(build(client)), throwsA(isA<ApiException>()));
  });
}
