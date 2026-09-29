import 'dart:convert';

import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_auth_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/sell_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/lnurlp_payment_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_result_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_status_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_submit_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_ocp_pay_unsigned_transaction_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_swap_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_swap_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/dto/real_unit_swap_unsigned_transaction_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_response_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_confirm_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/wallet/eip712_signer.dart';
import 'package:realunit_wallet/packages/wallet/eip7702_signer.dart';

/// Backend client for the Open CryptoPay pay flow (DFXswiss/api #3819, all under
/// `/v1/realunit/...`). Subclasses [DFXAuthService] for the JWT handshake +
/// retry-on-401 the sell flow already uses; the public lnurlp read is the only
/// unauthenticated call.
class RealUnitPayService extends DFXAuthService {
  static const _lnurlpPath = '/v1/lnurlp';
  static const _swapPath = '/v1/realunit/swap';
  static String _swapUnsignedTxPath(int id) => '/v1/realunit/swap/$id/unsigned-transaction';
  static String _swapBroadcastPath(int id) => '/v1/realunit/swap/$id/broadcast';
  static const _payUnsignedTxPath = '/v1/realunit/pay/unsigned-transaction';
  static const _paySubmitPath = '/v1/realunit/pay/submit';
  static String _payConfirmPath(int id) => '/v1/realunit/pay/$id/confirm';
  static String _payStatusPath(String id) => '/v1/realunit/pay/$id/status';

  // MetaMask Delegation Framework v1.3.0, CREATE2 — identical on all EVM chains.
  static const _metaMaskDelegatorAddress = '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b';
  static const _delegationManagerAddress = '0xdb9b1e94b5b69df7e401ddbede43491141047db3';

  static const _httpTimeout = Duration(seconds: 20);

  RealUnitPayService(super.appStore, super.walletService);

