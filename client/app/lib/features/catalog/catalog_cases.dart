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
  // This isolated component uses the identical seal already covered by the
  // C4 unlock goldens; no second set of PNGs is requested.
  CatalogCase(
    'c4',
    'jiabu_logo_seal_placeholder',
    (_) => const JiabuLogoSealPlaceholder(),
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
      (_) => SizedBox(height: 720, child: C3Preview(state: state)),
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
      (context) => PaperSheet(
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
        await PaperSheet.show<void>(
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
          height: 520,
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
        child: const SizedBox(width: double.infinity, height: 180),
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
