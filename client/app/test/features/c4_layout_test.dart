import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c4_harness.dart';
import '../support/vertical_spacing.dart';

const _minimumStackPairs = <String, int>{
  'switcher': 3,
  'switcher_offline': 4,
  'space_new': 5,
  'space_edit': 2,
  'space_validation': 6,
  'space_personal': 1,
  'space_owner': 1,
  'space_member': 1,
  'space_offline': 2,
  'members': 1,
  'members_left': 1,
  'invite': 2,
  'sent_invitations': 0,
  'received': 0,
  'received_empty': 0,
  'received_offline': 0,
  'invitation_expired': 0,
  'leave': 2,
  'leave_pending': 3,
  'leave_last_owner': 3,
  'remove': 3,
  'transfer': 3,
  'delete_unmatched': 3,
  'delete_matched': 3,
  'settings': 0,
  'account': 2,
  'password': 2,
  'password_error': 3,
  'language': 0,
  'about': 1,
  'lock_disabled': 7,
  'lock_enabled': 2,
  'lock_pattern_setup': 10,
  'lock_pin_mismatch': 8,
  'unlock_biometric': 3,
  'unlock_pin': 3,
  'unlock_pattern': 3,
  'unlock_error': 4,
  'unlock_wait': 4,
  'unlock_recovery': 3,
  'keys_empty': 3,
  'keys_list': 3,
  'keys_offline': 1,
  'keys_failure': 4,
  'key_create': 8,
  'key_never': 9,
  'key_once': 2,
  'key_copied': 2,
  'key_replay': 9,
  'key_details': 7,
  'key_revoke': 1,
  'key_saved_confirm': 1,
  'logout_confirm': 1,
  'keys_inactive': 3,
};

const _minimumChipPairs = <String, int>{
  'space_new': 12,
  'space_edit': 7,
  'space_validation': 12,
  'lock_disabled': 5,
  'lock_pattern_setup': 5,
  'lock_pin_mismatch': 5,
  'key_create': 4,
  'key_never': 4,
  'key_replay': 4,
};

