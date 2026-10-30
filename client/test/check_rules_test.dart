import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_rules.dart';

void main() {
  late Directory workspace;

  void write(String path, String contents) {
    final file = File('${workspace.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  List<Violation> violationsFor(int rule) {
    return scanProject(workspace)
        .where((violation) => violation.rule == rule)
        .toList();
  }

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('jiabu-rules-');
    write('pubspec.yaml', '''
name: jiabu_workspace
workspace:
  - app
  - packages/jiabu_design
''');
    write('app/pubspec.yaml', '''
name: jiabu
dependencies:
  flutter: {sdk: flutter}
''');
    write('packages/jiabu_design/pubspec.yaml', 'name: jiabu_design\n');
    write('tool/allowed_deps.yaml', '''
packages:
  jiabu:
    dependencies:
      flutter: {sdk: flutter}
''');
  });

  tearDown(() {
    workspace.deleteSync(recursive: true);
  });

  test('rule 1 rejects literal UI values with source locations', () {
    const path = 'app/lib/features/home/home_screen.dart';
    write(path, '// A comment.\nfinal color = Color(0xff000000);\n');
    final violations = violationsFor(1);
    expect(violations, hasLength(1));
    expect(violations.single.file, path);
    expect(violations.single.line, 2);
  });

  test('rule 1 rejects the remaining literal forms across whitespace', () {
    write('app/lib/data/example.dart', '''
final color = Colors.red;
final font = TextStyle(fontFamily: 'Example');
final delay = Duration(
  milliseconds: 100,
);
''');
    expect(violationsFor(1), hasLength(3));
  });

  test('rule 2 rejects direct rotation', () {
    write(
      'app/lib/features/home/home_screen.dart',
      'final decoration = Transform.rotate(angle: 0);\n',
    );
    expect(violationsFor(2), hasLength(1));
  });

  test('rule 3 rejects forbidden imports and conditional exports', () {
    write('app/lib/shared/example.dart', '''
import 'package:http/http.dart';
export 'example.dart'
  if (dart.library.io) {
    'package:firebase_core/firebase_core.dart';
  }
''');
    expect(violationsFor(3), hasLength(2));
  });

  test('rule 4 rejects legacy Riverpod APIs and imports', () {
    write('app/lib/features/home/home_view_model.dart', '''
import 'package:flutter_riverpod/legacy.dart';
final state = StateProvider<int>((ref) => 0);
''');
    expect(violationsFor(4), hasLength(2));
  });

  test('rule 5 rejects cross-feature package imports', () {
    write(
      'app/lib/features/home/home_view_model.dart',
      "import 'package:jiabu/features/settings/settings_view_model.dart';\n",
    );
    expect(violationsFor(5), hasLength(1));
  });

  test('rule 5 resolves relative imports before comparing features', () {
    write(
      'app/lib/features/home/view/home_screen.dart',
      "import '../../settings/settings_view_model.dart';\n",
    );
    expect(violationsFor(5), hasLength(1));
  });

  test('rule 6 rejects data imports in views', () {
    write(
      'app/lib/features/home/view/home_screen.dart',
      "import '../../../data/home_repository.dart';\n",
    );
    expect(violationsFor(6), hasLength(1));
  });

  test('rule 6 also recognizes screen and view file suffixes', () {
    write(
      'app/lib/features/home/home_screen.dart',
      "import 'package:jiabu/data/home_repository.dart';\n",
    );
    write(
      'app/lib/features/home/home_view.dart',
      "import 'package:jiabu/data/home_repository.dart';\n",
    );
    expect(violationsFor(6), hasLength(2));
  });

  test('rule 7 rejects dependencies absent from the allowlist', () {
    write('app/pubspec.yaml', '''
name: jiabu
dependencies:
  flutter: {sdk: flutter}
  unreviewed_package: ^1.0.0
''');
    final violations = violationsFor(7);
    expect(violations, hasLength(1));
    expect(violations.single.file, 'app/pubspec.yaml');
    expect(violations.single.line, 4);
  });

  test('rule 7 locates quoted keys before multiline dependency values', () {
    const lines = [
      'name: jiabu',
      'dependencies:',
      '  flutter: {sdk: flutter}',
      '  "unreviewed_package":',
      '    path: ../unreviewed_package',
    ];
    write('app/pubspec.yaml', '${lines.join('\n')}\n');
    final violations = violationsFor(7);
    expect(violations, hasLength(1));
    expect(violations.single.line, 4);
    final sourceLines = File('${workspace.path}/app/pubspec.yaml')
        .readAsLinesSync();
    expect(
      sourceLines[violations.single.line - 1].trim(),
      '"unreviewed_package":',
    );
  });

  test('rule 7 checks root dev dependencies and overrides', () {
    write('pubspec.yaml', '''
name: jiabu_workspace
workspace:
  - app
  - packages/jiabu_design
dev_dependencies:
  unreviewed_package: ^1.0.0
dependency_overrides:
  flutter: {path: /tmp/another-flutter}
''');
    expect(violationsFor(7), hasLength(2));
  });

  test('rule 7 rejects changed dependency sources and versions', () {
    write('app/pubspec.yaml', '''
name: jiabu
dependencies:
  flutter: {path: /tmp/another-flutter}
''');
    expect(violationsFor(7), hasLength(1));
  });

  test('allows tokens, design implementation and same-feature imports', () {
    write(
      'packages/jiabu_design/lib/src/tokens/colors.dart',
      'final color = Color(0xff000000);',
    );
    write(
      'packages/jiabu_design/lib/src/components/tilt.dart',
      'final decoration = Transform.rotate(angle: 0);',
    );
    write('app/lib/features/home/view/home_screen.dart', '''
// Colors.red and StateProvider must not match in comments.
/* Transform.rotate must not match in comments either. */
import '../home_view_model.dart';
import 'package:get_it/get_it.dart';
final color = context.jiabu.accent;
''');
    write(
      'app/lib/features/home/home_view_model.dart',
      "import '../../data/home_repository.dart';\n",
    );
    expect(scanProject(workspace), isEmpty);
  });

  test('mono is restricted to settings, including context token access', () {
    write(
      'app/lib/features/home/view/home_screen.dart',
      'final a = JiabuType.mono; final b = context.jiabu.type.mono;',
    );
    expect(violationsFor(8), hasLength(2));
    write(
      'app/lib/features/settings/view/key_screen.dart',
      'final a = context.jiabu.type.mono;',
    );
    expect(violationsFor(8), hasLength(2));
  });

  test('only the color token and Tilt may implement literals and rotation', () {
    write(
      'packages/jiabu_design/lib/src/components/example.dart',
      'final a = Color(0xff000000); '
          'final b = Transform.rotate(angle: 0);',
    );
    expect(violationsFor(1), hasLength(1));
    expect(violationsFor(2), hasLength(1));
  });

  test('rule 10 rejects literal spacing and accepts tokens and zero', () {
    const path = 'app/lib/features/home/home_screen.dart';
    write(path, '''
final bad = Padding(padding: EdgeInsets.all(18));
final gap = SizedBox(height: 12);
final zero = EdgeInsets.only(left: 0);
final good = EdgeInsets.all(context.jiabu.spacing.page);
final nested = SizedBox(child: Widget(width: 18));
''');
    expect(violationsFor(10), hasLength(2));
    write(path, '''
final zero = EdgeInsets.only(left: 0);
final good = EdgeInsets.all(context.jiabu.spacing.page);
''');
    expect(violationsFor(10), isEmpty);
  });

  const nestedInsetSource =
      'final inset = EdgeInsets.only( '
      'left: MediaQuery.paddingOf(context).left, right: 18);';
  for (final source in [
    'final inset = EdgeInsetsDirectional.only(start: 18);',
    'final box = SizedBox.fromSize(size: Size(12, 12));',
    nestedInsetSource,
    'final widget = Padding(padding: const .all(18));',
  ]) {
    test('rule 10 scans balanced and directional constructor: $source', () {
      write('app/lib/features/home/home_screen.dart', '$source\n');
      expect(violationsFor(10), isNotEmpty);
    });
  }

  test('literal spacing allowance requires a non-empty same-line reason', () {
    const path = 'app/lib/features/home/home_screen.dart';
    write(path, '''
final bad = SizedBox(height: 72); // rules:allow-literal
final good = SizedBox(height: 72); // rules:allow-literal fixed preview canvas
''');
    expect(violationsFor(10), hasLength(1));
  });

  test('production UI cannot use deprecated PaperSheet', () {
    write(
      'app/lib/shared/example.dart',
      'final route = PaperSheet.show<void>(context: context, builder: build);',
    );
    expect(violationsFor(10), hasLength(1));
  });

  test('section headers require JiabuStack section spacing in app UI', () {
    const path = 'app/lib/features/home/home_screen.dart';
    write(path, "final bad = JiabuSectionHeader(title: 'Loose');\n");
    expect(violationsFor(11), hasLength(1));
    write(path, '''
final good = JiabuStackItem.section(
  child: JiabuSectionHeader(title: 'Stacked'),
);
''');
    expect(violationsFor(11), isEmpty);
  });

  test('lazy delegates cannot directly build marked layout components', () {
    const path = 'app/lib/features/home/home_screen.dart';
    for (final source in [
      'ListView.builder(itemBuilder: (_, i) => JiabuStack(children: []));',
      'SliverList(delegate: SliverChildBuilderDelegate((_, i) => '
          'JiabuChipGroup(children: [])));',
    ]) {
      write(path, '$source\n');
      expect(violationsFor(12), hasLength(1));
    }
    write(
      path,
      'ListView.builder(itemBuilder: (_, i) => const Text("safe"));\n',
    );
    expect(violationsFor(12), isEmpty);
  });

  group('design package color literals outside tokens/colors.dart', () {
    const path = 'packages/jiabu_design/lib/src/components/example.dart';
    for (final source in [
      'final c = Color(0XFF000000);',
      'final c = Color(4278190080);',
      'final c = Color.fromARGB(255, 0, 0, 0);',
      'final c = Color.fromRGBO(0, 0, 0, 1);',
      'final c = Color.from(alpha: 1, red: 0, green: 0, blue: 0);',
      'final c = Colors.black;',
    ]) {
      test(source, () {
        write(path, '$source\n');
        expect(violationsFor(1), hasLength(1));
      });
    }
    test('the color token file may use every form', () {
      write(
        'packages/jiabu_design/lib/src/tokens/colors.dart',
        'final a = Color(0XFF000000); final b = Colors.black; '
            'final c = Color.fromARGB(255, 0, 0, 0);',
      );
      expect(violationsFor(1), isEmpty);
    });
    test('token references are not literals', () {
      write(path, 'final c = JiabuColors.defaultTapeA;\n');
      expect(violationsFor(1), isEmpty);
    });
  });

  group('rotation outside Tilt and geometry', () {
    for (final source in [
      'final m = Matrix4.rotationZ(0.1);',
      'final w = RotatedBox(quarterTurns: 1);',
      'void f(Canvas canvas) => canvas.rotate(0.1);',
      'void f(Canvas canvas) => canvas..save()..rotate(0.1);',
    ]) {
      test(source, () {
        write('app/lib/shared/example.dart', '$source\n');
        expect(violationsFor(2), hasLength(1));
        write('packages/jiabu_design/lib/src/components/x.dart', '$source\n');
        expect(violationsFor(2), hasLength(2));
      });
    }
    test('geometry may rotate', () {
      write(
        'packages/jiabu_design/lib/src/geometry/tape_path.dart',
        'void f(Canvas canvas) => canvas.rotate(0.1);\n',
      );
      expect(violationsFor(2), isEmpty);
    });
  });

  group('app/lib/app and app/lib/shared use tokens too', () {
    for (final dir in ['app/lib/app', 'app/lib/shared']) {
      for (final source in [
        "final s = TextStyle(fontFamily: 'Example');",
        'final d = Duration(seconds: 1);',
        'final c = Color.fromRGBO(0, 0, 0, 1);',
        'final c = Colors.red;',
      ]) {
        test('$dir: $source', () {
          write('$dir/example.dart', '$source\n');
          expect(violationsFor(1), hasLength(1));
        });
      }
    }
    test('Duration.zero and token durations are allowed', () {
      write(
        'app/lib/app/example.dart',
        'final a = Duration.zero; final b = context.jiabu.motion.sheet;\n',
      );
      expect(violationsFor(1), isEmpty);
    });
  });

  test('reports invalid dependency YAML as a rule failure', () {
    write('tool/allowed_deps.yaml', 'packages: [\n');
    expect(violationsFor(7), isNotEmpty);
  });

  test('technical Duration exception is limited to sync_policy', () {
    write(
      'app/lib/data/sync/sync_policy.dart',
      'const ttl = Duration(hours: 1);',
    );
    expect(violationsFor(1), isEmpty);
    write('app/lib/data/sync/other.dart', 'const ttl = Duration(hours: 1);');
    expect(violationsFor(1), hasLength(1));
    write(
      'app/lib/features/auth/view/login_screen.dart',
      'const ttl = Duration(hours: 1);',
    );
    expect(violationsFor(1), hasLength(2));
  });

  test('sync_policy still rejects colors and fonts', () {
    write(
      'app/lib/data/sync/sync_policy.dart',
      "final c = Colors.red; final s = TextStyle(fontFamily: 'Example');",
    );
    expect(violationsFor(1), hasLength(2));
  });

  test('database calls cannot escape scoped DAO boundary', () {
    write(
      'app/lib/data/repositories/example.dart',
      "db.customSelect('SELECT * FROM records');",
    );
    expect(violationsFor(9), hasLength(1));
    write(
      'app/lib/data/db/daos/example.dart',
      "db.customSelect('SELECT * FROM records WHERE space_id = ?', "
          'variables: args);',
    );
    expect(violationsFor(9), hasLength(1));
  });
}
