import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:realunit_wallet/packages/io/backup_exclusion_port.dart';
import 'package:realunit_wallet/packages/io/documents_directory_port.dart';
import 'package:realunit_wallet/packages/storage/database.dart';

/// Returns a caller-supplied [Directory] in place of
/// `path_provider.getApplicationDocumentsDirectory`. Each invocation is
/// counted so the test can assert that `getDatabasePath` reaches the port
/// exactly once.
class _FakeDocumentsDirectoryPort implements DocumentsDirectoryPort {
  _FakeDocumentsDirectoryPort(this.docsDirectory);

  final Directory docsDirectory;
  int docsCalls = 0;
  int tempCalls = 0;

  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    docsCalls++;
    return docsDirectory;
  }

  @override
  Future<Directory> getTemporaryDirectory() async {
    tempCalls++;
    return docsDirectory;
  }
}

void main() {
  group('AppDatabase.getDatabasePath', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_database_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('joins the port-provided documents dir with the SQLCipher filename', () async {
      final port = _FakeDocumentsDirectoryPort(tempDir);

      final path = await AppDatabase.getDatabasePath(port);

      expect(path, p.join(tempDir.path, 'wallet.db.enc'));
      expect(port.docsCalls, 1);
      expect(port.tempCalls, 0);
    });

    test('uses the port for every call (no caching of the resolved path)', () async {
      final port = _FakeDocumentsDirectoryPort(tempDir);

      await AppDatabase.getDatabasePath(port);
      await AppDatabase.getDatabasePath(port);

      expect(port.docsCalls, 2);
    });

    test('honours a port that hands back a different directory per call', () async {
      final firstDir = Directory.systemTemp.createTempSync('app_database_first_');
      final secondDir = Directory.systemTemp.createTempSync('app_database_second_');
      addTearDown(() {
        if (firstDir.existsSync()) firstDir.deleteSync(recursive: true);
        if (secondDir.existsSync()) secondDir.deleteSync(recursive: true);
      });

      final dirs = <Directory>[firstDir, secondDir];
      final port = _RotatingDocumentsDirectoryPort(dirs);

      final firstPath = await AppDatabase.getDatabasePath(port);
      final secondPath = await AppDatabase.getDatabasePath(port);

      expect(firstPath, p.join(firstDir.path, 'wallet.db.enc'));
      expect(secondPath, p.join(secondDir.path, 'wallet.db.enc'));
    });
  });

  group('AppDatabase.excludeDatabaseFromBackup', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_database_backup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('excludes the db file and its wal/shm/journal sidecars in place', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);
      final exclusionPort = _RecordingBackupExclusionPort();

      await AppDatabase.excludeDatabaseFromBackup(exclusionPort, dirPort);

      final dbPath = p.join(tempDir.path, 'wallet.db.enc');
      expect(exclusionPort.calls, hasLength(1));
      expect(exclusionPort.calls.single, [
        dbPath,
        '$dbPath-wal',
        '$dbPath-shm',
        '$dbPath-journal',
      ]);
      // The database keeps its resolved documents-dir path — the exclusion is
      // applied in place, with no move (and therefore no migration risk).
      expect(exclusionPort.calls.single.first, dbPath);
    });

    test('resolves the path through the documents port (no hard-coded location)', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);
      final exclusionPort = _RecordingBackupExclusionPort();

      await AppDatabase.excludeDatabaseFromBackup(exclusionPort, dirPort);

      expect(dirPort.docsCalls, 1);
    });
  });

  group('AppDatabase.deleteDatabaseFiles', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_database_delete_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deletes the main file and all existing sidecars', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);
      final dbPath = p.join(tempDir.path, 'wallet.db.enc');
      File(dbPath).writeAsStringSync('main');
      File('$dbPath-wal').writeAsStringSync('wal');
      File('$dbPath-shm').writeAsStringSync('shm');
      File('$dbPath-journal').writeAsStringSync('journal');

      await AppDatabase.deleteDatabaseFiles(dirPort);

      expect(File(dbPath).existsSync(), isFalse);
      expect(File('$dbPath-wal').existsSync(), isFalse);
      expect(File('$dbPath-shm').existsSync(), isFalse);
      expect(File('$dbPath-journal').existsSync(), isFalse);
    });

    test('is a no-op when nothing exists', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);

      await expectLater(AppDatabase.deleteDatabaseFiles(dirPort), completes);
    });

    test('deletes the main file when only it exists', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);
      final dbPath = p.join(tempDir.path, 'wallet.db.enc');
      File(dbPath).writeAsStringSync('main');

      await AppDatabase.deleteDatabaseFiles(dirPort);

      expect(File(dbPath).existsSync(), isFalse);
    });

    test('leaves unrelated files in the directory alone', () async {
      final dirPort = _FakeDocumentsDirectoryPort(tempDir);
      final dbPath = p.join(tempDir.path, 'wallet.db.enc');
      File(dbPath).writeAsStringSync('main');
      final other = File(p.join(tempDir.path, 'notes.txt'))..writeAsStringSync('keep');

      await AppDatabase.deleteDatabaseFiles(dirPort);

      expect(File(dbPath).existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(other.readAsStringSync(), 'keep');
    });
  });
}

/// Records every [excludeFromBackup] invocation so tests can assert the exact
/// set of paths handed to the platform boundary.
class _RecordingBackupExclusionPort implements BackupExclusionPort {
  final List<List<String>> calls = <List<String>>[];

  @override
  Future<void> excludeFromBackup(List<String> paths) async {
    calls.add(paths);
  }
}

/// Hands back each directory in [_directories] in turn; pins that
/// `getDatabasePath` re-resolves the docs dir on every call rather than
/// memoising it.
class _RotatingDocumentsDirectoryPort implements DocumentsDirectoryPort {
  _RotatingDocumentsDirectoryPort(this._directories);

  final List<Directory> _directories;
  int _index = 0;

  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    final dir = _directories[_index];
    _index++;
    return dir;
  }

  @override
  Future<Directory> getTemporaryDirectory() async => _directories[_index];
}
