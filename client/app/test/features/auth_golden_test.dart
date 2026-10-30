@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/auth_test_cases.dart';
import '../support/image_harness.dart';
import 'auth_screens_test.dart' show pumpAuth;

typedef _Variant = ({String locale, int width, double scale, String suffix});

const _fullVariants = <_Variant>[
  (locale: 'zh', width: 360, scale: 1.0, suffix: 'zh_pine_w360_text100'),
  (locale: 'zh', width: 430, scale: 2.0, suffix: 'zh_pine_w430_text200'),
  (locale: 'en', width: 360, scale: 1.0, suffix: 'en_pine_w360_text100'),
];

// Error, busy and secondary screens: one variant each, so the C2 auth set's
// states keep pixel coverage on the new AuthFrame without a full matrix.
const _stateVariants = <_Variant>[
  (locale: 'zh', width: 360, scale: 1.0, suffix: 'zh_pine_w360_text100'),
];

void main() {
  for (final (samples, variants) in [
    (authPrimaryTestCases, _fullVariants),
    (authSecondaryTestCases, _stateVariants),
  ]) {
    for (final sample in samples) {
      for (final variant in variants) {
        final path = '../goldens/c4b/${sample.state}_${variant.suffix}.png';
        testWidgets(path, (tester) async {
          await pumpAuth(
            tester,
            sample.builder(),
            width: variant.width.toDouble(),
            scale: variant.scale,
            locale: variant.locale,
          );
          if (sample.tapKey case final String key) {
            final target = find.byKey(Key(key));
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
            await settleImages(tester);
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('auth-golden')),
            matchesGoldenFile(path),
          );
        });
      }
    }
  }
}
