import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

class FontCharacterSource {
  const new(this.id, this.file, this.targets, this.codepoints);

  final String id;
  final String file;
  final List<String> targets;
  final Set<int> codepoints;
}

List<String> selectValues(Object? value, List<Object?> path) {
  if (path.isEmpty) {
    if (value is! String) {
      throw const FormatException('JSON selection must end at a string');
    }
    return [value];
  }
  final key = path.first;
  final tail = path.sublist(1);
  if (key == '*') {
    final children = switch (value) {
      Map<Object?, Object?>() => value.values,
      List<Object?>() => value,
      _ => throw const FormatException('Wildcard requires object or array'),
    };
    return [for (final child in children) ...selectValues(child, tail)];
  }
  if (value is List<Object?>) {
    return selectValues(value[int.parse(key.toString())], tail);
  }
  if (value is Map<Object?, Object?> && value.containsKey(key)) {
    return selectValues(value[key], tail);
  }
  throw FormatException('Missing JSON path $key');
}

String messageText(String message) {
  if (RegExp(r'\{\s*\w+\s*,').hasMatch(message)) {
    throw const FormatException('Add explicit ICU plural/select handling');
  }
  return message.replaceAll(RegExp(r'\{\w+\}'), '');
}

List<FontCharacterSource> readFontSources(Directory root) {
  final config = loadYaml(
    File('${root.path}/tool/fonts/char_sources.yaml').readAsStringSync(),
  ) as YamlMap;
  return [
    for (final source in (config['sources']! as YamlList).cast<Object?>())
      _readSource(root, source! as YamlMap),
  ];
}

FontCharacterSource _readSource(Directory root, YamlMap source) {
  final path = source['file']! as String;
  final text = File('${root.path}/$path').readAsStringSync();
  final values = <String>[];
  switch (source['format']) {
    case 'text':
      values.addAll(
        const LineSplitter()
            .convert(text)
            .where(
              (line) =>
                  line.trim().isNotEmpty && !line.trimLeft().startsWith('#'),
            ),
      );
    case 'json':
      final Object? data = jsonDecode(text);
      if (source.containsKey('keyPrefix')) {
        final prefix = source['keyPrefix']! as String;
        final entries = (data! as Map<String, Object?>).entries;
        for (final entry in entries) {
          if (!entry.key.startsWith('@') &&
              entry.key.startsWith(prefix) &&
              entry.value is String) {
            values.add(messageText(entry.value! as String));
          }
        }
      } else {
        values.addAll(
          selectValues(data, (source['path']! as YamlList).cast<Object?>()),
        );
      }
    default:
      throw FormatException('Unknown source format ${source['format']}');
  }
  return FontCharacterSource(
    source['id']! as String,
    path,
    (source['targets']! as YamlList).cast<String>(),
    values.join().replaceAll(RegExp(r'\s'), '').runes.toSet(),
  );
}
