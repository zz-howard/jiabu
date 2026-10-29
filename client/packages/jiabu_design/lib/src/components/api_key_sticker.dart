import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';

class ApiKeySticker extends StatelessWidget {
  const ApiKeySticker({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Tilt(
      degrees: context.jiabu.decor.stickerTilt,
      child: Container(
        width: context.jiabu.decor.stickerSize,
        height: context.jiabu.decor.stickerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.jiabu.colors.surface2,
          border: Border.all(
            color: context.jiabu.colors.onPrimary,
            width: context.jiabu.decor.stickerBorder,
          ),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: Center(
          child: JiabuIcon(JiabuIcons.uiKey, color: context.jiabu.colors.ink2),
        ),
      ),
    ),
  );
}
