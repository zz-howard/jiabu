import 'package:flutter/material.dart';

import 'package:jiabu_design/src/tokens/colors.dart';

abstract final class JiabuTheme {
  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: JiabuColors.accent),
  );
}
