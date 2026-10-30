import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// A source or dependency policy violation.
class Violation {
  const Violation(this.file, this.line, this.rule, this.message);

  final String file;
  final int line;
  final int rule;
  final String message;

  @override
  String toString() => '$file:$line: rule $rule: $message';
}

void main(List<String> arguments) {
  if (arguments.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/check_rules.dart [workspace-directory]',
    );
    exitCode = 1;
    return;
  }
  final root = arguments.isEmpty
      ? Directory.current
      : Directory(arguments.single);
  final violations = scanProject(root)..forEach(stderr.writeln);
  if (violations.isNotEmpty) {
    exitCode = 1;
  } else {
    stdout.writeln('Client rules passed.');
  }
}

/// Checks production libraries and every workspace dependency declaration.
List<Violation> scanProject(Directory root) {
  final violations = <Violation>[];
  final packages = _readPackages(root, violations);
  _checkDependencies(root, packages, violations);
  for (final package in packages.entries) {
    if (package.value.isEmpty) {
      continue;
    }
    final library = Directory('${root.path}/${package.value}/lib');
    if (!library.existsSync()) {
      continue;
    }
    final files = library.listSync(recursive: true, followLinks: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    for (final entity in files) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      final file = _relative(root, entity.path);
      final original = entity.readAsStringSync();
      final source = _withoutComments(original);
      _checkSource(file, source, original, packages, violations);
    }
  }
  return violations;
}

Map<String, String> _readPackages(Directory root, List<Violation> violations) {
  final packages = <String, String>{};
  final rootManifest = _readManifest(root, 'pubspec.yaml', violations);
  if (rootManifest == null) {
    return packages;
  }
  final name = rootManifest['name'];
  if (name is String) {
    packages[name] = '';
  }
  final workspace = rootManifest['workspace'];
  if (workspace is! YamlList) {
    violations.add(
      const Violation('pubspec.yaml', 1, 7, 'Missing workspace package list.'),
    );
    return packages;
  }
  for (final Object? member in workspace) {
    if (member is! String ||
        member.startsWith('/') ||
        member.split('/').contains('..')) {
      violations.add(
        const Violation('pubspec.yaml', 1, 7, 'Invalid workspace member path.'),
      );
      continue;
    }
    final manifest = _readManifest(root, '$member/pubspec.yaml', violations);
    final memberName = manifest?['name'];
    if (memberName is String) {
      packages[memberName] = _normalize(member);
    } else {
      violations.add(
        Violation('$member/pubspec.yaml', 1, 7, 'Missing package name.'),
      );
    }
  }
  return packages;
}

YamlMap? _readManifest(
  Directory root,
  String path,
  List<Violation> violations,
) {
  final file = File('${root.path}/$path');
  if (!file.existsSync()) {
    violations.add(Violation(path, 1, 7, 'Missing manifest.'));
    return null;
  }
  try {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is YamlMap) {
      return document;
    }
    violations.add(Violation(path, 1, 7, 'Expected a YAML mapping.'));
  } on YamlException catch (error) {
    violations.add(Violation(path, 1, 7, 'Invalid YAML: $error'));
  }
  return null;
}

void _checkDependencies(
  Directory root,
  Map<String, String> packages,
  List<Violation> violations,
) {
  const allowedPath = 'tool/allowed_deps.yaml';
  final allowlist = _readManifest(root, allowedPath, violations);
  final Object? allowedPackages = allowlist?['packages'];
  if (allowedPackages is! YamlMap) {
    violations.add(
      const Violation(allowedPath, 1, 7, 'Missing dependency allowlist.'),
    );
    return;
  }
  for (final package in packages.entries) {
    final path = package.value.isEmpty
        ? 'pubspec.yaml'
        : '${package.value}/pubspec.yaml';
    final manifest = _readManifest(root, path, violations);
    if (manifest == null) {
      continue;
    }
    final manifestSource = File('${root.path}/$path').readAsStringSync();
    final Object? allowedPackage = allowedPackages[package.key];
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final Object? dependencies = manifest[section];
      if (dependencies == null) {
        continue;
      }
      if (dependencies is! YamlMap) {
        violations.add(Violation(path, 1, 7, 'Invalid $section mapping.'));
        continue;
      }
      final Object? allowedSection = allowedPackage is YamlMap
          ? allowedPackage[section]
          : null;
      for (final entry in dependencies.entries) {
        final Object? expected = allowedSection is YamlMap
            ? allowedSection[entry.key]
            : null;
        final allowed =
            allowedSection is YamlMap &&
            allowedSection.containsKey(entry.key) &&
            _canonical(expected) == _canonical(entry.value);
        if (!allowed) {
          violations.add(
            Violation(
              path,
              _dependencyLine(dependencies, entry.key, manifestSource),
              7,
              'Unapproved $section entry ${entry.key}; '
              'request review of $allowedPath.',
            ),
          );
        }
      }
    }
  }
}

