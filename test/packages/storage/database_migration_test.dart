import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:realunit_wallet/packages/storage/database.dart';
import 'package:realunit_wallet/packages/storage/dfx_transaction_storage.dart';
import 'package:realunit_wallet/packages/storage/transaction_storage.dart';
import 'package:realunit_wallet/packages/storage/wallet_storage.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

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

  // These tests write an older schema by hand and let drift run the real
  // upgrade when the database opens, as it does on a device after an app
  // update. They also cover databases that an earlier upgrade, interrupted
  // after some of its statements had committed, left half-migrated at the
  // old user_version.
  group('AppDatabase upgrade on open', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('database_upgrade_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'v3 → v5 deletes savings rows, keeps referral payouts and adds the amount columns',
      () async {
        final upgraded = _openSchema(3, [
          _txRow('tx-token', type: 2),
          _txRow('tx-savings-add', type: 3),
          _txRow('tx-savings-remove', type: 4),
          _txRow('tx-referral', type: 5, sender: _zeroSender),
          _walletRow,
          _detailsRow('tx-token'),
        ]);
        addTearDown(upgraded.close);

        expect(await _userVersion(upgraded), 5);
        expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3});
        expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
        final details = await upgraded.getDfxTransactionDetailsByDfxId(7);
        expect(details!.txId, 'tx-token');
        expect(details.rate, '1.5');
        expect(details.inputAmount, isNull);
        expect((await upgraded.getWalletById(1))!.seed, 'encrypted-seed');
      },
    );

    test(
      'v3 with input_amount already present reaches v5 and keeps rewritten referral payouts',
      () async {
        // State after an upgrade that rewrote the types and added input_amount,
        // but was interrupted before the version was written.
        final upgraded = _openSchema(3, [
          'ALTER TABLE dfx_transaction_details ADD COLUMN input_amount TEXT NULL',
          _txRow('tx-token', type: 2),
          _txRow('tx-referral', type: 3, sender: _zeroSender),
          _detailsRow('tx-token', inputAmount: '100'),
        ]);
        addTearDown(upgraded.close);

        expect(await _userVersion(upgraded), 5);
        expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3});
        expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
        expect((await upgraded.getDfxTransactionDetailsByDfxId(7))!.inputAmount, '100');
      },
    );

    test(
      'v3 with all four amount columns already present reaches v5 and keeps referral payouts',
      () async {
        final upgraded = _openSchema(3, [
          for (final column in _amountColumns)
            'ALTER TABLE dfx_transaction_details ADD COLUMN $column TEXT NULL',
          _txRow('tx-token', type: 2),
          _txRow('tx-referral', type: 3, sender: _zeroSender),
          _detailsRow('tx-token', inputAmount: '100'),
        ]);
        addTearDown(upgraded.close);

        expect(await _userVersion(upgraded), 5);
        expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3});
        expect((await upgraded.getDfxTransactionDetailsByDfxId(7))!.inputAmount, '100');
      },
    );

    test(
      'v3 whose type rewrite already ran but no column was added keeps referral payouts',
      () async {
        final upgraded = _openSchema(3, [
          _txRow('tx-token', type: 2),
          _txRow('tx-referral', type: 3, sender: _zeroSender),
        ]);
        addTearDown(upgraded.close);

        expect(await _userVersion(upgraded), 5);
        expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3});
      },
    );

    test(
      'v1 whose earlier upgrade already created the old details table reaches v5 with the amount columns',
      () async {
        // An upgrade from v1 under the v2–v4 code created dfx_transaction_details
        // without the amount columns and was interrupted before the version was
        // written.
        final upgraded = _openSchema(1, [_txRow('tx-token', type: 2, withCategory: false)]);
        addTearDown(upgraded.close);

        expect(await _userVersion(upgraded), 5);
        expect(await _types(upgraded), {'tx-token': 2});
        expect(await _columns(upgraded, 'transactions'), contains('category'));
        expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
      },
    );

    test('v2 → v5 adds the category column with its default and the amount columns', () async {
      final upgraded = _openSchema(2, [
        _txRow('tx-token', type: 2, withCategory: false),
        _txRow('tx-referral', type: 5, sender: _zeroSender, withCategory: false),
      ]);
      addTearDown(upgraded.close);

      expect(await _userVersion(upgraded), 5);
      expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3});
      final rows = await upgraded.select(upgraded.transactions).get();
      expect(rows.map((r) => r.category), everyElement(''));
      expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
    });

    test('v4 → v5 adds the amount columns and leaves every type unchanged', () async {
      final upgraded = _openSchema(4, [
        _txRow('tx-token', type: 2),
        _txRow('tx-referral', type: 3, sender: _zeroSender),
        _txRow('tx-other', type: 3),
      ]);
      addTearDown(upgraded.close);

      expect(await _userVersion(upgraded), 5);
      expect(await _types(upgraded), {'tx-token': 2, 'tx-referral': 3, 'tx-other': 3});
      expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
    });

    test('a failing upgrade rolls back every step and keeps the old version', () async {
      final path = p.join(tempDir.path, 'wallet.db');
      final file = raw.sqlite3.open(path);
      _writeSchema(file, 2, [
        _txRow('tx-savings-add', type: 3, withCategory: false),
        _txRow('tx-referral', type: 5, sender: _zeroSender, withCategory: false),
        // Fails the type rewrite, after the category column was added and the
        // savings row deleted.
        "CREATE TRIGGER fail_rewrite BEFORE UPDATE ON transactions BEGIN SELECT RAISE(ABORT, 'interrupted'); END",
      ]);
      file.close();

      final failing = AppDatabase.forTesting(NativeDatabase(File(path)));
      await expectLater(_userVersion(failing), throwsA(isA<SqliteException>()));
      await failing.close();

      final after = raw.sqlite3.open(path);
      addTearDown(after.close);
      expect(after.select('PRAGMA user_version').single.values.single, 2);
      final columns = after.select("PRAGMA table_info('transactions')").map((r) => r['name']);
      expect(columns, isNot(contains('category')));
      final types = after.select('SELECT tx_id, type FROM transactions ORDER BY tx_id');
      expect(types.map((r) => '${r['tx_id']}:${r['type']}'), ['tx-referral:5', 'tx-savings-add:3']);
    });

    test('upgrades a half-migrated v3 file through a background isolate', () async {
      final path = p.join(tempDir.path, 'wallet.db');
      final file = raw.sqlite3.open(path);
      _writeSchema(file, 3, [
        'ALTER TABLE dfx_transaction_details ADD COLUMN input_amount TEXT NULL',
        _txRow('tx-referral', type: 3, sender: _zeroSender),
      ]);
      file.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase.createInBackground(File(path)));
      addTearDown(upgraded.close);

      expect(await _userVersion(upgraded), 5);
      expect(await _types(upgraded), {'tx-referral': 3});
      expect(await _columns(upgraded, 'dfx_transaction_details'), containsAll(_amountColumns));
    });
  });
}

