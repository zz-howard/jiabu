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

const _icuBranching = {'plural', 'select', 'selectordinal'};

int _closingBrace(String text, int start) {
  var depth = 0;
  for (var index = start; index < text.length; index++) {
    if (text[index] == '{') {
      depth++;
    } else if (text[index] == '}') {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
  }
  throw const FormatException('Unbalanced braces in ARB message');
}

/// Mirrors tool/fonts/subset.py `message_text`: placeholders contribute no
/// characters, plural/select contribute every branch ("#" inside plural is the
/// count) and any other ICU argument is rejected.
String messageText(String message, {bool inPlural = false}) {
  final out = StringBuffer();
  var index = 0;
  while (index < message.length) {
    final char = message[index];
    if (char != '{') {
      if (!(inPlural && char == '#')) {
        out.write(char);
      }
      index++;
      continue;
    }
    final end = _closingBrace(message, index);
    final body = message.substring(index + 1, end);
    final comma = body.indexOf(',');
    if (comma >= 0) {
      final second = body.indexOf(',', comma + 1);
      final kind = second < 0 ? '' : body.substring(comma + 1, second).trim();
      if (second < 0 || !_icuBranching.contains(kind)) {
        throw const FormatException('Add explicit ICU plural/select handling');
      }
      final rest = body.substring(second + 1);
      var position = 0;
      while (position < rest.length) {
        if (rest[position].trim().isEmpty) {
          position++;
          continue;
        }
        final opening = rest.indexOf('{', position);
        if (opening < 0 ||
            !RegExp(r'^=?\w+$')
                .hasMatch(rest.substring(position, opening).trim())) {
          throw const FormatException('Malformed ICU selector');
        }
        final closing = _closingBrace(rest, opening);
        out.write(
          messageText(
            rest.substring(opening + 1, closing),
            inPlural: kind != 'select',
          ),
        );
        position = closing + 1;
      }
    } else if (!RegExp(r'^\w+$').hasMatch(body)) {
      throw const FormatException('Malformed ARB placeholder');
    }
    index = end + 1;
  }
  return out.toString();
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