// YamlMap.nodes exposes value-node spans. A block value can start below its
// key, so locate the key at the enclosing mapping's indentation instead.
int _dependencyLine(YamlMap dependencies, Object? name, String source) {
  final key = RegExp.escape(name.toString());
  final keyPattern = RegExp(
    '''^([ \t]*)(?:$key|"$key"|'$key')\\s*:''',
    multiLine: true,
  );
  final start = dependencies.span.start;
  final end = dependencies.span.end;
  for (final match in keyPattern.allMatches(source)) {
    final indentation = match.group(1)?.length ?? 0;
    final keyOffset = match.start + indentation;
    if (keyOffset >= start.offset &&
        keyOffset < end.offset &&
        indentation == start.column) {
      return '\n'.allMatches(source.substring(0, keyOffset)).length + 1;
    }
  }
  // Flow mappings can share a line; their value span is a suitable fallback.
  final node = dependencies.nodes[name];
  return node == null ? start.line + 1 : node.span.start.line + 1;
}

String _canonical(Object? value) {
  if (value is YamlMap) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return jsonEncode({for (final key in keys) key: _canonical(value[key])});
  }
  if (value is YamlList) {
    return jsonEncode(value.map(_canonical).toList());
  }
  return jsonEncode(value);
}

final _colorLiteral = RegExp(
  r'\bColor\s*\(\s*(?:0[xX]|\d)|'
  r'\bColor\s*\.\s*(?:fromARGB|fromRGBO|from)\s*\(|'
  r'\bColors\s*\.',
);
final _appLiteral = RegExp(r'\bColor\s*[.(]|\bColors\s*\.|\bfontFamily\s*:');
final _rotation = RegExp(
  r'\bTransform\s*\.\s*rotate\b|\bRotationTransition\b|'
  r'\bMatrix4\s*\.\s*rotationZ\b|\bRotatedBox\b|'
  r'\bcanvas\s*(?:\.|\.\.)\s*rotate\s*\(|\.\.\s*rotate\s*\(',
);

