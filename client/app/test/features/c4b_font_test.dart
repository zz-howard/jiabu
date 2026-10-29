import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  testWidgets('restored_c4_strings_use_the_hand_font_stack', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l = AppLocalizations.of(context);
            return Scaffold(
              body: Column(
                children: [
                  HandText(l.handC4Locked),
                  HandText(l.handC4KeysSubtitle),
                ],
              ),
            );
          },
        ),
      ),
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.fontFamily, JiabuType.numeralsFamily);
      expect(text.style?.fontFamilyFallback, contains(JiabuType.handFamily));
    }
  });
}
