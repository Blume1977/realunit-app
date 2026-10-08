import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/dfx_transaction.dart';
import 'package:realunit_wallet/models/transaction.dart';
import 'package:realunit_wallet/packages/config/api_config.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/transaction_repository.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/transaction_history_service.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/transaction_history/completed_transaction.dart';

class _MockHistory extends Mock implements TransactionHistoryService {}

class _MockRepository extends Mock implements TransactionRepository {}

class _MockAppStore extends Mock implements AppStore {}

class _FakeTransaction extends Fake implements Transaction {}

class _FakeDfxTransaction extends Fake implements DfxTransaction {}

const _wallet = '0x1111111111111111111111111111111111111111';
const _receiver = '0x2222222222222222222222222222222222222222';
final _now = DateTime.utc(2026, 10, 8, 12);

Transaction _storedRow({
  required String txId,
  BigInt? amount,
  TransferCategory? category,
  DateTime? timestamp,
}) => Transaction(
  height: 17,
  txId: txId,
  chainId: realUnitAsset.chainId,
  senderAddress: _wallet,
  receiverAddress: '0x3333333333333333333333333333333333333333',
  amount: amount ?? BigInt.from(99),
  asset: realUnitAsset,
  type: TransactionTypes.tokenTransfer,
  category: category ?? TransferCategory.purchase,
  note: 'stored',
  data: null,
  timestamp: timestamp ?? DateTime.utc(2025, 1, 2, 3),
);

