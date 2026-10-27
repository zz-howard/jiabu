@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/app.dart';

void main() {
  testWidgets('blank home at 390x844 and DPR 2.75', (tester) async {
    tester.view.devicePixelRatio = 2.75;
    tester.view.physicalSize = const Size(390 * 2.75, 844 * 2.75);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const boundaryKey = Key('golden-boundary');
    await tester.pumpWidget(
      const RepaintBoundary(key: boundaryKey, child: JiabuApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Text), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('blank-accent'))),
      const Size(96, 96),
    );
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    addTearDown(image.dispose);
    await expectLater(
      image,
      matchesGoldenFile('goldens/blank_home_390x844_2.75.png'),
    );
  });
}
