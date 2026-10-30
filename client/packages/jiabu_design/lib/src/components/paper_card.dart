import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/paper_background.dart';
import 'package:jiabu_design/src/geometry/paper.dart';
import 'package:jiabu_design/src/geometry/shadow.dart';
import 'package:jiabu_design/src/theme_context.dart';

class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.padding,
    this.revoked = false,
    this.pattern = PaperPattern.dots,
    this.elevation = PaperElevation.card,
    super.key,
  });

  final Widget child;
  final bool revoked;
  final EdgeInsetsGeometry? padding;
  final PaperPattern pattern;

  /// Shadow level (design-spec 3.3): `card` by default, `hero` for the one
  /// overview hero card, `tile` for the lighter purpose-account tiles.
  final PaperElevation elevation;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: revoked ? .65 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.jiabu.colors.paper,
        border: revoked
            ? Border.all(color: context.jiabu.colors.lineStrong)
            : null,
        borderRadius: BorderRadius.circular(context.jiabu.decor.cardRadius),
        boxShadow: paperShadows(context.jiabu.decor, elevation),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.jiabu.decor.cardRadius),
        child: PaperBackground(
          pattern: pattern,
          color: context.jiabu.colors.paper,
          child: Padding(
            padding: padding ?? EdgeInsets.all(context.jiabu.decor.cardInset),
            child: child,
          ),
        ),
      ),
    ),
  );
}