void main() {
  test('stack pair table covers every C4 state', () {
    expect(_minimumStackPairs.keys.toSet(), c4States.toSet());
  });

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
                final stackPairs = expectJiabuVerticalRhythm(
                  tester,
                  reason: '$state $locale $accent $width $scale',
                );
                expect(
                  stackPairs,
                  greaterThanOrEqualTo(_minimumStackPairs[state]!),
                  reason: '$state minimum stack pair table',
                );
                final chipPairs = expectJiabuChipSpacing(
                  tester,
                  reason: '$state $locale $accent $width $scale',
                );
                expect(
                  chipPairs,
                  greaterThanOrEqualTo(_minimumChipPairs[state] ?? 0),
                  reason: '$state minimum chip pair table',
                );
                for (final element
                    in find.byType(SpaceAccentPicker).evaluate()) {
                  final widget = element.widget as SpaceAccentPicker;
                  expect(widget.value, isNotEmpty);
                }
                for (final element in find.byType(JiabuLogo).evaluate()) {
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
                  final box = tester.renderObject<RenderBox>(
                    find.byWidget(element.widget),
                  );
                  expect(
                    box.size.height,
                    greaterThanOrEqualTo(JiabuSpacing.minTapTarget),
                  );
                  expect(
                    box.size.width,
                    greaterThanOrEqualTo(JiabuSpacing.minTapTarget),
                  );
                }
                for (final element in find.byType(Tilt).evaluate()) {
                  expect([
                    -8.0,
                    -6.0,
                    0.0,
                  ], contains((element.widget as Tilt).degrees));
                }
                if (find.byType(JiabuPageScaffold).evaluate().isNotEmpty) {
                  final header = tester.getRect(find.byType(JiabuPageHeader));
                  final body = tester.getRect(
                    find.byKey(const Key('jiabu-page-body')),
                  );
                  expect(body.top, greaterThanOrEqualTo(header.bottom));
                  final pageInset = width <= 380 ? 14.0 : 18.0;
                  // The settings root is the 我的 tab and has no back arrow.
                  if (state != 'settings') {
                    expect(
                      tester
                          .getRect(find.byKey(const Key('jiabu-page-back')))
                          .left,
                      closeTo(pageInset, .1),
                    );
                  }
                  for (final group
                      in find.byType(JiabuSettingsGroup).evaluate()) {
                    expect(
                      tester.getRect(find.byWidget(group.widget)).left,
                      closeTo(pageInset, .1),
                    );
                  }
                }
                if (state == 'members') {
                  final group = find.byType(JiabuSettingsGroup);
                  expect(group, findsOneWidget);
                  expect(
                    find.descendant(
                      of: group,
                      matching: find.byType(JiabuListRow),
                    ),
                    findsNWidgets(2),
                  );
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
  testWidgets('second-level routed pages expose a back button and title', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      // The settings root is the 我的 bottom-navigation tab: no back arrow.
      await pumpC4Preview(tester, state: 'settings');
      expect(find.byType(JiabuPageHeader), findsOneWidget);
      expect(find.byKey(const Key('jiabu-page-back')), findsNothing);
      for (final state in const [
        'account',
        'password',
        'language',
        'about',
        'lock_disabled',
        'keys_list',
        'members',
        'received',
        'sent_invitations',
      ]) {
        await pumpC4Preview(tester, state: state);
        final header = find.byType(JiabuPageHeader);
        expect(header, findsOneWidget, reason: state);
        final back = find.byKey(const Key('jiabu-page-back'));
        expect(back, findsOneWidget, reason: state);
        expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
        final label = MaterialLocalizations.of(tester.element(header))
            .backButtonTooltip;
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: state);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('settings group has no ruled paper or margin decoration', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'settings');
    expect(JiabuSettingsGroup.paperPattern, isNull);
    expect(find.byType(JiabuSettingsGroup), findsOneWidget);
    final group = find.byType(JiabuSettingsGroup);
    expect(
      find.descendant(of: group, matching: find.byType(PaperBackground)),
      findsNothing,
    );
  });

  testWidgets('api key rows keep expiry, usage, warning, and inactive stamps', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'keys_inactive', scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('永不过期'), findsOneWidget);
    expect(find.text('从未使用'), findsNWidgets(3));
    final neverExpires = tester.widget<Text>(find.text('永不过期'));
    expect(
      neverExpires.style?.color,
      tester.element(find.text('永不过期')).jiabu.colors.warn,
    );
    expect(find.widgetWithText(Stamp, '已撤销'), findsOneWidget);
    expect(find.widgetWithText(Stamp, '已过期'), findsOneWidget);
  });

  testWidgets('api key permissions remain visible beside long prefixes', (
    tester,
  ) async {
    for (final locale in ['zh', 'en']) {
      for (final (width, scale) in [
        (360.0, 1.0),
        (360.0, 2.0),
        (430.0, 1.0),
        (430.0, 2.0),
      ]) {
        await pumpC4Preview(
          tester,
          state: 'keys_list',
          locale: locale,
          width: width,
          scale: scale,
        );
        final permission = find.text(locale == 'zh' ? '只读' : 'Read only');
        expect(permission, findsOneWidget, reason: '$width at ${scale}x');
        expect(
          tester.renderObject<RenderParagraph>(permission).didExceedMaxLines,
          isFalse,
          reason: '$width at ${scale}x',
        );
      }
    }
  });

  testWidgets('api key group and primary action use the card gap token', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'keys_list');
    final groupBottom = tester
        .getRect(find.byType(JiabuSettingsGroup).last)
        .bottom;
    final buttonTop = tester.getRect(find.byType(FilledButton)).top;
    expect(
      buttonTop - groupBottom,
      greaterThanOrEqualTo(JiabuSpacing.actionGap),
    );
  });

  testWidgets('C4Form submit is an action block with action gap', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'password');
    final button = find.byType(FilledButton);
    final marker = find
        .ancestor(of: button, matching: find.byType(JiabuStackMarker))
        .first;
    expect(
      tester.widget<JiabuStackMarker>(marker).kind,
      JiabuStackItemKind.action,
    );
    expect(
      expectJiabuVerticalRhythm(tester, reason: 'password C4Form'),
      greaterThanOrEqualTo(_minimumStackPairs['password']!),
    );
  });

  testWidgets('C4Form error sits 8 under the fields and 24 above submit', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'password_error');
    final markers = find.byType(JiabuStackMarker);
    final kinds = [
      for (final element in markers.evaluate())
        (element.widget as JiabuStackMarker).kind,
    ];
    final error = kinds.indexOf(JiabuStackItemKind.caption);
    expect(error, greaterThan(0));
    expect(kinds[error + 1], JiabuStackItemKind.action);
    final field = tester.getRect(markers.at(error - 1));
    final message = tester.getRect(markers.at(error));
    final submit = tester.getRect(markers.at(error + 1));
    expect(
      message.top - field.bottom,
      moreOrLessEquals(JiabuSpacing.captionGap, epsilon: geometryTolerance),
    );
    expect(
      submit.top - message.bottom,
      moreOrLessEquals(JiabuSpacing.actionGap, epsilon: geometryTolerance),
    );
  });

  testWidgets('C4Form keeps offline submit note inside the action group', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'password_offline');
    final offline = find.text('需要联网才能管理');
    final button = find.widgetWithText(FilledButton, '保存');
    final actionMarker = find.ancestor(
      of: button,
      matching: find.byType(JiabuStackMarker),
    );
    final markers = find.byType(JiabuStackMarker);
    final actionIndex = tester.widget<JiabuStackMarker>(actionMarker).index;
    expect(
      tester.widget<JiabuStackMarker>(actionMarker).kind,
      JiabuStackItemKind.action,
    );
    expect(
      find.descendant(of: actionMarker, matching: offline),
      findsOneWidget,
    );
    expect(
      tester.getRect(actionMarker).top -
          tester.getRect(markers.at(actionIndex - 1)).bottom,
      moreOrLessEquals(JiabuSpacing.actionGap, epsilon: geometryTolerance),
    );
    expect(
      tester.getRect(button).top - tester.getRect(offline).bottom,
      moreOrLessEquals(JiabuSpacing.captionGap, epsilon: geometryTolerance),
    );
  });

  testWidgets('C4Form keeps list offline note after its content', (
    tester,
  ) async {
    await pumpC4Preview(tester, state: 'keys_offline');
    final offline = find.text('需要联网才能管理');
    final captionMarker = find.ancestor(
      of: offline,
      matching: find.byType(JiabuStackMarker),
    );
    final caption = tester.widget<JiabuStackMarker>(captionMarker);
    final markers = find.byType(JiabuStackMarker);
    expect(caption.kind, JiabuStackItemKind.caption);
    expect(caption.captionTarget, JiabuCaptionTarget.previous);
    expect(
      tester.getRect(captionMarker).top -
          tester.getRect(markers.at(caption.index - 1)).bottom,
      moreOrLessEquals(JiabuSpacing.captionGap, epsilon: geometryTolerance),
    );
  });

  testWidgets('unlock logo and title stay centered', (tester) async {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        await pumpC4Preview(
          tester,
          state: 'unlock_pin',
          width: width,
          scale: scale,
        );
        for (final finder in [find.byType(JiabuLogo), find.text('家簿已上锁')]) {
          expect(
            tester.getRect(finder).center.dx,
            closeTo(width / 2, 1),
            reason: '$finder at $width and ${scale}x',
          );
        }
      }
    }
  });

  testWidgets('account logout is separated as an action block', (tester) async {
    await pumpC4Preview(tester, state: 'account');
    final group = tester.getRect(find.byType(JiabuSettingsGroup));
    final buttonFinder = find.widgetWithText(OutlinedButton, '退出登录');
    final button = tester.getRect(buttonFinder);
    final marker = find.ancestor(
      of: buttonFinder,
      matching: find.byType(JiabuStackMarker),
    );
    expect(
      tester.widget<JiabuStackMarker>(marker).kind,
      JiabuStackItemKind.action,
    );
    expect(
      button.top - group.bottom,
      greaterThanOrEqualTo(JiabuSpacing.actionGap),
    );
  });

  testWidgets('app lock status and action labels are distinct', (tester) async {
    await pumpC4Preview(tester, state: 'lock_enabled');
    expect(find.text('已开启'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '关闭应用锁'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '未开启'), findsNothing);
    await pumpC4Preview(tester, state: 'lock_disabled');
    expect(find.text('未开启'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '开启应用锁'), findsOneWidget);
  });

  testWidgets('language row exposes selected semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpC4Preview(tester, state: 'language');
      expect(
        tester.getSemantics(find.byKey(const ValueKey('language-zh-Hans'))),
        isSemantics(hasSelectedState: true, isSelected: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('inactive key row exposes expanded and collapsed semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpC4Preview(tester, state: 'keys_inactive');
      expect(
        tester.getSemantics(find.byKey(const Key('inactive-keys-toggle'))),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      final expandedIcon = tester.widget<JiabuIcon>(
        find.descendant(
          of: find.byKey(const Key('inactive-keys-toggle')),
          matching: find.byType(JiabuIcon),
        ),
      );
      expect(expandedIcon.icon, JiabuIcons.uiDown);
      expect(expandedIcon.flipY, isTrue);

      await pumpC4Preview(tester, state: 'keys_list');
      expect(
        tester.getSemantics(find.byKey(const Key('inactive-keys-toggle'))),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );
      final collapsedIcon = tester.widget<JiabuIcon>(
        find.descendant(
          of: find.byKey(const Key('inactive-keys-toggle')),
          matching: find.byType(JiabuIcon),
        ),
      );
      expect(collapsedIcon.icon, JiabuIcons.uiDown);
      expect(collapsedIcon.flipY, isFalse);
    } finally {
      semantics.dispose();
    }
  });
}
