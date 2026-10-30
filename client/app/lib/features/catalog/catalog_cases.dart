import 'package:flutter/material.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

@immutable
class CatalogCase {
  const CatalogCase(this.component, this.state, this.builder);

  final String component;
  final String state;
  final WidgetBuilder builder;

  String get id => '${component}_$state';
}

/// The dev catalog and all visual tests consume this same exhaustive registry.
List<CatalogCase> catalogCases() => [
  CatalogCase(
    'c4b',
    'jiabu_logo_variants',
    // The dark variant is a paper disc for dark surfaces; show it on ink so
    // the disc is visible in the golden.
    (context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const JiabuLogo(size: 120),
        const SizedBox(width: JiabuSpacing.xl),
        ColoredBox(
          color: context.jiabu.colors.ink,
          child: const Padding(
            padding: EdgeInsets.all(JiabuSpacing.md),
            child: JiabuLogo(size: 120, variant: JiabuLogoVariant.dark),
          ),
        ),
      ],
    ),
  ),
  CatalogCase(
    'c4b',
    'jiabu_mascot_poses',
    (_) => const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JiabuMascot(pose: JiabuMascotPose.greet, size: 96),
        JiabuMascot(pose: JiabuMascotPose.pen, size: 96),
        JiabuMascot(pose: JiabuMascotPose.idle, size: 96),
      ],
    ),
  ),
  for (final state in c4States)
    CatalogCase('c4', state, (_) => C4Preview(state: state)),
  for (final state in c5States)
    CatalogCase(
      'c5',
      state,
      (_) => SizedBox(
        height: JiabuChatMetrics.pageHeight,
        child: C5Preview(state: state),
      ),
    ),
  // PaperRow is exercised by the existing C3 settings, pending-record and
  // allocation-plan states on their real decorated paper surfaces.
  for (final state in c3States)
    CatalogCase(
      'c3',
      state,
      (_) => SizedBox(
        height: 720, // rules:allow-literal fixed C3 catalog viewport
        child: C3Preview(state: state),
      ),
    ),
  CatalogCase(
    'ui1_page_scaffold',
    'basic',
    (context) => SizedBox(
      height: 320, // rules:allow-literal component preview viewport
      child: JiabuPageScaffold(
        title: _l(context).catalogSampleTitle,
        onBack: () {},
        body: Center(child: Text(_l(context).catalogSampleBody)),
      ),
    ),
  ),
  CatalogCase(
    'ui1_page_header',
    'action',
    (context) => JiabuPageHeader(
      title: _l(context).catalogSampleTitle,
      onBack: () {},
      action: TextButton(
        onPressed: () {},
        child: Text(_l(context).catalogOpenSheet),
      ),
    ),
  ),
  CatalogCase(
    'ui1_list_row',
    'basic',
    (context) => JiabuListRow(
      title: _l(context).catalogSampleTitle,
      subtitle: _l(context).catalogSampleBody,
      showChevron: true,
    ),
  ),
  CatalogCase(
    'ui1_list_row',
    'long_name',
    (context) => JiabuListRow(
      title: '${_l(context).catalogLongBody} ${_l(context).catalogLongBody}',
      value: '¥12,345.67',
      showChevron: true,
    ),
  ),
  CatalogCase(
    'ui1_section_header',
    'basic',
    (context) => JiabuStack(
      children: [
        JiabuStackItem.section(
          child: JiabuSectionHeader(title: _l(context).catalogSampleTitle),
        ),
      ],
    ),
  ),
  CatalogCase(
    'ui2_stack',
    'vertical_rhythm',
    (context) => JiabuStack(
      children: [
        JiabuStackItem.content(child: Text(_l(context).catalogSampleBody)),
        JiabuStackItem.captionAfter(child: Text(_l(context).catalogLongBody)),
        JiabuStackItem.section(
          child: JiabuSectionHeader(title: _l(context).catalogSampleTitle),
        ),
        JiabuStackItem.content(
          child: JiabuSettingsGroup(
            children: [JiabuListRow(title: _l(context).catalogSampleBody)],
          ),
        ),
        JiabuStackItem.action(
          child: FilledButton(
            onPressed: () {},
            child: Text(_l(context).catalogOpenSheet),
          ),
        ),
      ],
    ),
  ),
  CatalogCase(
    'ui1_empty_state',
    'action',
    (context) => JiabuEmptyState(
      message: HandText(_l(context).handNoResults, textAlign: TextAlign.center),
      actionLabel: _l(context).catalogOpenSheet,
      onAction: () {},
    ),
  ),
  CatalogCase(
    'ui1_settings_group',
    'basic',
    (context) => JiabuSettingsGroup(
      children: [
        JiabuListRow(title: _l(context).catalogSampleTitle),
        JiabuListRow(title: _l(context).catalogSampleBody),
      ],
    ),
  ),
  CatalogCase(
    'ui1_sheet',
    'short_content',
    (context) => JiabuSheet(child: Text(_l(context).catalogSampleBody)),
  ),
  for (final degrees in [-5.0, 0.0, 5.0])
    CatalogCase(
      'tilt',
      degrees < 0 ? 'negative' : (degrees > 0 ? 'positive' : 'zero'),
      (context) =>
          Tilt(degrees: degrees, child: Text(_l(context).catalogSampleTitle)),
    ),
  for (final multiline in [false, true])
    CatalogCase(
      'paper_card',
      multiline ? 'multiline_content' : 'short_content',
      (context) => Stack(
        clipBehavior: Clip.none,
        children: [
          PaperCard(
            child: Text(
              multiline
                  ? _l(context).catalogLongBody
                  : _l(context).catalogSampleBody,
            ),
          ),
          const Positioned(left: 12, top: -10, child: Tape()),
        ],
      ),
    ),
  for (final pattern in TapePattern.values)
    CatalogCase('tape', pattern.name, (_) => Tape(pattern: pattern)),
  for (final category in Sticker.icons.keys)
    for (final compact in [false, true])
      CatalogCase(
        'sticker',
        '${category}_${compact ? 'compact36' : 'regular40'}',
        (_) => Sticker(category: category, compact: compact),
      ),
  for (final state in StampState.values)
    CatalogCase(
      'stamp',
      state.name,
      (context) => Stamp(
        label: state == StampState.recorded
            ? _l(context).catalogRecorded
            : _l(context).catalogRevoked,
        state: state,
      ),
    ),
  for (final degrees in [-2.0, 2.0])
    CatalogCase(
      'polaroid',
      degrees < 0 ? 'left_saved' : 'right_saved',
      (context) => Polaroid(
        degrees: degrees,
        caption: _l(context).handOriginalSaved,
        image: AspectRatio(
          aspectRatio: 1.8,
          child: ColoredBox(
            color: context.jiabu.colors.surface2,
            child: const Center(child: JiabuIcon(JiabuIcons.uiImage, size: 48)),
          ),
        ),
      ),
    ),
  CatalogCase('hand_text', 'subtitle', (c) => HandText(_l(c).handSubtitle)),
  CatalogCase(
    'hand_text',
    'today_time',
    (c) => HandText(_l(c).handTodayTime('12:36')),
  ),
  CatalogCase('hand_text', 'yesterday', (c) => HandText(_l(c).handYesterday)),
  CatalogCase(
    'hand_text',
    'calendar_date',
    (c) => HandText(_l(c).handCalendarDate(10, 24, _l(c).handWeekdaySaturday)),
  ),
  CatalogCase(
    'hand_text',
    'original_saved',
    (c) => HandText(_l(c).handOriginalSaved),
  ),
  CatalogCase('hand_text', 'carry_over', (c) => HandText(_l(c).handCarryOver)),
  CatalogCase(
    'hand_text',
    'personal_space_only',
    (c) => HandText(_l(c).handPersonalSpaceOnly),
  ),
  CatalogCase('hand_text', 'no_results', (c) => HandText(_l(c).handNoResults)),
  CatalogCase(
    'hand_text',
    'english',
    (c) => HandText(_l(c).handEnglish, english: true),
  ),
  CatalogCase(
    'hand_text',
    'mixed_e4',
    (c) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandText(_l(c).handTodayTime('12:36')),
        HandText(_l(c).handE4Amount),
        HandText(_l(c).handE4Negative),
        HandText(_l(c).handVision),
      ],
    ),
  ),
  for (final sample in const [
    ('zero', 0, AmountRole.hero, false),
    ('positive', 184260, AmountRole.detail, false),
    ('negative', -18000, AmountRole.record, false),
    ('grouped', 12345678, AmountRole.balance, false),
    ('highlighted', 6800, AmountRole.list, true),
    ('inline', 1850, AmountRole.inline, false),
    ('long_wrapped', 1234567890123456, AmountRole.hero, true),
  ])
    CatalogCase(
      'amount_text',
      sample.$1,
      (context) => AmountText(
        minorUnits: sample.$2,
        semanticLabel: sample.$2 < 0
            ? _l(context).catalogExpenseDescription(
                sample.$2.abs() ~/ 100,
                sample.$2.abs() % 100,
              )
            : _l(context)
                  .catalogAmountDescription(sample.$2 ~/ 100, sample.$2 % 100),
        role: sample.$3,
        highlighted: sample.$4,
      ),
    ),
  for (final long in [false, true])
    CatalogCase(
      'hand_underline',
      long ? 'long_title' : 'short_title',
      (context) => HandUnderline(
        child: Text(
          long ? _l(context).catalogLongBody : _l(context).catalogSampleTitle,
          style: context.jiabu.type.pageTitle,
        ),
      ),
    ),
  CatalogCase(
    'hand_circle',
    'icon_only',
    (_) => const HandCircle(child: JiabuIcon(JiabuIcons.uiDash, size: 22)),
  ),
  CatalogCase(
    'hand_circle',
    'navigation_label',
    (context) => HandCircle(child: Text(_l(context).catalogNavigationLabel)),
  ),
  CatalogCase(
    'pencil_strike',
    'title',
    (context) => PencilStrike(
      child: Text(
        _l(context).catalogSampleTitle,
        style: context.jiabu.type.cardTitle,
      ),
    ),
  ),
  CatalogCase(
    'pencil_strike',
    'amount',
    (context) => PencilStrike(
      child: AmountText(
        minorUnits: -18000,
        semanticLabel: _l(context).catalogExpenseDescription(180, 0),
      ),
    ),
  ),
  for (final sample in const [
    ('short', 'message-short', false),
    ('multiline', 'message-long', true),
    ('tilt_negative', '0', false),
    ('tilt_zero', '2', false),
    ('tilt_positive', '4', false),
  ])
    CatalogCase(
      'note_bubble',
      sample.$1,
      (context) => NoteBubble(
        id: sample.$2,
        child: Text(
          sample.$3
              ? _l(context).catalogLongBody
              : _l(context).catalogSampleBody,
        ),
      ),
    ),
  for (final long in [false, true])
    CatalogCase(
      'paper_sheet',
      long ? 'scrollable_content' : 'short_content',
      (context) => JiabuSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < (long ? 15 : 1); i++)
              Text(_l(context).catalogLongBody),
          ],
        ),
      ),
    ),
  CatalogCase(
    'paper_sheet',
    'modal',
    (context) => TextButton(
      onPressed: () async {
        await JiabuSheet.show<void>(
          context: context,
          builder: (sheetContext) => Text(_l(sheetContext).catalogLongBody),
        );
      },
      child: Text(_l(context).catalogOpenSheet),
    ),
  ),
  for (final position in PaperSnackPosition.values)
    for (final state in ['message_only', 'with_action', 'long_message'])
      CatalogCase(
        'paper_snack_bar',
        '${state}_${position.name}',
        (context) => SizedBox(
          width: double.infinity,
          height: 520, // rules:allow-literal snackbar position preview
          child: Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                bottom: position == PaperSnackPosition.chat ? 150 : 92,
                child: PaperSnackBar(
                  message: state == 'long_message'
                      ? _l(context).catalogLongBody
                      : _l(context).catalogSnackMessage,
                  actionLabel: state == 'message_only'
                      ? null
                      : _l(context).catalogAction,
                  onAction: state == 'message_only' ? null : () {},
                ),
              ),
            ],
          ),
        ),
      ),
  for (final pattern in PaperPattern.values)
    CatalogCase(
      'paper_background',
      pattern.name,
      (_) => PaperBackground(
        pattern: pattern,
        child: const SizedBox(
          width: double.infinity,
          height: 180, // rules:allow-literal snackbar preview canvas
        ),
      ),
    ),
  for (final category in ['ui', 'doodle', 'stroke-decor'])
    CatalogCase(
      'jiabu_icon',
      '${category.replaceAll('-', '_')}_sheet',
      (_) => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final icon in JiabuIcons.all.values)
            if (icon.category == category)
              Tooltip(
                message: icon.name,
                child: JiabuIcon(
                  icon,
                  size: category == 'stroke-decor' ? 120 : 32,
                ),
              ),
        ],
      ),
    ),
];

AppLocalizations _l(BuildContext context) => AppLocalizations.of(context);