const _zeroSender = '0x0000000000000000000000000000000000000000';

const _amountColumns = ['input_amount', 'input_asset', 'output_amount', 'output_asset'];

const _walletRow =
    "INSERT INTO wallet_infos (id, name, seed, address, type) VALUES (1, 'Main', 'encrypted-seed', '0xWallet', 0)";

/// Tables of schema v2: `transactions` has no `category` and
/// `dfx_transaction_details` none of the amount columns. v3 adds `category`;
/// v4 changes data only, so it shares the v3 tables. Version 1 gets the v2
/// tables too, as an interrupted v1 upgrade under the v2–v4 code left them.
List<String> _schema(int version) => [
  'CREATE TABLE "assets" ("id" INTEGER NOT NULL UNIQUE, "chain_id" INTEGER NOT NULL, "address" TEXT NOT NULL, '
      '"symbol" TEXT NOT NULL, "name" TEXT NOT NULL, "decimals" INTEGER NOT NULL, "icon_url" TEXT NULL, '
      '"editable" INTEGER NOT NULL CHECK ("editable" IN (0, 1)))',
  'CREATE TABLE "balances" ("id" INTEGER NOT NULL UNIQUE, "chain_id" INTEGER NOT NULL, '
      '"contract_address" TEXT NOT NULL, "wallet_address" TEXT NOT NULL, "balance" TEXT NOT NULL)',
  'CREATE TABLE "key_value_cache" ("id" TEXT NOT NULL UNIQUE, "value" TEXT NOT NULL)',
  'CREATE TABLE "nodes" ("chain_id" INTEGER NOT NULL UNIQUE, "name" TEXT NOT NULL, "https_url" TEXT NOT NULL, '
      '"wss_url" TEXT NULL)',
  'CREATE TABLE "transactions" ("height" INTEGER NOT NULL, "tx_id" TEXT NOT NULL UNIQUE, '
      '"chain_id" INTEGER NOT NULL, "sender_address" TEXT NOT NULL, "receiver_address" TEXT NOT NULL, '
      '"amount" TEXT NOT NULL, "asset" INTEGER NOT NULL, "type" INTEGER NOT NULL, '
      '${version >= 3 ? '"category" TEXT NOT NULL DEFAULT \'\', ' : ''}'
      '"note" TEXT NOT NULL, "data" TEXT NOT NULL, "time_stamp" INTEGER NOT NULL)',
  'CREATE TABLE "dfx_transaction_details" ("tx_id" TEXT NOT NULL UNIQUE REFERENCES transactions (tx_id), '
      '"dfx_id" INTEGER NOT NULL UNIQUE, "rate" TEXT NULL, "input_tx_id" TEXT NULL, "output_tx_id" TEXT NULL)',
  'CREATE TABLE "wallet_infos" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, '
      '"seed" TEXT NOT NULL, "address" TEXT NOT NULL, "type" INTEGER NOT NULL)',
  'CREATE TABLE "wallet_account_infos" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, '
      '"account_index" INTEGER NOT NULL, "wallet" INTEGER NOT NULL REFERENCES wallet_infos (id))',
];

void _writeSchema(raw.Database db, int version, List<String> statements) {
  for (final statement in [..._schema(version), ...statements]) {
    db.execute(statement);
  }
  db.execute('PRAGMA user_version = $version');
}

AppDatabase _openSchema(int version, List<String> statements) => AppDatabase.forTesting(
  NativeDatabase.memory(setup: (db) => _writeSchema(db, version, statements)),
);

String _txRow(String txId, {required int type, String sender = '0xA', bool withCategory = true}) =>
    'INSERT INTO transactions (height, tx_id, chain_id, sender_address, receiver_address, amount, asset, type, '
    "${withCategory ? 'category, ' : ''}note, data, time_stamp) "
    "VALUES (1, '$txId', 1, '$sender', '0xB', '100', 1, $type, ${withCategory ? "'', " : ''}'', '', 0)";

String _detailsRow(String txId, {String? inputAmount}) => inputAmount == null
    ? "INSERT INTO dfx_transaction_details (tx_id, dfx_id, rate) VALUES ('$txId', 7, '1.5')"
    : "INSERT INTO dfx_transaction_details (tx_id, dfx_id, rate, input_amount) VALUES ('$txId', 7, '1.5', '$inputAmount')";

Future<int> _userVersion(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

Future<Map<String, int>> _types(AppDatabase db) async {
  final rows = await db.select(db.transactions).get();
  return {for (final row in rows) row.txId: row.type};
}

Future<List<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toList();
}
