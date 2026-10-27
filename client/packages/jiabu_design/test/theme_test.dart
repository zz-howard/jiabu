import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  test('body and control tokens explicitly use logical system Sans', () {
    const type = JiabuType();
    final styles = {
      'body': type.body,
      'chat': type.chat,
      'listTitle': type.listTitle,
      'secondary': type.secondary,
      'caption': type.caption,
      'badge': type.badge,
    };
    for (final entry in styles.entries) {
      expect(
        entry.value.fontFamily,
        JiabuType.systemSansFamily,
        reason: entry.key,
      );
    }
  });

  test('Material text themes resolve to design font families', () {
    final theme = JiabuTheme.light();
    const families = {
      JiabuType.systemSansFamily,
      JiabuType.handFamily,
      JiabuType.numeralsFamily,
      JiabuType.serifFamily,
    };
    for (final textTheme in [theme.textTheme, theme.primaryTextTheme]) {
      for (final style in [
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineLarge,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.titleSmall,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
        textTheme.labelSmall,
      ]) {
        expect(style?.fontFamily, isIn(families), reason: '$style');
      }
    }
  });

  testWidgets('light theme stays light on a dark platform', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    Brightness? brightness;
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: Builder(
          builder: (context) {
            brightness = Theme.of(context).brightness;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