void main() {
  group('usableTxHash', () {
    test('returns null for null, empty, whitespace, and confirmed', () {
      expect(usableTxHash(null), isNull);
      expect(usableTxHash(''), isNull);
      expect(usableTxHash('   '), isNull);
      expect(usableTxHash('confirmed'), isNull);
    });

    test('returns the trimmed hash otherwise', () {
      expect(usableTxHash('0xabc'), '0xabc');
      expect(usableTxHash('  0xpay  '), '0xpay');
    });
  });

  group('buildFallbackTransaction', () {
    test(
      'sets sender, receiver, category, amount, empty txId, and timestamp',
      () {
        final timestamp = DateTime.utc(2026, 10, 8, 12);
        final tx = buildFallbackTransaction(
          asset: realUnitAsset,
          walletAddress: '0xwallet',
          txHash: 'confirmed',
          amount: BigInt.from(2),
          receiverAddress: '0xreceiver',
          category: TransferCategory.sale,
          timestamp: timestamp,
        );

        expect(tx.height, 0);
        expect(tx.txId, '');
        expect(tx.chainId, realUnitAsset.chainId);
        expect(tx.senderAddress, '0xwallet');
        expect(tx.receiverAddress, '0xreceiver');
        expect(tx.amount, BigInt.from(2));
        expect(tx.asset, realUnitAsset);
        expect(tx.type, TransactionTypes.tokenTransfer);
        expect(tx.category, TransferCategory.sale);
        expect(tx.note, '');
        expect(tx.data, isNull);
        expect(tx.timestamp, timestamp);
      },
    );

    test('uses the trimmed hash as txId when it is usable', () {
      final tx = buildFallbackTransaction(
        asset: realUnitAsset,
        walletAddress: '0xwallet',
        txHash: '  0xpay  ',
        amount: BigInt.one,
        receiverAddress: '0xreceiver',
        category: TransferCategory.transferOut,
        timestamp: DateTime.utc(2026, 10, 8),
      );

      expect(tx.txId, '0xpay');
      expect(tx.category, TransferCategory.transferOut);
    });
  });

  group('resolveCompletedTransaction', () {
    late _MockHistory history;
    late _MockRepository repository;
    late _MockAppStore appStore;

    setUpAll(() {
      registerFallbackValue(_FakeTransaction());
      registerFallbackValue(_FakeDfxTransaction());
    });

    setUp(() {
      history = _MockHistory();
      repository = _MockRepository();
      appStore = _MockAppStore();
      when(() => appStore.primaryAddress).thenReturn(_wallet);
      when(
        () => appStore.apiConfig,
      ).thenReturn(const ApiConfig(networkMode: NetworkMode.mainnet));
    });

    void verifyNeverWrites() {
      verifyNever(() => repository.insertTransaction(any()));
      verifyNever(() => repository.updateTransaction(any()));
      verifyNever(() => repository.insertDfxTransaction(any()));
      verifyNever(() => repository.updateDfxTransaction(any()));
    }

    test('returns the stored history row and does not write', () async {
      const storedId = '0xABCDEF';
      final stored = _storedRow(txId: storedId);
      final decoy = _storedRow(txId: '0x9999999999999999999999999999999999999999');
      when(() => history.apiBasedSync()).thenAnswer((_) async {});
      when(
        () => repository.findTxIdIgnoreCase('0xabcdef'),
      ).thenAnswer((_) async => storedId);
      when(
        () => repository.allTransactions,
      ).thenAnswer((_) async => [stored, decoy]);

      final request = CompletedTransactionRequest(
        txHash: '  0xabcdef  ',
        amount: BigInt.from(2),
        receiverAddress: _receiver,
        category: TransferCategory.sale,
      );

      final result = await resolveCompletedTransaction(
        request,
        history: history,
        repository: repository,
        appStore: appStore,
        now: _now,
      );

      expect(result.transaction, same(stored));
      expect(result.transaction.amount, isNot(request.amount));
      expect(result.transaction.category, isNot(request.category));
      expect(result.transaction.timestamp, isNot(_now));
      expect(result.walletAddress, _wallet);
      verify(() => history.apiBasedSync()).called(1);
      verify(() => repository.allTransactions).called(1);
      verifyNeverWrites();
    });

    test('returns the in-memory fallback on a miss and does not write', () async {
      when(() => history.apiBasedSync()).thenAnswer((_) async {});
      when(
        () => repository.findTxIdIgnoreCase('0xpay'),
      ).thenAnswer((_) async => null);

      final request = CompletedTransactionRequest(
        txHash: '  0xpay  ',
        amount: BigInt.from(7),
        receiverAddress: _receiver,
        category: TransferCategory.transferOut,
      );

      final result = await resolveCompletedTransaction(
        request,
        history: history,
        repository: repository,
        appStore: appStore,
        now: _now,
      );

      expect(result.transaction.height, 0);
      expect(result.transaction.txId, '0xpay');
      expect(result.transaction.amount, request.amount);
      expect(result.transaction.category, request.category);
      expect(result.transaction.receiverAddress, request.receiverAddress);
      expect(result.transaction.senderAddress, _wallet);
      expect(result.transaction.asset, realUnitAsset);
      expect(result.transaction.timestamp, _now);
      expect(result.walletAddress, _wallet);
      verify(() => history.apiBasedSync()).called(1);
      verifyNever(() => repository.allTransactions);
      verifyNeverWrites();
    });

    test('does not throw when apiBasedSync throws and still returns fallback', () async {
      when(() => history.apiBasedSync()).thenThrow(Exception('sync failed'));
      when(
        () => repository.findTxIdIgnoreCase('0xpay'),
      ).thenAnswer((_) async => null);

      final request = CompletedTransactionRequest(
        txHash: '0xpay',
        amount: BigInt.from(7),
        receiverAddress: _receiver,
        category: TransferCategory.transferOut,
      );

      final result = await resolveCompletedTransaction(
        request,
        history: history,
        repository: repository,
        appStore: appStore,
        now: _now,
      );

      expect(result.transaction.height, 0);
      expect(result.transaction.txId, '0xpay');
      expect(result.transaction.amount, request.amount);
      expect(result.transaction.category, request.category);
      expect(result.transaction.timestamp, _now);
      verify(() => repository.findTxIdIgnoreCase('0xpay')).called(1);
      verifyNever(() => repository.allTransactions);
      verifyNeverWrites();
    });

    for (final hash in <String?>[null, '', 'confirmed']) {
      test(
        'skips sync and lookup when txHash is ${hash == null
            ? 'null'
            : hash.isEmpty
            ? 'empty'
            : hash}',
        () async {
          final request = CompletedTransactionRequest(
            txHash: hash,
            amount: BigInt.from(3),
            receiverAddress: _receiver,
            category: TransferCategory.sale,
          );

          final result = await resolveCompletedTransaction(
            request,
            history: history,
            repository: repository,
            appStore: appStore,
            now: _now,
          );

          expect(result.transaction.txId, '');
          expect(result.transaction.height, 0);
          expect(result.transaction.amount, request.amount);
          expect(result.transaction.category, request.category);
          expect(result.transaction.timestamp, _now);
          verifyNever(() => history.apiBasedSync());
          verifyNever(() => repository.findTxIdIgnoreCase(any()));
          verifyNeverWrites();
        },
      );
    }
  });
}
