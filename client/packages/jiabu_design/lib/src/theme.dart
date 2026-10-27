import 'package:flutter/material.dart';

import 'package:jiabu_design/src/tokens/colors.dart';
import 'package:jiabu_design/src/tokens/decor.dart';
import 'package:jiabu_design/src/tokens/motion.dart';
import 'package:jiabu_design/src/tokens/type.dart';

abstract final class JiabuTheme {
  static ThemeData light() {
    const c = JiabuColors();
    const t = JiabuType();
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      textStyle: WidgetStatePropertyAll(t.listTitle),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Also covers Material defaults and modal routes off the page subtree.
      fontFamily: JiabuType.systemSansFamily,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.light(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.onPrimarySoft,
        secondary: c.ink2,
        onSecondary: c.paper,
        secondaryContainer: c.surface2,
        onSecondaryContainer: c.ink,
        tertiary: c.pos,
        onTertiary: c.white,
        error: c.neg,
        onError: c.white,
        surface: c.paper,
        onSurface: c.ink,
        onSurfaceVariant: c.ink2,
        outline: c.lineStrong,
        outlineVariant: c.line,
        scrim: c.scrim,
        surfaceContainerLowest: c.paper,
        surfaceContainerLow: c.bg,
        surfaceContainer: c.surface2,
        surfaceContainerHigh: c.surface3,
        surfaceContainerHighest: c.surface3,
      ),
      textTheme: TextTheme(
        displayLarge: t.heroAmount,
        displayMedium: t.detailAmount,
        displaySmall: t.recordAmount,
        headlineLarge: t.pageTitle,
        headlineMedium: t.sectionTitle,
        headlineSmall: t.cardTitle,
        titleLarge: t.cardTitle,
        titleMedium: t.listTitle,
        titleSmall: t.secondary,
        bodyLarge: t.chat,
        bodyMedium: t.body,
        bodySmall: t.secondary,
        labelLarge: t.listTitle,
        labelMedium: t.badge,
        labelSmall: t.caption,
      ).apply(bodyColor: c.ink, displayColor: c.ink),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.lineStrong),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.paper,
        modalBarrierColor: c.scrim,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.snackBg,
        contentTextStyle: t.secondary.copyWith(color: c.snackInk),
        actionTextColor: c.snackAction,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      extensions: [c, t, JiabuDecor.paper(c), const JiabuMotion()],
    );
  }
}
