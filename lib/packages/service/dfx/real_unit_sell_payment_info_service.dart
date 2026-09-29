import 'dart:convert';

import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_auth_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/sell_exceptions.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_response_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_confirm_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_confirm_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_unsigned_transactions_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/packages/wallet/eip712_signer.dart';
import 'package:realunit_wallet/packages/wallet/eip7702_signer.dart';
import 'package:realunit_wallet/styles/currency.dart';

class RealUnitSellPaymentInfoService extends DFXAuthService {
  static const _sellPaymentInfoPath = '/v1/realunit/sell';
  static String _confirmPaymentPath(int id) => '/v1/realunit/sell/$id/confirm';
  static String _unsignedTxsPath(int id) => '/v1/realunit/sell/$id/unsigned-transactions';
  static String _broadcastPath(int id) => '/v1/realunit/sell/$id/broadcast';

  // MetaMask Delegation Framework v1.3.0, CREATE2 — identical on all EVM chains
  static const _metaMaskDelegatorAddress = '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b';
  static const _delegationManagerAddress = '0xdb9b1e94b5b69df7e401ddbede43491141047db3';

  RealUnitSellPaymentInfoService(super.appStore, super.walletService);

  Future<SellPaymentInfo> getPaymentInfo(
    int amount,
    String iban, {
    Currency currency = Currency.chf,
  }) async {
    final sellDto = RealUnitSellDto(
      amount: amount,
      iban: iban,
      currency: currency,
    );

    final uri = buildUri(host, _sellPaymentInfoPath);
    final response = await authenticatedPut(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(sellDto.toJson()),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final responseDto = RealUnitSellPaymentInfoDto.fromJson(json);

      return SellPaymentInfo(
        id: responseDto.id,
        amount: responseDto.amount.toInt(),
        currency: responseDto.currency,
        beneficiary: responseDto.beneficiary,
        eip7702: responseDto.eip7702,
        estimatedAmount: responseDto.estimatedAmount,
        exchangeRate: responseDto.exchangeRate,
        rate: responseDto.rate,
        depositAddress: responseDto.depositAddress,
        tokenAddress: responseDto.tokenAddress,
        chainId: responseDto.chainId,
        ethBalance: responseDto.ethBalance,
        requiredGasEth: responseDto.requiredGasEth,
        isValid: responseDto.isValid,
        minVolume: responseDto.minVolume,
        maxVolume: responseDto.maxVolume,
        error: responseDto.error,
        valueChf: responseDto.valueChf,
        valueEur: responseDto.valueEur,
        zchfAmount: responseDto.zchfAmount,
      );
    } else if (response.statusCode == 403) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    } else {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }
  }

  /// Confirms payment for Software Wallet
  Future<void> confirmPayment(SellPaymentInfo paymentInfo) async {
    // EIP-712 + EIP-7702 typed-data signing requires the private key; promote
    // the view-wallet to a fully unlocked SoftwareWallet before reading
    // credentials.
    await walletService.ensureCurrentWalletUnlocked();
    try {
      final credentials = appStore.wallet.currentAccount.primaryAddress;
      _validateEip7702Data(paymentInfo.eip7702, credentials.address.hexEip55, paymentInfo.amount);

      final delegationSignature = await Eip712Signer.signDelegation(
        credentials: credentials,
        eip7702Data: paymentInfo.eip7702,
      );
      final authorizationSignature = Eip7702Signer.signAuthorization(
        credentials: credentials,
        eip7702Data: paymentInfo.eip7702,
      );
      await _sendConfirm(
        paymentInfo.id,
        RealUnitSellConfirmDto(
          eip7702ConfirmDto: Eip7702ConfirmDto(
            delegation: Eip7702DelegationDto(
              delegate: paymentInfo.eip7702.relayerAddress,
              delegator: paymentInfo.eip7702.message.delegator,
              authority: paymentInfo.eip7702.message.authority,
              salt: '${paymentInfo.eip7702.message.salt}',
              signature: delegationSignature,
            ),
            authorization: Eip7702AuthorizationDto(
              chainId: paymentInfo.eip7702.domain.chainId,
              address: paymentInfo.eip7702.delegatorAddress,
              nonce: paymentInfo.eip7702.userNonce,
              r: '0x${authorizationSignature.r.toRadixString(16).padLeft(64, '0')}',
              s: '0x${authorizationSignature.s.toRadixString(16).padLeft(64, '0')}',
              yParity: authorizationSignature.yParity,
            ),
          ),
        ),
      );
    } finally {
      // Drop the mnemonic from memory as soon as signing is done — see
      // [WalletService.lockCurrentWallet]. Runs on the throw path too so an
      // EIP-712 validation failure mid-sequence doesn't leave the key resident.
      await walletService.lockCurrentWallet();
    }
  }

  Future<RealUnitUnsignedTransactionsRequestDto> createUnsignedTransactions(int id) async {
    final uri = buildUri(host, _unsignedTxsPath(id));
    final response = await authenticatedPut(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RealUnitUnsignedTransactionsRequestDto.fromJson(json);
  }

  Future<String> broadcastTransaction(
    int id,
    BroadcastTransactionRequestDto dto,
  ) async {
    final uri = buildUri(host, _broadcastPath(id));
    final response = await authenticatedPut(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(dto.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }
    final responseDto = BroadcastTransactionResponseDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return responseDto.txHash;
  }

  /// Confirms payment for Bitbox Wallet using txHash obtained after broadcasting the transaction
  Future<void> confirmPaymentWithTxHash(SellPaymentInfo paymentInfo, String txHash) async {
    await _sendConfirm(paymentInfo.id, RealUnitSellConfirmDto(txHash: txHash));
  }

  Future<void> _sendConfirm(int id, RealUnitSellConfirmDto dto) async {
    final uri = buildUri(host, _confirmPaymentPath(id));
    final response = await authenticatedPut(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(dto.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      final error = ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
      // 409 "already confirmed": an earlier confirm landed but its response was lost.
      if (error.statusCode == 409 && error.message.toLowerCase().contains('already confirmed')) {
        throw AlreadyConfirmedException(
          statusCode: error.statusCode,
          code: error.code,
          message: error.message,
        );
      }
      throw error;
    }
  }

  void _validateEip7702Data(Eip7702Data data, String walletAddress, int userAmount) {
    final expectedChainId = appStore.apiConfig.asset.chainId;

    // Pin signed contract addresses against known constants
    if (data.delegatorAddress.toLowerCase() != _metaMaskDelegatorAddress) {
      throw Exception(
        'EIP-7702 delegator address does not match expected MetaMask Delegator contract',
      );
    }
    if (data.delegationManagerAddress.toLowerCase() != _delegationManagerAddress) {
      throw Exception('EIP-7702 delegation manager address does not match expected contract');
    }
    if (data.domain.verifyingContract.toLowerCase() != _delegationManagerAddress) {
      throw Exception('EIP-7702 verifying contract does not match expected DelegationManager');
    }

    // Validate signed fields against known values
    if (data.message.delegator.toLowerCase() != walletAddress.toLowerCase()) {
      throw Exception('EIP-7702 message delegator does not match wallet address');
    }
    if (data.domain.chainId != expectedChainId) {
      throw Exception(
        'EIP-7702 chain ID mismatch: expected $expectedChainId, got ${data.domain.chainId}',
      );
    }

    // Cross-check signed delegate against response metadata
    if (data.message.delegate.toLowerCase() != data.relayerAddress.toLowerCase()) {
      throw Exception('EIP-7702 message delegate does not match relayer address');
    }

    // Validate unsigned metadata for consistency
    if (data.tokenAddress.toLowerCase() != appStore.apiConfig.asset.address.toLowerCase()) {
      throw Exception('EIP-7702 token address does not match RealUnit token');
    }
    final expectedWei =
        BigInt.from(userAmount) * BigInt.from(10).pow(appStore.apiConfig.asset.decimals);
    final actualWei = BigInt.tryParse(data.amountWei);
    if (actualWei == null || actualWei != expectedWei) {
      throw Exception('EIP-7702 amount mismatch: expected $expectedWei, got ${data.amountWei}');
    }
  }
}
