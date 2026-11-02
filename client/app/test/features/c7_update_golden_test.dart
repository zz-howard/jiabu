@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/c7_preview.dart';

import '../support/c3_harness.dart';

const c7Goldens = [
  (
    'banner_available',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/banner_available_zh_pine_w360_text100.png',
  ),
  (
    'banner_available',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/banner_available_zh_pine_w430_text200.png',
  ),
  (
    'banner_forced',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/banner_forced_zh_pine_w360_text100.png',
  ),
  (
    'banner_forced',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/banner_forced_zh_pine_w430_text200.png',
  ),
  (
    'sheet_available',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/sheet_available_zh_pine_w360_text100.png',
  ),
  (
    'sheet_available',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/sheet_available_zh_pine_w430_text200.png',
  ),
  (
    'sheet_downloading',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/sheet_downloading_zh_pine_w360_text100.png',
  ),
  (
    'sheet_downloading',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/sheet_downloading_zh_pine_w430_text200.png',
  ),
  (
    'sheet_checksum_failed',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/sheet_checksum_failed_zh_pine_w360_text100.png',
  ),
  (
    'sheet_checksum_failed',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/sheet_checksum_failed_zh_pine_w430_text200.png',
  ),
  (
    'sheet_permission_required',
    'zh',
    360.0,
    1.0,
    '../goldens/c7/sheet_permission_required_zh_pine_w360_text100.png',
  ),
  (
    'sheet_permission_required',
    'zh',
    430.0,
    2.0,
    '../goldens/c7/sheet_permission_required_zh_pine_w430_text200.png',
  ),
  (
    'banner_available',
    'en',
    360.0,
    1.0,
    '../goldens/c7/banner_available_en_pine_w360_text100.png',
  ),
  (
    'sheet_available',
    'en',
    360.0,
    1.0,
    '../goldens/c7/sheet_available_en_pine_w360_text100.png',
  ),
];

void main() {
  for (final (state, locale, width, scale, path) in c7Goldens) {
    testWidgets(path, (tester) async {
      await pumpC3(
        tester,
        child: C7Preview(state: state),
        locale: locale,
        width: width,
        scale: scale,
      );
      await expectLater(find.byKey(c3Boundary), matchesGoldenFile(path));
    });
  }
}