void _checkSource(
  String file,
  String source,
  String original,
  Map<String, String> packages,
  List<Violation> violations,
) {
  void report(int rule, int offset, String message) {
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    violations.add(Violation(file, line, rule, message));
  }

  final isDesign = file.startsWith('packages/jiabu_design/lib/');
  final isUi = RegExp('^app/lib/(?:app|features|shared)/').hasMatch(file);
  final feature = _feature(file);
  if (isDesign && file != 'packages/jiabu_design/lib/src/tokens/colors.dart') {
    for (final match in _colorLiteral.allMatches(source)) {
      report(1, match.start, 'Color literals belong in tokens/colors.dart.');
    }
  }
  if (file != 'packages/jiabu_design/lib/src/tokens/type.dart' &&
      !file.contains('/lib/features/settings/')) {
    for (final match in RegExp(r'\.\s*mono\b').allMatches(source)) {
      report(8, match.start, 'JiabuType.mono is only for settings API keys.');
    }
  }

  if (!isDesign) {
    // Everything outside jiabu_design (features, data, app, shared, …) uses
    // tokens: AGENTS.md forbids Color/Colors/fontFamily/Duration literals.
    for (final match in _appLiteral.allMatches(source)) {
      report(1, match.start, 'Use design tokens instead of UI literals.');
    }
  }
  if (isUi) {
    _checkSpacingLiterals(source, original, report);
    _checkSectionHeaders(source, report);
    _checkLazyLayoutComponents(source, report);
    for (final match in RegExp(
      r'\bPaperSheet(?:\s*\.\s*show)?\b',
    ).allMatches(source)) {
      report(10, match.start, 'Use JiabuSheet in production UI.');
    }
  }
  if (!isDesign && file != 'app/lib/data/sync/sync_policy.dart') {
    for (final match in RegExp(r'\bDuration\s*\(').allMatches(source)) {
      report(1, match.start, 'Technical durations belong in sync_policy.dart.');
    }
  }
  if (!file.startsWith('app/lib/data/db/')) {
    for (final match in RegExp(
      r'\b(?:customSelect|customStatement|customUpdate|customInsert|selectOnly)'
      r'\s*\(',
    ).allMatches(source)) {
      report(9, match.start, 'Database access belongs in scoped DAOs.');
    }
  }
  if (file != 'packages/jiabu_design/lib/src/components/tilt.dart' &&
      !file.startsWith('packages/jiabu_design/lib/src/geometry/')) {
    for (final match in _rotation.allMatches(source)) {
      report(2, match.start, 'Use jiabu_design Tilt for decoration rotation.');
    }
  }
  for (final match in RegExp(
    r'\b(?:StateProvider|StateNotifier|StateNotifierProvider|'
    r'ChangeNotifierProvider)\b',
  ).allMatches(source)) {
    report(4, match.start, 'Riverpod legacy APIs are forbidden.');
  }
  final isView =
      file.contains('/view/') ||
      file.endsWith('_screen.dart') ||
      file.endsWith('_view.dart');
  for (final directive in RegExp(
    r'\b(?:import|export)\s+[^;]*;',
    dotAll: true,
  ).allMatches(source)) {
    for (final uri in RegExp(
      '''['"]([^'"]+)['"]''',
    ).allMatches(directive.group(0) ?? '')) {
      final value = uri.group(1) ?? '';
      final offset = directive.start + uri.start;
      final parsed = Uri.tryParse(value);
      final importedPackage = parsed?.scheme == 'package'
          ? parsed?.pathSegments.firstOrNull
          : null;
      if (importedPackage != null &&
          (_forbiddenPackages.contains(importedPackage) ||
              importedPackage.startsWith('firebase_'))) {
        report(3, offset, 'Forbidden package: $importedPackage.');
      }
      if (value.startsWith('package:riverpod/') ||
          value.startsWith('package:flutter_riverpod/') ||
          value.startsWith('package:hooks_riverpod/')) {
        if (value.endsWith('/legacy.dart')) {
          report(4, offset, 'Riverpod legacy imports are forbidden.');
        }
      }
      final target = _resolveImport(file, value, packages);
      if (target == null) {
        continue;
      }
      final targetFeature = _feature(target);
      if (feature != null &&
          targetFeature != null &&
          feature != targetFeature) {
        report(5, offset, 'Feature $feature cannot import $targetFeature.');
      }
      if (isView && RegExp('(?:^|/)lib/data/').hasMatch(target)) {
        report(6, offset, 'Views cannot import the data layer.');
      }
    }
  }
}

void _checkLazyLayoutComponents(
  String source,
  void Function(int rule, int offset, String message) report,
) {
  final reportedComponents = <int>{};
  final lazyConstructors = RegExp(
    r'\b(?:ListView\s*\.\s*builder|SliverList|SliverChildBuilderDelegate)\s*\(',
  );
  for (final lazy in lazyConstructors.allMatches(source)) {
    final close = _matchingParen(source, lazy.end - 1);
    if (close == null) {
      continue;
    }
    final body = source.substring(lazy.end, close);
    final component = RegExp(
      r'\bJiabu(?:Stack|ChipGroup)\s*\(',
    ).firstMatch(body);
    final componentOffset = component == null
        ? null
        : lazy.end + component.start;
    if (componentOffset != null && reportedComponents.add(componentOffset)) {
      report(
        12,
        componentOffset,
        'JiabuStack and JiabuChipGroup cannot be lazy delegate items; '
        'use non-lazy content or test every scrolled segment.',
      );
    }
  }
}

