import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('golden_tool_and_ci_app_step_pin_utc', () {
    expect(File('tool/golden.sh').readAsStringSync(), contains('--env TZ=UTC'));
    final workflow = File('../.github/workflows/client-ci.yml')
        .readAsStringSync();
    expect(
      workflow,
      matches(
        RegExp(
          r'name: App tests including goldens\s+env:\s+TZ: UTC\s+'
          r'working-directory: client/app\s+run: flutter test',
        ),
      ),
    );
  });
}
