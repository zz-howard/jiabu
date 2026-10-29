import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

import 'image_harness.dart';

const catalogBoundary = Key('catalog-boundary');
const catalogContent = Key('catalog-content');

/// Golden view height. Content taller than this would be cut off silently.
const catalogViewHeight = 1000.0;

/// Fails when the sample does not fit inside the golden view.
void expectCatalogFits(WidgetTester tester, String name) {
  final bottom = tester.getRect(find.byKey(catalogContent)).bottom;
  expect(
    bottom,
    lessThanOrEqualTo(catalogViewHeight),
    reason: '$name ends at $bottom, below the ${catalogViewHeight}px view',
  );
}

Future<void> pumpCatalogCase(
  WidgetTester tester,
  CatalogCase sample, {
  required double width,
  required double scale,
  Locale locale = const Locale('zh'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, catalogViewHeight);
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
              child: KeyedSubtree(
                key: catalogContent,
                child: Builder(builder: sample.builder),
              ),
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
  await settleImages(tester);
}
