import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Pure presentation shared by production routing and the component catalog.
///
/// The header is the shared page-title block (title with wavy underline and a
/// handwritten subtitle) on the left and the space badge on the right, where
/// the original design had its 家庭 / 私人 switch.
class MainFrame extends StatelessWidget {
  const MainFrame({
    required this.spaceName,
    required this.accent,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.title,
    this.handEnglish,
    this.subtitle,
    this.showMark = false,
    this.personalSpace = false,
    this.onSpace,
    this.manual,
    this.status,
    super.key,
  });

  /// Null on second-level routes (settings…), which bring their own header.
  final String? title;
  final String? handEnglish;
  final String? subtitle;

  /// The round home emblem before the title (chat page only).
  final bool showMark;
  final String spaceName;
  final Color accent;

  /// The current space is the personal one (lock icon instead of a house).
  final bool personalSpace;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;
  final VoidCallback? onSpace;
  final Widget? manual;
  final Widget? status;

  /// The badge never takes more than this share of the header, so long space
  /// names are cut with an ellipsis and the title keeps its room.
  static const double badgeShare = .44;

  /// Above this text scale the badge drops below the title block (without its
  /// subtitle) instead of squeezing both into one row.
  static const double stackedTextScale = 1.4;

  Widget _header(BuildContext context) {
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > stackedTextScale;
    // At large text sizes the handwritten subtitle is decoration the screen
    // cannot afford (it stays in the reading order); the title and the space
    // badge keep their room.
    final titleBlock = JiabuPageTitleBlock(
      title: title!,
      handEnglish: handEnglish,
      subtitle: subtitle,
      showSubtitle: !stacked,
      leading: showMark ? const JiabuHomeMark() : null,
    );
    final badge = SpaceBadge(
      name: spaceName,
      accent: accent,
      personal: personalSpace,
      onTap: onSpace,
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          Align(alignment: AlignmentDirectional.centerEnd, child: badge),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: titleBlock,
          ),
        ),
        const SizedBox(width: JiabuSpacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * badgeShare,
          ),
          child: badge,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Second-level routes (title == null) bring their own page header.
            if (title != null)
              ColoredBox(
                key: const Key('main-frame-header'),
                color: context.jiabu.colors.bg,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.jiabu.spacing.page,
                    vertical: JiabuSpacing.sm,
                  ),
                  child: _header(context),
                ),
              ),
            ?status,
            Expanded(
              child: ClipRect(
                key: const Key('main-frame-content'),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
    floatingActionButtonLocation: const ManualEntryLocation(),
    floatingActionButton: manual,
    bottomNavigationBar: PaperBottomNavigation(
      labels: labels,
      selected: selected,
      onSelect: onSelect,
    ),
  );
}