void _checkSectionHeaders(
  String source,
  void Function(int rule, int offset, String message) report,
) {
  final wrappers = <(int, int)>[];
  for (final match in RegExp(
    r'\bJiabuStackItem\s*\.\s*section\s*\(',
  ).allMatches(source)) {
    final close = _matchingParen(source, match.end - 1);
    if (close != null) {
      wrappers.add((match.start, close));
    }
  }
  for (final match in RegExp(r'\bJiabuSectionHeader\s*\(').allMatches(source)) {
    final wrapped = wrappers.any(
      (range) => range.$1 < match.start && match.end <= range.$2,
    );
    if (!wrapped) {
      report(
        11,
        match.start,
        'JiabuSectionHeader must be a JiabuStackItem.section.',
      );
    }
  }
}

void _checkSpacingLiterals(
  String source,
  String original,
  void Function(int rule, int offset, String message) report,
) {
  final constructors = <(RegExp, String, bool)>[
    (
      RegExp(
        r'\bEdgeInsets(?:Directional)?\s*\.\s*'
        r'(?:all|only|symmetric|fromLTRB|fromSTEB)\s*\(',
      ),
      'Use JiabuSpacing instead of literal EdgeInsets.',
      false,
    ),
    (
      RegExp(
        r'\b(?:[A-Za-z_]\w*)?(?:padding|margin)\s*:\s*'
        r'(?:const\s+)?\.\s*'
        r'(?:all|only|symmetric|fromLTRB|fromSTEB)\s*\(',
        caseSensitive: false,
      ),
      'Use JiabuSpacing instead of literal EdgeInsets.',
      false,
    ),
    (
      RegExp(r'\bSizedBox(?:\s*\.\s*(?:square|fromSize))?\s*\('),
      'Use JiabuSpacing instead of literal SizedBox spacing.',
      true,
    ),
  ];
  final nonZero = RegExp(r'(?<![\w.])(?:[1-9]\d*(?:\.\d+)?|0\.\d*[1-9]\d*)');
  for (final entry in constructors) {
    for (final match in entry.$1.allMatches(source)) {
      final openParen = match.end - 1;
      final closeParen = _matchingParen(source, openParen);
      if (closeParen == null) {
        continue;
      }
      final bodyStart = openParen + 1;
      final body = source.substring(bodyStart, closeParen);
      final constructor = match.group(0) ?? '';
      final fromSize = entry.$3 && constructor.contains('fromSize');
      final numbers = entry.$3
          ? _namedArgumentNumberOffsets(
              body,
              fromSize
                  ? const {'size'}
                  : const {'width', 'height', 'dimension'},
              nonZero,
            )
          : nonZero.allMatches(body).map((match) => match.start);
      for (final numberOffset in numbers) {
        final offset = bodyStart + numberOffset;
        if (!_hasLiteralAllowance(original, offset)) {
          report(10, offset, entry.$2);
        }
      }
    }
  }
}

Iterable<int> _namedArgumentNumberOffsets(
  String body,
  Set<String> names,
  RegExp number,
) sync* {
  var start = 0;
  var parentheses = 0;
  var brackets = 0;
  var braces = 0;
  String? quote;
  for (var index = 0; index <= body.length; index++) {
    final atEnd = index == body.length;
    final current = atEnd ? '' : body[index];
    if (quote != null) {
      if (current == r'\') {
        index++;
      } else if (current == quote) {
        quote = null;
      }
      continue;
    }
    if (current == "'" || current == '"') {
      quote = current;
      continue;
    }
    if (current == '(') {
      parentheses++;
    } else if (current == ')') {
      parentheses--;
    } else if (current == '[') {
      brackets++;
    } else if (current == ']') {
      brackets--;
    } else if (current == '{') {
      braces++;
    } else if (current == '}') {
      braces--;
    }
    final separator =
        atEnd ||
        (current == ',' && parentheses == 0 && brackets == 0 && braces == 0);
    if (!separator) {
      continue;
    }
    final argument = body.substring(start, index);
    final named = RegExp(r'^\s*([A-Za-z_]\w*)\s*:').firstMatch(argument);
    if (named != null && names.contains(named.group(1))) {
      for (final match in number.allMatches(argument, named.end)) {
        yield start + match.start;
      }
    }
    start = index + 1;
  }
}

