import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/ledger_metrics.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

/// The history page's rounded search card (design-spec 4.12, original
/// `.search`): paper, search radius, a hairline edge with a soft paper shadow,
/// a magnifier on the left and a ruled line under the text. [child] is the
/// borderless text field.
class PaperSearchCard extends StatelessWidget {
  const PaperSearchCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.jiabu.colors;
    final d = context.jiabu.decor;
    return Container(
      key: const Key('paper-search-card'),
      constraints: const BoxConstraints(
        minHeight: JiabuLedgerMetrics.searchHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: JiabuSpacing.lg),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(d.searchRadius),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: c.shadowInk.withValues(alpha: .25),
            offset: const Offset(0, 2),
            blurRadius: 4,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: JiabuIcon(
              JiabuIcons.uiSearch,
              key: const Key('paper-search-icon'),
              size: JiabuLedgerMetrics.searchIcon,
              color: c.ink2,
            ),
          ),
          const SizedBox(width: JiabuSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: JiabuSpacing.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.rule)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: JiabuSpacing.xs,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrolling chip row that runs edge to edge (original
/// `.fchips`, margin `0 -18px` + padding `0 18px`): the first chip starts at
/// the page gutter, the last chip ends one gutter before the screen edge, and
/// an edge fades only while more chips are hidden on that side.
class PaperChipScroller extends StatefulWidget {
  const PaperChipScroller({
    required this.gutter,
    required this.child,
    super.key,
  });

  /// The page gutter, used as leading and trailing padding.
  final double gutter;
  final Widget child;

  @override
  State<PaperChipScroller> createState() => _PaperChipScrollerState();
}

class _PaperChipScrollerState extends State<PaperChipScroller> {
  var _before = false;
  var _after = false;

  bool _sync(ScrollMetrics metrics) {
    // Half a pixel of slack: a fully scrolled row must show no fade.
    final before = metrics.extentBefore > .5;
    final after = metrics.extentAfter > .5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  Widget _fade(BuildContext context, {required bool start}) {
    final bg = context.jiabu.colors.bg;
    return PositionedDirectional(
      key: Key(start ? 'chip-fade-start' : 'chip-fade-end'),
      start: start ? 0 : null,
      end: start ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: JiabuLedgerMetrics.chipFade,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: start
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              end: start
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              colors: [bg.withValues(alpha: 0), bg],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _sync(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _sync(n.metrics),
          child: Stack(
            children: [
              SingleChildScrollView(
                key: const Key('paper-chip-scroller'),
                scrollDirection: Axis.horizontal,
                // Room for the selected chip's white ring and shadow.
                padding: EdgeInsetsDirectional.only(
                  start: widget.gutter,
                  end: widget.gutter,
                  top: JiabuSpacing.xs,
                  bottom: JiabuSpacing.xs,
                ),
                child: widget.child,
              ),
              if (_before) _fade(context, start: true),
              if (_after) _fade(context, start: false),
            ],
          ),
        ),
      );
}

/// One day of the history page (design-spec 4.12, original screenshot): a
/// paper card with the card shadow, rows separated by rule lines, and a red
/// timeline running top to bottom through the round stickers, which sit on
/// the line. Each row must place its sticker [JiabuLedgerMetrics.timelineStart]
/// in from the card's start edge.
class PaperTimelineCard extends StatelessWidget {
  const PaperTimelineCard({required this.children, this.lineKey, super.key});
  final List<Widget> children;
  final Key? lineKey;

  /// The x of the timeline's centre inside the card.
  static double lineCenter(BuildContext context) =>
      JiabuLedgerMetrics.timelineStart + context.jiabu.decor.stickerSize / 2;

  @override
  Widget build(BuildContext context) {
    final c = context.jiabu.colors;
    final d = context.jiabu.decor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(d.cardRadius),
        boxShadow: d.cardShadow,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            key: lineKey,
            start: lineCenter(context) - JiabuLedgerMetrics.timelineStroke / 2,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: c.margin,
              child: const SizedBox(width: JiabuLedgerMetrics.timelineStroke),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++)
                if (i == 0)
                  children[i]
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.rule)),
                    ),
                    child: children[i],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
