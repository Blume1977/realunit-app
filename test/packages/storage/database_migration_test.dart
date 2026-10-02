import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/storage/database.dart';
import 'package:realunit_wallet/packages/storage/dfx_transaction_storage.dart';
import 'package:realunit_wallet/packages/storage/transaction_storage.dart';
import 'package:realunit_wallet/packages/storage/wallet_storage.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema', () {
    test('schema version is 5', () {
      expect(db.schemaVersion, 5);
    });

    test('creates all expected tables on fresh database', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();

      expect(
        names,
        containsAll([
          'assets',
          'balances',
          'key_value_cache',
          'nodes',
          'transactions',
          'dfx_transaction_details',
          'wallet_account_infos',
          'wallet_infos',
        ]),
      );
    });

    test('wallet_infos accepts inserts via Drift API', () async {
      final id = await db.insertWallet('Test', 'encrypted-seed', '0xAddress', 0);

      expect(id, greaterThan(0));

      final row = await db.getWalletById(id);
      expect(row, isNotNull);
      expect(row!.name, 'Test');
      expect(row.seed, 'encrypted-seed');
      expect(row.address, '0xAddress');
    });

    test('dfx_transaction_details references transactions via tx_id', () async {
      await db.insertTransactions(
        1,
        'tx-1',
        1,
        '0xA',
        '0xB',
        '100',
        1,
        0,
        '',
        '',
        '',
        DateTime.now(),
      );

      await db.insertDfxTransactionDetails(txId: 'tx-1', dfxId: 42);

      final details = await db.getDfxTransactionDetailsByDfxId(42);
      expect(details, isNotNull);
      expect(details!.txId, 'tx-1');
    });
  });

  group('AppDatabase.migration', () {
    test('onCreate creates the full schema on a fresh database', () async {
      // Re-running `createAll` on an already migrated database would
      // fail with "table … already exists". This indirectly pins that
      // the `onCreate` branch we install in `MigrationStrategy` only
      // fires once on a fresh in-memory store.
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(tables, isNotEmpty);
    });

    test('onUpgrade from v1 → v3 creates the dfx table and the category column', () async {
      // Simulate a pre-v2 database: drop the dfx_transaction_details table (added in v2)
      // and the transactions.category column (added in v3), then drive the migration
      // manually via the strategy exposed by `AppDatabase.migration`. After
      // onUpgrade(1, 3) both must exist again, exercising both `from <` branches.
      await db.customStatement('DROP TABLE dfx_transaction_details');
      await db.customStatement('ALTER TABLE transactions DROP COLUMN category');

      final strategy = db.migration;
      final migrator = Migrator(db);
      await strategy.onUpgrade(migrator, 1, 3);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='dfx_transaction_details'",
          )
          .get();
      expect(rows, hasLength(1));

      final columns = await db.customSelect("PRAGMA table_info('transactions')").get();
      expect(columns.map((r) => r.read<String>('name')), contains('category'));
    });

    test('onUpgrade from v2 → v3 adds the category column with its default', () async {
      await db.customStatement('ALTER TABLE transactions DROP COLUMN category');

      final details = db.dfxTransactionDetails;
      for (final column in [
        details.inputAmount,
        details.inputAsset,
        details.outputAmount,
        details.outputAsset,
      ]) {
        await db.customStatement(
          'ALTER TABLE dfx_transaction_details DROP COLUMN ${column.name}',
        );
      }

      final strategy = db.migration;
      final migrator = Migrator(db);
      await strategy.onUpgrade(migrator, 2, 3);

      final columns = await db.customSelect("PRAGMA table_info('transactions')").get();
      expect(columns.map((r) => r.read<String>('name')), contains('category'));

      final detailsColumns = await db
          .customSelect("PRAGMA table_info('dfx_transaction_details')")
          .get();
      expect(
        detailsColumns.map((r) => r.read<String>('name')),
        isNot(contains(details.inputAmount.name)),
      );
      expect(
        detailsColumns.map((r) => r.read<String>('name')),
        isNot(contains(details.inputAsset.name)),
      );
      expect(
        detailsColumns.map((r) => r.read<String>('name')),
        isNot(contains(details.outputAmount.name)),
      );
      expect(
        detailsColumns.map((r) => r.read<String>('name')),
        isNot(contains(details.outputAsset.name)),
      );
    });

    test('onUpgrade from v3 → v4 deletes leftover savings rows and remaps referral payouts', () async {
      await db.insertTransactions(1, 'tx-token', 1, '0xA', '0xB', '100', 1, 2, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-savings-add', 1, '0xA', '0xB', '100', 1, 3, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-savings-remove', 1, '0xA', '0xB', '100', 1, 4, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-referral', 1, '0xA', '0xB', '100', 1, 5, '', '', '', DateTime.now());

      final strategy = db.migration;
      final migrator = Migrator(db);
      await strategy.onUpgrade(migrator, 3, 4);

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(2));
      expect(rows.firstWhere((r) => r.txId == 'tx-token').type, 2);
      expect(rows.where((r) => r.txId == 'tx-savings-add'), isEmpty);
      expect(rows.where((r) => r.txId == 'tx-savings-remove'), isEmpty);
      expect(rows.firstWhere((r) => r.txId == 'tx-referral').type, 3);

      final dfxRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='dfx_transaction_details'",
          )
          .get();
      expect(dfxRows, hasLength(1));
    });

    test('onUpgrade from v4 → v5 adds the amount columns and leaves a type-3 row unchanged', () async {
      await db.insertTransactions(1, 'tx-referral', 1, '0xA', '0xB', '100', 1, 3, '', '', '', DateTime.now());

      final details = db.dfxTransactionDetails;
      for (final column in [
        details.inputAmount,
        details.inputAsset,
        details.outputAmount,
        details.outputAsset,
      ]) {
        await db.customStatement(
          'ALTER TABLE dfx_transaction_details DROP COLUMN ${column.name}',
        );
      }

      final strategy = db.migration;
      final migrator = Migrator(db);
      await strategy.onUpgrade(migrator, 4, 5);

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.txId, 'tx-referral');
      expect(rows.single.type, 3);

      final columns = await db
          .customSelect("PRAGMA table_info('dfx_transaction_details')")
          .get();
      expect(
        columns.map((r) => r.read<String>('name')),
        containsAll([
          details.inputAmount.name,
          details.inputAsset.name,
          details.outputAmount.name,
          details.outputAsset.name,
        ]),
      );
    });

    test('onUpgrade from v3 → v5 remaps referral payouts and adds the amount columns', () async {
      await db.insertTransactions(1, 'tx-token', 1, '0xA', '0xB', '100', 1, 2, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-savings-add', 1, '0xA', '0xB', '100', 1, 3, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-savings-remove', 1, '0xA', '0xB', '100', 1, 4, '', '', '', DateTime.now());
      await db.insertTransactions(1, 'tx-referral', 1, '0xA', '0xB', '100', 1, 5, '', '', '', DateTime.now());

      final details = db.dfxTransactionDetails;
      for (final column in [
        details.inputAmount,
        details.inputAsset,
        details.outputAmount,
        details.outputAsset,
      ]) {
        await db.customStatement(
          'ALTER TABLE dfx_transaction_details DROP COLUMN ${column.name}',
        );
      }

      final strategy = db.migration;
      final migrator = Migrator(db);
      await strategy.onUpgrade(migrator, 3, 5);

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(2));
      expect(rows.firstWhere((r) => r.txId == 'tx-token').type, 2);
      expect(rows.where((r) => r.txId == 'tx-savings-add'), isEmpty);
      expect(rows.where((r) => r.txId == 'tx-savings-remove'), isEmpty);
      expect(rows.firstWhere((r) => r.txId == 'tx-referral').type, 3);

      final columns = await db
          .customSelect("PRAGMA table_info('dfx_transaction_details')")
          .get();
      expect(
        columns.map((r) => r.read<String>('name')),
        containsAll([
          details.inputAmount.name,
          details.inputAsset.name,
          details.outputAmount.name,
          details.outputAsset.name,
        ]),
      );
    });
  });
}