int? _matchingParen(String source, int openParen) {
  var depth = 1;
  var index = openParen + 1;
  String? quote;
  var triple = false;
  while (index < source.length) {
    final current = source[index];
    if (quote != null) {
      if (current == r'\') {
        index += 2;
        continue;
      }
      final delimiter = triple ? '$quote$quote$quote' : quote;
      if (source.startsWith(delimiter, index)) {
        index += delimiter.length;
        quote = null;
      } else {
        index++;
      }
      continue;
    }
    if (current == "'" || current == '"') {
      quote = current;
      triple = source.startsWith('$current$current$current', index);
      index += triple ? 3 : 1;
      continue;
    }
    if (current == '(') {
      depth++;
    } else if (current == ')') {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
    index++;
  }
  return null;
}

bool _hasLiteralAllowance(String source, int offset) {
  final lineStart = source.lastIndexOf('\n', offset - 1) + 1;
  final lineEnd = source.indexOf('\n', offset);
  final line = source.substring(
    lineStart,
    lineEnd < 0 ? source.length : lineEnd,
  );
  return RegExp(r'//\s*rules:allow-literal\s+\S.*$').hasMatch(line);
}

const _forbiddenPackages = <String>{
  'http',
  'google_fonts',
  'sqlite3_flutter_libs',
  'isar',
  'get',
};

String? _feature(String path) =>
    RegExp('(?:^|/)lib/features/([^/]+)/').firstMatch(path)?.group(1);

String? _resolveImport(
  String file,
  String value,
  Map<String, String> packages,
) {
  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }
  if (uri.scheme == 'package') {
    final parts = uri.pathSegments;
    if (parts.length < 2) {
      return null;
    }
    final package = packages[parts.first];
    if (package == null) {
      return null;
    }
    return _normalize('$package/lib/${parts.skip(1).join('/')}');
  }
  if (uri.hasScheme || value.startsWith('/')) {
    return null;
  }
  final parent = file.substring(0, file.lastIndexOf('/'));
  return _normalize('$parent/$value');
}

String _relative(Directory root, String path) {
  final base = _normalize(root.absolute.path);
  final absolute = _normalize(File(path).absolute.path);
  return base.isEmpty ? absolute : absolute.substring(base.length + 1);
}

String _normalize(String path) {
  final parts = <String>[];
  for (final part in path.replaceAll(r'\', '/').split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}

// Preserve offsets and newlines so diagnostics point into the original file.
String _withoutComments(String source) {
  final result = source.split('');
  var index = 0;
  String? quote;
  var triple = false;
  while (index < source.length) {
    final current = source[index];
    if (quote != null) {
      if (current == r'\') {
        index += 2;
        continue;
      }
      final delimiter = triple ? '$quote$quote$quote' : quote;
      if (source.startsWith(delimiter, index)) {
        index += delimiter.length;
        quote = null;
      } else {
        index++;
      }
      continue;
    }
    if (current == "'" || current == '"') {
      quote = current;
      triple = source.startsWith('$current$current$current', index);
      index += triple ? 3 : 1;
      continue;
    }
    if (source.startsWith('//', index)) {
      while (index < source.length && source[index] != '\n') {
        result[index++] = ' ';
      }
      continue;
    }
    if (source.startsWith('/*', index)) {
      var depth = 1;
      result[index++] = ' ';
      result[index++] = ' ';
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth++;
          result[index++] = ' ';
          result[index++] = ' ';
        } else if (source.startsWith('*/', index)) {
          depth--;
          result[index++] = ' ';
          result[index++] = ' ';
        } else {
          if (source[index] != '\n') {
            result[index] = ' ';
          }
          index++;
        }
      }
      continue;
    }
    index++;
  }
  return result.join();
}
