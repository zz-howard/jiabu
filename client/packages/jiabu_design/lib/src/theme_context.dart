import 'package:flutter/material.dart';

import 'package:jiabu_design/src/tokens/colors.dart';
import 'package:jiabu_design/src/tokens/decor.dart';
import 'package:jiabu_design/src/tokens/motion.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';
import 'package:jiabu_design/src/tokens/type.dart';

extension JiabuContext on BuildContext {
  JiabuThemeTokens get jiabu => JiabuThemeTokens(this);
}

class JiabuThemeTokens {
  const new(this.context);

  final BuildContext context;

  JiabuColors get colors =>
      Theme.of(context).extension<JiabuColors>() ?? const JiabuColors();
  JiabuType get type =>
      Theme.of(context).extension<JiabuType>() ?? const JiabuType();
  JiabuDecor get decor =>
      Theme.of(context).extension<JiabuDecor>() ?? JiabuDecor.paper(colors);
  JiabuMotion get motion {
    final value =
        Theme.of(context).extension<JiabuMotion>() ?? const JiabuMotion();
    return MediaQuery.disableAnimationsOf(context) ? value.reduced : value;
  }

  JiabuSpacing get spacing =>
      JiabuSpacing.forWidth(MediaQuery.sizeOf(context).width);
}
