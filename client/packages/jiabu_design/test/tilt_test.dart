import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  test('UTF-16 deterministic tilt matches fixed JSON fixtures exactly', () {
    final fixtures = jsonDecode(
      File('test/fixtures/tilt_cases.json').readAsStringSync(),
    ) as List<Object?>;
    for (final row in fixtures.cast<Map<String, Object?>>()) {
      expect(
        tiltFor(row['id']! as String, amp: (row['amp']! as num).toDouble()),
        row['degrees'],
      );
    }
  });
}
