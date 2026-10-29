import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/font_sources.dart';
import 'support/sfnt_cmap.dart';

void main() {
  test('committed fonts match subset_manifest.json byte for byte', () {
    final manifest = jsonDecode(
      File('assets/fonts/subset_manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final fonts = manifest['fonts'] as Map<String, dynamic>;
    expect(fonts.keys.toSet(), {
      'jiabu_hand.ttf',
      'jiabu_numerals.ttf',
      'jiabu_serif.otf',
    });
    for (final entry in fonts.entries) {
      final expected = entry.value as Map<String, dynamic>;
      final bytes = File('assets/fonts/${entry.key}').readAsBytesSync();
      expect(bytes.length, expected['bytes'], reason: entry.key);
      expect(
        sha256.convert(bytes).toString(),
        expected['sha256'],
        reason: '${entry.key} differs from the manifest; rerun subset.py',
      );
    }
  });
  test('every declared source is covered; Caveat never contains Han', () {
    final root = Directory('../..');
    final sources = readFontSources(root);
    final paths = {
      'hand': 'jiabu_hand.ttf',
      'serif': 'jiabu_serif.otf',
      'numerals': 'jiabu_numerals.ttf',
    };
    final fonts = {
      for (final entry in paths.entries)
        entry.key: readCmap(
          File('assets/fonts/${entry.value}').readAsBytesSync(),
        ),
    };
    final missing = <String>[];
    for (final source in sources) {
      for (final target in source.targets) {
        final absent = source.codepoints.difference(fonts[target]!);
        if (absent.isNotEmpty) {
          final codes = absent.toList()..sort();
          missing.add(
            '${source.id} (${source.file}) -> $target: '
            '${codes.map(_describe).join(', ')}',
          );
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
    expect(fonts['numerals']!.where(isHan), isEmpty);
    final manifest = jsonDecode(
      File('assets/fonts/subset_manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final entries = manifest['fonts']! as Map<String, Object?>;
    final specs = jsonDecode(
      File('${root.path}/tool/fonts/sources.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final upstream = specs['fonts']! as Map<String, Object?>;
    for (final path in paths.entries) {
      final entry = entries[path.value]! as Map<String, Object?>;
      final spec = upstream[path.key]! as Map<String, Object?>;
      expect(entry['codepoint_count'], fonts[path.key]!.length);
      expect(entry['bytes'], File('assets/fonts/${path.value}').lengthSync());
      expect(entry['source_sha256'], spec['sha256']);
      expect(entry['source_url'], spec['url']);
    }
  });
  test('every production HandText call uses a hand-prefixed ARB getter', () {
    final root = Directory('../../app/lib');
    final invalid = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'\bHandText\s*\(\s*([^,\n\)]+)',
      ).allMatches(source)) {
        final argument = match.group(1) ?? '';
        final catalogHelper =
            entity.path.contains('/features/catalog/') &&
            argument.trimLeft().startsWith('_l(');
        if (!RegExp(r'\.hand[A-Z]').hasMatch(argument) &&
            !argument.contains('AppLocalizations.of') &&
            !catalogHelper) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          invalid.add('${entity.path}:$line: $argument');
        }
      }
    }
    expect(invalid, isEmpty, reason: invalid.join('\n'));
  });
}

String _describe(int code) {
  final hex = code.toRadixString(16).toUpperCase().padLeft(4, '0');
  return '${String.fromCharCode(code)} U+$hex';
}
