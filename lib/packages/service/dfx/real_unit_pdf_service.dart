import 'dart:convert';

import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_auth_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/pdf/balance_pdf_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/pdf/multi_receipt_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/pdf/pdf_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/pdf/single_receipt_dto.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

class RealUnitPdfService extends DFXAuthService {
  static const _balancePath = '/v1/realunit/balance/pdf';
  static const _transactionsReceiptMultiPath = 'v1/realunit/transactions/receipt/multi';
  static const _transactionsReceiptSinglePath = '/v1/realunit/transactions/receipt/single';
  static const _transactionsReceiptExchangePath = '/v1/realunit/transactions/receipt/exchange';
  static const _transactionsReceiptPaymentPath = '/v1/realunit/transactions/receipt/payment';

  RealUnitPdfService(super.appStore, super.walletService);

  Future<PdfDto> getBalanceReport({
    required DateTime date,
    required Currency currency,
    required Language language,
  }) async {
    final balancePdfDto = BalancePdfDto(
      language: language,
      address: appStore.primaryAddress,
      currency: currency,
      date: date,
    );

    final uri = buildUri(host, _balancePath);
    final response = await authenticatedPost(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(balancePdfDto),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }

    return PdfDto.fromJson(jsonDecode(response.body));
  }

  Future<PdfDto> getTransactionsReceipt(
    List<String> ids, {
    Currency currency = Currency.chf,
    required Language language,
  }) async {
    final uri = buildUri(host, _transactionsReceiptMultiPath);
    final response = await authenticatedPost(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(MultiReceiptDto(txIds: ids, currency: currency, language: language)),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }

    return PdfDto.fromJson(jsonDecode(response.body));
  }

  Future<PdfDto> getTransactionReceipt(
    String id, {
    Currency currency = Currency.chf,
    required Language language,
  }) async {
    final uri = buildUri(host, _transactionsReceiptSinglePath);
    final response = await authenticatedPost(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(SingleReceiptDto(txId: id, currency: currency, language: language)),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }

    return PdfDto.fromJson(jsonDecode(response.body));
  }

  Future<PdfDto> getExchangeReceipt(String txId) async {
    final uri = buildUri(host, _transactionsReceiptExchangePath);
    final response = await authenticatedPost(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'txHash': txId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }

    return PdfDto.fromJson(jsonDecode(response.body));
  }

  /// Payment receipt of a RealUnit payment (history category `payment`): the payment to the
  /// merchant that the sale proceeds covered. The sale itself has the regular single receipt.
  Future<PdfDto> getPaymentReceipt(String txId, {required Language language}) async {
    final uri = buildUri(host, _transactionsReceiptPaymentPath);
    final response = await authenticatedPost(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'txHash': txId, 'language': language.code.toUpperCase()}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException.fromJson(errorJson, httpStatusCode: response.statusCode);
    }

    return PdfDto.fromJson(jsonDecode(response.body));
  }
}
