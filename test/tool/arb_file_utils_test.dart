// Committed language files end with a newline; if a writer drops it, regeneration dirties
// the working tree and aborts the mandatory author report.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/arb_file_utils.dart';

void main() {
  group('alphabetizeArbFile', () {
    test('regression: canonical generator output is rewritten byte-identically', () {
      final tempDir = Directory.systemTemp.createTempSync('arb_file_utils_test_');
      final file = File('${tempDir.path}/strings.arb');
      const canonicalContent =
          '{\n'
          '  "alpha": "A",\n'
          '  "Beta": "B",\n'
          '  "gamma": "G"\n'
          '}\n';

      try {
        file.writeAsStringSync(canonicalContent);

        alphabetizeArbFile(file.path);

        expect(file.readAsStringSync(), canonicalContent);
      } finally {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('sorts case-insensitively and adds exactly one trailing newline', () {
      final tempDir = Directory.systemTemp.createTempSync('arb_file_utils_test_');
      final file = File('${tempDir.path}/strings.arb');

      try {
        file.writeAsStringSync('{"gamma":"G","Beta":"B","alpha":"A"}');

        alphabetizeArbFile(file.path);

        final contents = file.readAsStringSync();
        expect(readArbFile(file).keys, orderedEquals(['alpha', 'Beta', 'gamma']));
        expect(contents, endsWith('}\n'));
        expect(contents, isNot(endsWith('\n\n')));
      } finally {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('is byte-identical when run twice', () {
      final tempDir = Directory.systemTemp.createTempSync('arb_file_utils_test_');
      final file = File('${tempDir.path}/strings.arb');

      try {
        file.writeAsStringSync('{"gamma":"G","alpha":"A","Beta":"B"}');
        alphabetizeArbFile(file.path);
        final firstRun = file.readAsBytesSync();

        alphabetizeArbFile(file.path);

        expect(file.readAsBytesSync(), firstRun);
      } finally {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });
  });

  test('appendStringToArbFile preserves overwrite behaviour and one trailing newline', () {
    final tempDir = Directory.systemTemp.createTempSync('arb_file_utils_test_');
    final file = File('${tempDir.path}/strings.arb');

    try {
      file.writeAsStringSync('{"alpha":"original"}');

      appendStringToArbFile(file.path, 'Beta', 'B');
      final afterAppend = file.readAsStringSync();
      expect(afterAppend, endsWith('}\n'));
      expect(afterAppend, isNot(endsWith('\n\n')));

      appendStringToArbFile(file.path, 'alpha', 'ignored');
      expect(file.readAsStringSync(), afterAppend);
      expect(readArbFile(file)['alpha'], 'original');

      appendStringToArbFile(file.path, 'alpha', 'replacement', force: true);
      final afterForce = file.readAsStringSync();
      expect(readArbFile(file)['alpha'], 'replacement');
      expect(afterForce, endsWith('}\n'));
      expect(afterForce, isNot(endsWith('\n\n')));
    } finally {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });

  test('appendStringsToArbFile adds exactly one trailing newline', () {
    final tempDir = Directory.systemTemp.createTempSync('arb_file_utils_test_');
    final file = File('${tempDir.path}/strings.arb');

    try {
      file.writeAsStringSync('{"gamma":"G"}');

      appendStringsToArbFile(file.path, {'alpha': 'A', 'Beta': 'B'});

      final contents = file.readAsStringSync();
      expect(contents, endsWith('}\n'));
      expect(contents, isNot(endsWith('\n\n')));
    } finally {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });
}
