import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

const catalogBoundary = Key('catalog-boundary');

Future<void> pumpCatalogCase(
  WidgetTester tester,
  CatalogCase sample, {
  required double width,
  required double scale,
  Locale locale = const Locale('zh'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: JiabuTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: catalogBoundary, child: child),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(builder: sample.builder),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (sample.component == 'paper_sheet' && sample.state == 'modal') {
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
  }
}
