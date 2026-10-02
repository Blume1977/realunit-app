import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/io/documents_directory_port.dart';
import 'package:realunit_wallet/packages/service/dfx/models/pdf/pdf_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pdf_service.dart';
import 'package:realunit_wallet/screens/transaction_history/cubits/receipt/transaction_history_receipt_cubit.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

class _MockPdfService extends Mock implements RealUnitPdfService {}

/// Returns a real, writable [Directory] under `Directory.systemTemp`, so the
/// cubit's `File.writeAsBytes` path executes for-real without crossing the
/// `path_provider` platform channel.
class _FakeDocumentsDirectoryPort implements DocumentsDirectoryPort {
  _FakeDocumentsDirectoryPort(this.directory);

  final Directory directory;
  int calls = 0;

  @override
  Future<Directory> getTemporaryDirectory() async {
    calls++;
    return directory;
  }

  @override
  Future<Directory> getApplicationDocumentsDirectory() async => directory;
}

void main() {
  late _MockPdfService service;
  late Directory tempDir;
  late _FakeDocumentsDirectoryPort directoryPort;

  setUpAll(() {
    registerFallbackValue(Currency.chf);
    registerFallbackValue(Language.en);
  });

  setUp(() {
    service = _MockPdfService();
    tempDir = Directory.systemTemp.createTempSync('receipt_cubit_test_');
    directoryPort = _FakeDocumentsDirectoryPort(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  TransactionHistoryReceiptCubit buildCubit() =>
      TransactionHistoryReceiptCubit(service, directory: directoryPort);

  group('$TransactionHistoryReceiptCubit', () {
    test('initial state is TransactionHistoryReceiptInitial', () {
      expect(buildCubit().state, isA<TransactionHistoryReceiptInitial>());
    });

    test('default constructor uses production path provider adapter', () {
      expect(TransactionHistoryReceiptCubit(service), isNotNull);
    });

    test('generateReceipt writes the PDF and emits Success with the file path', () async {
      final pdfBytes = utf8.encode('%PDF-1.4 fake-tx');
      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => PdfDto(pdfData: base64Encode(pdfBytes)));

      final cubit = buildCubit();
      final emissions = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<TransactionHistoryReceiptLoading>(),
          isA<TransactionHistoryReceiptSuccess>(),
        ]),
      );

      await cubit.generateReceipt('tx-42', currency: Currency.eur, language: Language.de);
      await emissions;

      expect(cubit.state, isA<TransactionHistoryReceiptSuccess>());
      final success = cubit.state as TransactionHistoryReceiptSuccess;
      expect(success.receiptPath, '${tempDir.path}/receipt_tx-42.pdf');
      expect(File(success.receiptPath).existsSync(), isTrue);
      expect(File(success.receiptPath).readAsBytesSync(), pdfBytes);
      expect(directoryPort.calls, 1);
      verify(
        () => service.getTransactionReceipt('tx-42', currency: Currency.eur, language: Language.de),
      ).called(1);
    });

    test('generateReceipt uses Currency.chf as default', () async {
      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => PdfDto(pdfData: base64Encode(<int>[1])));

      final cubit = buildCubit();
      await cubit.generateReceipt('tx-1', language: Language.en);

      verify(
        () => service.getTransactionReceipt('tx-1', currency: Currency.chf, language: Language.en),
      ).called(1);
    });

    test('generateReceipt emits Failure on service error', () async {
      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => throw Exception('network'));

      final cubit = buildCubit();
      await cubit.generateReceipt('tx-1', language: Language.en);

      expect(cubit.state, isA<TransactionHistoryReceiptFailure>());
      final failure = cubit.state as TransactionHistoryReceiptFailure;
      expect(failure.message, contains('network'));
    });

    test('generateReceipt emits Failure when the directory is missing', () async {
      final missing = Directory('${tempDir.path}/does-not-exist');
      final brokenPort = _FakeDocumentsDirectoryPort(missing);

      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => PdfDto(pdfData: base64Encode(<int>[1])));

      final cubit = TransactionHistoryReceiptCubit(service, directory: brokenPort);
      await cubit.generateReceipt('tx-1', language: Language.en);

      expect(cubit.state, isA<TransactionHistoryReceiptFailure>());
    });

    test('does not emit Success when closed during service call', () async {
      final completer = Completer<PdfDto>();
      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      unawaited(cubit.generateReceipt('tx-1', language: Language.en));
      await cubit.close();
      completer.complete(PdfDto(pdfData: base64Encode(<int>[1])));

      // If emit fires after close, the framework throws StateError.
    });

    test('does not emit Failure after close', () async {
      final completer = Completer<PdfDto>();
      when(
        () => service.getTransactionReceipt(
          any(),
          currency: any(named: 'currency'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      unawaited(cubit.generateReceipt('tx-1', language: Language.en));
      await cubit.close();
      completer.completeError(Exception('late'));
    });

    test('generateExchangeReceipt writes the PDF and emits Success with the file path', () async {
      final pdfBytes = utf8.encode('%PDF-1.4 fake-tx');
      when(
        () => service.getExchangeReceipt(any()),
      ).thenAnswer((_) async => PdfDto(pdfData: base64Encode(pdfBytes)));

      final cubit = buildCubit();
      final emissions = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<TransactionHistoryReceiptLoading>(),
          isA<TransactionHistoryReceiptSuccess>(),
        ]),
      );

      await cubit.generateExchangeReceipt('tx-42');
      await emissions;

      expect(cubit.state, isA<TransactionHistoryReceiptSuccess>());
      final success = cubit.state as TransactionHistoryReceiptSuccess;
      expect(success.receiptPath, contains('receipt_exchange_tx-42.pdf'));
      verify(() => service.getExchangeReceipt('tx-42')).called(1);
    });

    test('generateExchangeReceipt emits Failure on service error', () async {
      when(
        () => service.getExchangeReceipt(any()),
      ).thenAnswer((_) async => throw Exception('network'));

      final cubit = buildCubit();
      await cubit.generateExchangeReceipt('tx-42');

      expect(cubit.state, isA<TransactionHistoryReceiptFailure>());
    });
  });
}
