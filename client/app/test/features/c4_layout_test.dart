import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c4_harness.dart';

void main() {
  for (final state in c4States) {
    for (final locale in ['zh', 'en']) {
      for (final accent in ['pine', 'indigo']) {
        for (final width in [360.0, 430.0]) {
          for (final scale in [1.0, 2.0]) {
            testWidgets('$state $locale $accent $width $scale fits', (
              tester,
            ) async {
              final semantics = tester.ensureSemantics();
              try {
                await pumpC4Preview(
                  tester,
                  state: state,
                  locale: locale,
                  accent: accent,
                  width: width,
                  scale: scale,
                );
                expect(tester.takeException(), isNull);
                for (final element
                    in find.byType(SpaceAccentPicker).evaluate()) {
                  final widget = element.widget as SpaceAccentPicker;
                  expect(widget.value, isNotEmpty);
                }
                for (final element
                    in find.byType(JiabuLogoSealPlaceholder).evaluate()) {
                  final tilt = find.descendant(
                    of: find.byWidget(element.widget),
                    matching: find.byType(Tilt),
                  );
                  expect(tester.widget<Tilt>(tilt).degrees, -8);
                }
                for (final element in find.byType(PinPad).evaluate()) {
                  expect(
                    tester.getSize(find.byWidget(element.widget)).width,
                    lessThanOrEqualTo(width),
                  );
                }
                for (final element
                    in find.bySubtype<ButtonStyleButton>().evaluate()) {
                  final size = tester.getSize(find.byWidget(element.widget));
                  expect(size.height, greaterThanOrEqualTo(44));
                  expect(size.width, greaterThanOrEqualTo(44));
                }
                for (final element in find.byType(Tilt).evaluate()) {
                  expect([
                    -8.0,
                    -6.0,
                    0.0,
                  ], contains((element.widget as Tilt).degrees));
                }
                final decor = tester
                    .element(find.byType(C4Preview))
                    .jiabu
                    .decor;
                if (state.startsWith('unlock')) {
                  expect(
                    tester.getSize(find.byType(PaperBackground).last).height,
                    760,
                  );
                }
                if (state == 'key_details') {
                  final immutable = find.text(
                    locale == 'zh'
                        ? '权限不能修改，可以新建一个再撤销这个。'
                        : 'Permissions cannot be changed. '
                              'Create a replacement and revoke this key.',
                  );
                  final field = find.byType(TextFormField).first;
                  expect(
                    tester.getTopLeft(field).dy -
                        tester.getBottomLeft(immutable).dy,
                    greaterThanOrEqualTo(decor.cardGap),
                  );
                }
                if (state == 'space_new' || state == 'space_validation') {
                  final currency = find.text(
                    locale == 'zh' ? '币种' : 'Currency',
                  );
                  final chips = find.byType(ChoiceChip);
                  expect(
                    tester.getTopLeft(chips.first).dy -
                        tester.getBottomLeft(currency).dy,
                    greaterThanOrEqualTo(decor.messageGap),
                  );
                  var chipBottom = 0.0;
                  for (final element in chips.evaluate()) {
                    final bottom = tester
                        .getBottomLeft(find.byWidget(element.widget))
                        .dy;
                    if (bottom > chipBottom) {
                      chipBottom = bottom;
                    }
                  }
                  expect(
                    tester.getTopLeft(find.byType(TextFormField).last).dy -
                        chipBottom,
                    greaterThanOrEqualTo(decor.cardGap),
                  );
                }
                final retry = find.text(locale == 'zh' ? '重试' : 'Retry');
                if (state == 'keys_failure') {
                  expect(retry, findsOneWidget);
                } else if (const {
                  'keys_empty',
                  'keys_list',
                  'keys_offline',
                  'keys_inactive',
                  'received',
                  'received_empty',
                  'received_offline',
                  'sent_invitations',
                  'invitation_expired',
                }.contains(state)) {
                  expect(retry, findsNothing);
                }
                if (state == 'space_new' || state == 'space_edit') {
                  expect(find.byType(SpaceAccentPicker), findsOneWidget);
                  expect(
                    find.bySemanticsLabel(
                      RegExp(locale == 'zh' ? '陶土' : 'Terracotta'),
                    ),
                    findsOneWidget,
                  );
                }
              } finally {
                semantics.dispose();
              }
            });
          }
        }
      }
    }
  }
}
