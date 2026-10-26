import 'dart:convert';
import 'dart:io';

import 'package:eip7702/eip7702.dart' as eip7702;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/cache_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/api_client.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/transfer/dto/real_unit_transfer_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_sell_payment_info_service.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_transfer_service.dart';
import 'package:realunit_wallet/packages/service/session_cache.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/wallet/delegation_signer.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/packages/wallet/wallet_account.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:web3dart/web3dart.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock implements AWallet {}

class _MockAccount extends Mock implements AWalletAccount {}

class _MockCacheRepository extends Mock implements CacheRepository {}

class _MockWalletService extends Mock implements WalletService {}

/// Signs like the production signer and counts each signature.
class _SpySigner extends DelegationSigner {
  int delegationCalls = 0;
  int authorizationCalls = 0;

  @override
  Future<String> signDelegation({
    required CredentialsWithKnownAddress credentials,
    required Eip7702Data eip7702Data,
  }) {
    delegationCalls++;
    return super.signDelegation(credentials: credentials, eip7702Data: eip7702Data);
  }

  @override
  eip7702.EIP7702MsgSignature signAuthorization({
    required CredentialsWithKnownAddress credentials,
    required Eip7702Data eip7702Data,
  }) {
    authorizationCalls++;
    return super.signAuthorization(credentials: credentials, eip7702Data: eip7702Data);
  }
}

const _testPrivateKeyHex = 'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';
final _privKey = EthPrivateKey.fromHex(_testPrivateKeyHex);
final _walletAddress = _privKey.address.hexEip55.toLowerCase();

const _metaMaskDelegator = '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b';
const _delegationManager = '0xdb9b1e94b5b69df7e401ddbede43491141047db3';
const _relayerAddress = '0x1111111111111111111111111111111111111111';
const _realuToken = '0x553C7f9C780316FC1D34b8e14ac2465Ab22a090B';

// The delegation framework's root authority and its DelegationManager
// EIP-712 domain.
const _rootAuthority = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _domainName = 'DelegationManager';
const _domainVersion = '1';

const _transferRecipient = '0x2222222222222222222222222222222222222222';
const _transferAmount = 5;

final Map<String, dynamic> _caveatVectors = _loadCaveatVectors();

Map<String, dynamic> _loadCaveatVectors() {
  final decoded = jsonDecode(
    File('test/packages/service/dfx/delegation_caveat_vectors.json').readAsStringSync(),
  );
  if (decoded is! Map<String, dynamic>) {
    throw StateError('caveat vectors are not a JSON object');
  }
  return decoded;
}

String _caveatVector(String key) {
  final value = _caveatVectors[key];
  if (value is! String) {
    throw StateError('caveat vector $key is missing');
  }
  return value;
}

List<Map<String, dynamic>> _sellCaveats(String wrapperKey) => [
  {'enforcer': '0xE1302607a3251AF54c3a6e69318d6aa07F5eB46c', 'terms': _caveatVector(wrapperKey)},
  {'enforcer': '0x1046bb45C8d673d4ea75321280DB34899413c069', 'terms': _caveatVector('timestamp')},
];

List<Map<String, dynamic>> _transferCaveats() => [
  {
    'enforcer': '0x146713078D39eCC1F5338309c28405ccf85Abfbb',
    'terms': _caveatVector('transferAmount5Recipient2222'),
  },
  {'enforcer': '0x04658B29F6b82ed55274221a06Fc97D318E25416', 'terms': _caveatVector('limited')},
  {'enforcer': '0x1046bb45C8d673d4ea75321280DB34899413c069', 'terms': _caveatVector('timestamp')},
];

/// A delegation every check accepts today; [caveats] and [amountWei] pick the
/// flow it belongs to.
Map<String, dynamic> _delegationJson({
  required List<Map<String, dynamic>> caveats,
  required String amountWei,
}) => {
  'relayerAddress': _relayerAddress,
  'delegationManagerAddress': _delegationManager,
  'delegatorAddress': _metaMaskDelegator,
  'userNonce': 7,
  'domain': {
    'name': _domainName,
    'version': _domainVersion,
    'chainId': 1,
    'verifyingContract': _delegationManager,
  },
  'types': {
    'Delegation': <Map<String, dynamic>>[],
    'Caveat': <Map<String, dynamic>>[],
  },
  'message': {
    'delegate': _relayerAddress,
    'delegator': _walletAddress,
    'authority': _rootAuthority,
    'caveats': caveats,
    'salt': 0,
  },
  'tokenAddress': _realuToken,
  'amountWei': amountWei,
  'depositAddress': '',
};

typedef _Mutation = void Function(Map<String, dynamic> json);

void _setAuthority(Map<String, dynamic> json) =>
    (json['message'] as Map<String, dynamic>)['authority'] =
        '0x0000000000000000000000000000000000000000000000000000000000000001';

