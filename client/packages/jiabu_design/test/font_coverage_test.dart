import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/font_sources.dart';
import 'support/sfnt_cmap.dart';

void main() {
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
}

String _describe(int code) {
  final hex = code.toRadixString(16).toUpperCase().padLeft(4, '0');
  return '${String.fromCharCode(code)} U+$hex';
}
