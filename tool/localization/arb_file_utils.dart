import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

void appendStringToArbFile(String fileName, String name, String text, {bool force = false}) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  if (arbObj.containsKey(name) && !force) {
    developer.log('String $name already exists in $fileName!');
    return;
  }

  arbObj.addAll({name: text});

  final outputContent = _encodeArbContent(arbObj);

  file.writeAsStringSync(outputContent);
}

void appendStringsToArbFile(String fileName, Map<String, String> strings) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  arbObj.addAll(strings);

  final outputContent = _encodeArbContent(arbObj);

  file.writeAsStringSync(outputContent);
}

Map<String, dynamic> readArbFile(File file) {
  final inputContent = file.readAsStringSync();
  return json.decode(inputContent) as Map<String, dynamic>;
}

String getArbFileName(String lang) {
  final shortLang = lang.split('-').first;
  return './assets/languages/strings_$shortLang.arb';
}

List<String> getMissingKeysInArbFile(String fileName, Iterable<String> langKeys) {
  final file = File(fileName);
  final arbObj = readArbFile(file);
  final results = <String>[];

  for (final langKey in langKeys) {
    if (!arbObj.containsKey(langKey)) {
      results.add(langKey);
    }
  }

  return results;
}

void alphabetizeArbFile(String fileName) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  final sortedKeys = arbObj.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final Map<String, dynamic> sortedArbObj = {};
  for (final key in sortedKeys) {
    sortedArbObj[key] = arbObj[key];
  }

  final outputContent = _encodeArbContent(sortedArbObj);

  file.writeAsStringSync(outputContent);
}

// Committed ARB files end with a newline, so regeneration stays byte-identical.
String _encodeArbContent(Map<String, dynamic> arbObj) {
  final outputContent = json
      .encode(arbObj)
      .replaceAll('","', '",\n  "')
      .replaceAll('{"', '{\n  "')
      .replaceAll('"}', '"\n}')
      .replaceAll('":"', '": "')
      .replaceAll('\$ {', '\${');

  return '$outputContent\n';
}
