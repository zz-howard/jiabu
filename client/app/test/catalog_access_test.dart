import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/app.dart';
import 'package:jiabu/features/catalog/catalog_screen.dart';

void main() {
  testWidgets('production has no catalog route', (tester) async {
    await tester.pumpWidget(const JiabuApp());
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
  testWidgets('dev can inject the catalog', (tester) async {
    await tester.pumpWidget(const JiabuApp(home: CatalogScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
