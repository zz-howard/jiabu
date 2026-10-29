import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decode every [Image] in the tree before a golden capture.
///
/// Asset images decode on real I/O, which the fake-async test zone never
/// runs; without this the capture shows empty boxes where the Logo or mascot
/// should be. Fails if any visible image is still undecoded afterwards.
Future<void> settleImages(WidgetTester tester) async {
  final images = find.byType(Image).evaluate().toList();
  if (images.isEmpty) {
    return;
  }
  await tester.runAsync(() async {
    for (final element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  for (final render in tester.renderObjectList<RenderImage>(
    find.byType(RawImage),
  )) {
    expect(render.image, isNotNull, reason: 'image not decoded before capture');
  }
}
