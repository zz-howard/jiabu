import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
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
