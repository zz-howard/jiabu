import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/icon_data.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';

class Sticker extends StatelessWidget {
  const new({required this.category, this.compact = false, super.key})
    : assert(
        category == 'food' ||
            category == 'edu' ||
            category == 'health' ||
            category == 'travel' ||
            category == 'home' ||
            category == 'reserve' ||
            category == 'hobby' ||
            category == 'books' ||
            category == 'fit' ||
            category == 'income' ||
            category == 'alloc' ||
            category == 'transfer' ||
            category == 'move' ||
            category == 'doc' ||
            category == 'fund' ||
            category == 'warn',
        'Unknown sticker category',
      );

  final String category;
  final bool compact;

  static const Map<String, JiabuIconData> icons = {
    'food': JiabuIcons.doodleFood,
    'edu': JiabuIcons.doodleEdu,
    'health': JiabuIcons.doodleHealth,
    'travel': JiabuIcons.doodleTravel,
    'home': JiabuIcons.doodleHome,
    'reserve': JiabuIcons.doodleReserve,
    'hobby': JiabuIcons.doodleHobby,
    'books': JiabuIcons.doodleBooks,
    'fit': JiabuIcons.doodleFit,
    'income': JiabuIcons.uiIncome,
    'alloc': JiabuIcons.uiAlloc,
    'transfer': JiabuIcons.uiMove,
    'move': JiabuIcons.uiMove,
    'doc': JiabuIcons.uiEye,
    'fund': JiabuIcons.uiCard,
    'warn': JiabuIcons.uiCloudOff,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.jiabu.colors;
    final d = context.jiabu.decor;
    final size = compact ? d.compactStickerSize : d.stickerSize;
    return ExcludeSemantics(
      child: Tilt(
        degrees: d.stickerTilt,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.stickerBackgrounds[category],
            shape: BoxShape.circle,
            border: Border.all(color: c.white, width: d.stickerBorder),
            boxShadow: d.stickerShadow,
          ),
          alignment: Alignment.center,
          child: JiabuIcon(
            icons[category]!,
            size: compact ? 20 : 22,
            color: c.stickerInks[category],
            strokeWidth: d.stickerStroke,
          ),
        ),
      ),
    );
  }
}
