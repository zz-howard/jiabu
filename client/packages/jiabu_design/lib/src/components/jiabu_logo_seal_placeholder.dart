import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/theme_context.dart';

/// Deliberately blank seal. Replace this component when the official logo is
/// approved; it is not a drawing of the Jiabu logo or mascot.
class JiabuLogoSealPlaceholder extends StatelessWidget {
  const JiabuLogoSealPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Tilt(
      degrees: context.jiabu.decor.logoTilt,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.jiabu.colors.paper,
          border: Border.all(color: context.jiabu.colors.lineStrong, width: 2),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.jiabu.colors.lineStrong),
            ),
          ),
        ),
      ),
    ),
  );
}