  /// Public OCP payment-link read (no auth). Returns the requested fiat amount,
  /// the active quote (id + expiration) and the per-method transfer amounts.
  Future<LnurlpPaymentDto> getPaymentDetails(String id) async {
    final uri = buildUri(host, '$_lnurlpPath/$id');
    final response = await appStore.httpClient
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(_httpTimeout);

    if (response.statusCode != 200) {
      _throwApi(response.body, response.statusCode);
    }
    return LnurlpPaymentDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // --- Swap (REALU → ZCHF, proceeds stay in the user wallet) ---

  Future<SwapPaymentInfo> getSwapPaymentInfo(RealUnitSwapDto dto) async {
    final uri = buildUri(host, _swapPath);
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    ).timeout(_httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    final responseDto = RealUnitSwapPaymentInfoDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return SwapPaymentInfo.fromDto(responseDto);
  }

  Future<RealUnitSwapUnsignedTransactionDto> createSwapUnsignedTransaction(
    int id,
  ) async {
    final uri = buildUri(host, _swapUnsignedTxPath(id));
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(_httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    return RealUnitSwapUnsignedTransactionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> broadcastSwapTransaction(
    int id,
    BroadcastTransactionRequestDto dto,
  ) async {
    final uri = buildUri(host, _swapBroadcastPath(id));
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    ).timeout(_httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    return BroadcastTransactionResponseDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    ).txHash;
  }

  // --- OCP pay (settle a ZCHF payment-link quote via the lnurlp flow) ---

  Future<RealUnitOcpPayUnsignedTransactionDto> createPayUnsignedTransaction(
    RealUnitOcpPayDto dto,
  ) async {
    final uri = buildUri(host, _payUnsignedTxPath);
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    ).timeout(_httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    return RealUnitOcpPayUnsignedTransactionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> submitPay(RealUnitOcpPaySubmitDto dto) async {
    final uri = buildUri(host, _paySubmitPath);
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    ).timeout(_httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    return RealUnitOcpPayResultDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    ).txId;
  }

  /// Software-wallet pay. Signs only the EIP-7702 delegation, then asks the
  /// relayer to sell REALU and send the ZCHF proceeds to the OpenCryptoPay
  /// deposit in one transaction. Gas is paid from the DFX balance. There is
  /// no prior ETH transfer and no user-signed transaction.
  Future<String> confirmOcpPay({
    required SwapPaymentInfo swap,
    required String paymentLinkId,
    required String quoteId,
  }) async {
    final data = swap.eip7702;
    if (data == null) {
      throw const PayConfirmNotSubmittedException(
        'Payment quote is missing the sell delegation',
      );
    }
    await walletService.ensureCurrentWalletUnlocked();
    final Eip7702ConfirmDto signed;
    try {
      final credentials = appStore.wallet.currentAccount.primaryAddress;
      _validateEip7702Data(data, credentials.address.hexEip55, swap.amount);
      final delegationSignature = await Eip712Signer.signDelegation(
        credentials: credentials,
        eip7702Data: data,
      );
      final authorizationSignature = Eip7702Signer.signAuthorization(
        credentials: credentials,
        eip7702Data: data,
      );
      signed = Eip7702ConfirmDto(
        delegation: Eip7702DelegationDto(
          delegate: data.relayerAddress,
          delegator: data.message.delegator,
          authority: data.message.authority,
          salt: '${data.message.salt}',
          signature: delegationSignature,
        ),
        authorization: Eip7702AuthorizationDto(
          chainId: data.domain.chainId,
          address: data.delegatorAddress,
          nonce: data.userNonce,
          r: '0x${authorizationSignature.r.toRadixString(16).padLeft(64, '0')}',
          s: '0x${authorizationSignature.s.toRadixString(16).padLeft(64, '0')}',
          yParity: authorizationSignature.yParity,
        ),
      );
    } on PayConfirmNotSubmittedException {
      rethrow;
    } catch (e) {
      throw PayConfirmNotSubmittedException(e.toString());
    } finally {
      await walletService.lockCurrentWallet();
    }

    final uri = buildUri(host, _payConfirmPath(swap.id));
    final response = await authenticatedPut(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paymentLinkId': paymentLinkId,
        'quoteId': quoteId,
        'eip7702': signed.toJson(),
      }),
    ).timeout(_httpTimeout);

    if (response.statusCode == 409) {
      final error = ApiException.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        httpStatusCode: response.statusCode,
      );
      if (error.message.toLowerCase().contains('already confirmed')) {
        throw AlreadyConfirmedException(
          statusCode: error.statusCode,
          code: error.code,
          message: error.message,
        );
      }
      throw error;
    }
    if (response.statusCode >= 400 && response.statusCode < 500) {
      final error = ApiException.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        httpStatusCode: response.statusCode,
      );
      throw PayConfirmNotSubmittedException(
        error.message,
        apiMessage: error.message,
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApi(response.body, response.statusCode);
    }
    final confirmed = RealUnitPayConfirmResultDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    final txHash = confirmed.txHash;
    if (txHash == null) {
      throw const PayConfirmNotSubmittedException(
        'Confirm did not return a transaction hash',
      );
    }
    return txHash;
  }

  void _validateEip7702Data(
    Eip7702Data data,
    String walletAddress,
    double shares,
  ) {
    final asset = appStore.apiConfig.asset;
    if (data.delegatorAddress.toLowerCase() != _metaMaskDelegatorAddress) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 delegator address does not match expected MetaMask Delegator contract',
      );
    }
    if (data.delegationManagerAddress.toLowerCase() != _delegationManagerAddress) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 delegation manager address does not match expected contract',
      );
    }
    if (data.domain.verifyingContract.toLowerCase() != _delegationManagerAddress) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 verifying contract does not match expected DelegationManager',
      );
    }
    if (data.message.delegator.toLowerCase() != walletAddress.toLowerCase()) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 message delegator does not match wallet address',
      );
    }
    if (data.domain.chainId != asset.chainId) {
      throw PayConfirmNotSubmittedException(
        'EIP-7702 chain ID mismatch: expected ${asset.chainId}, got ${data.domain.chainId}',
      );
    }
    if (data.message.delegate.toLowerCase() != data.relayerAddress.toLowerCase()) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 message delegate does not match relayer address',
      );
    }
    if (data.tokenAddress.toLowerCase() != asset.address.toLowerCase()) {
      throw const PayConfirmNotSubmittedException(
        'EIP-7702 token address does not match RealUnit token',
      );
    }
    if (shares != shares.roundToDouble()) {
      throw const PayConfirmNotSubmittedException(
        'Pay sells whole REALU shares only',
      );
    }
    final expectedWei = BigInt.from(shares.round()) * BigInt.from(10).pow(asset.decimals);
    final actualWei = BigInt.tryParse(data.amountWei);
    if (actualWei == null || actualWei != expectedWei) {
      throw PayConfirmNotSubmittedException(
        'EIP-7702 amount mismatch: expected $expectedWei, got ${data.amountWei}',
      );
    }
  }

  Future<RealUnitOcpPayStatusDto> getPayStatus(String id) async {
    final uri = buildUri(host, _payStatusPath(id));
    final response = await authenticatedGet(uri).timeout(_httpTimeout);

    if (response.statusCode != 200) {
      _throwApi(response.body, response.statusCode);
    }
    return RealUnitOcpPayStatusDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Never _throwApi(String body, int statusCode) {
    final errorJson = jsonDecode(body) as Map<String, dynamic>;
    throw ApiException.fromJson(errorJson, httpStatusCode: statusCode);
  }
}