void _setDomainName(Map<String, dynamic> json) =>
    (json['domain'] as Map<String, dynamic>)['name'] = 'OtherManager';

void _setDomainVersion(Map<String, dynamic> json) =>
    (json['domain'] as Map<String, dynamic>)['version'] = '2';

void main() {
  late _MockAppStore appStore;
  late _MockWalletService walletService;
  late List<http.Request> requests;
  late _SpySigner signer;

  setUp(() {
    signer = _SpySigner();
    appStore = _MockAppStore();
    walletService = _MockWalletService();
    final wallet = _MockWallet();
    final account = _MockAccount();
    final session = SessionCache(_MockCacheRepository())..setAuthToken('jwt-1');
    requests = [];

    when(() => appStore.apiConfig).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    when(() => appStore.sessionCache).thenReturn(session);
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => wallet.currentAccount).thenReturn(account);
    when(() => account.primaryAddress).thenReturn(_privKey);
    when(() => appStore.httpClient).thenReturn(
      RealUnitApiClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'txHash': '0xconfirmed'}), 200);
        }),
      ),
    );
    when(() => walletService.ensureCurrentWalletUnlocked()).thenAnswer((_) async {});
    when(() => walletService.lockCurrentWallet()).thenAnswer((_) async {});
  });

  /// Defines the control case and one rejection case per mutation for a flow.
  void delegationGuardCases(
    String flow,
    Future<void> Function(_Mutation? mutate) confirm,
  ) {
    group('$flow delegation', () {
      test('signs and sends the confirm for a delegation with the expected envelope', () async {
        await confirm(null);

        expect(requests, hasLength(1));
        expect(signer.delegationCalls, 1);
        expect(signer.authorizationCalls, 1);
      });

      Future<void> expectRefused(_Mutation mutate) async {
        Object? error;
        try {
          await confirm(mutate);
        } catch (e) {
          error = e;
        }
        expect(signer.delegationCalls, 0, reason: 'expected no delegation signature');
        expect(signer.authorizationCalls, 0, reason: 'expected no authorization signature');
        expect(requests, isEmpty, reason: 'expected no confirm request');
        expect(error, isA<Exception>(), reason: 'expected the confirm to throw');
      }

      test('refuses an authority other than the root authority', () async {
        await expectRefused(_setAuthority);
      });

      test('refuses an EIP-712 domain name other than $_domainName', () async {
        await expectRefused(_setDomainName);
      });

      test('refuses an EIP-712 domain version other than $_domainVersion', () async {
        await expectRefused(_setDomainVersion);
      });
    });
  }

  delegationGuardCases('sell', (mutate) {
    final json = _delegationJson(caveats: _sellCaveats('sellWrapperAmount100'), amountWei: '100');
    mutate?.call(json);
    return RealUnitSellPaymentInfoService(appStore, walletService, signer: signer).confirmPayment(
      SellPaymentInfo(
        id: 42,
        eip7702: Eip7702Data.fromJson(json),
        amount: 100,
        exchangeRate: 1.0,
        rate: 1.0,
        beneficiary: const BeneficiaryDto(iban: 'CH...'),
        estimatedAmount: 100.0,
        currency: Currency.chf,
        depositAddress: '0xdeposit',
        tokenAddress: _realuToken,
        chainId: 1,
        ethBalance: 0.1,
        requiredGasEth: 0.001,
      ),
    );
  });

  delegationGuardCases('pay', (mutate) {
    final json = _delegationJson(caveats: _sellCaveats('sellWrapperAmount2'), amountWei: '2');
    mutate?.call(json);
    return RealUnitPayService(appStore, walletService, signer: signer).confirmOcpPay(
      swap: SwapPaymentInfo(
        id: 99,
        amount: 2,
        estimatedAmount: 2.4,
        targetAsset: 'ZCHF',
        ethBalance: 0,
        requiredGasEth: 0.01,
        isValid: true,
        eip7702: Eip7702Data.fromJson(json),
      ),
      paymentLinkId: 'pl_abc',
      quoteId: 'quote_xyz',
    );
  });

  delegationGuardCases('transfer', (mutate) {
    final json = _delegationJson(caveats: _transferCaveats(), amountWei: '$_transferAmount')
      ..['recipient'] = _transferRecipient;
    mutate?.call(json);
    return RealUnitTransferService(appStore, walletService, signer: signer).confirmTransfer(
      RealUnitTransferPaymentInfoDto.fromJson({
        'id': 42,
        'uid': 'RTabc',
        'toAddress': _transferRecipient,
        'amount': _transferAmount,
        'networkFeeRealu': 1,
        'tokenAddress': _realuToken,
        'chainId': 1,
        'eip7702': json,
      }),
      confirmedRecipient: _transferRecipient,
      confirmedAmount: _transferAmount,
    );
  });
}
