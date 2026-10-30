import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Which table tags an SFNT file carries.
Set<String> _tables(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return {
    for (var i = 0; i < data.getUint16(4); i++)
      String.fromCharCodes(bytes.sublist(12 + i * 16, 16 + i * 16)),
  };
}

int _usWeightClass(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < data.getUint16(4); i++) {
    final entry = 12 + i * 16;
    if (String.fromCharCodes(bytes.sublist(entry, entry + 4)) == 'OS/2') {
      return data.getUint16(data.getUint32(entry + 8) + 4);
    }
  }
  throw StateError('no OS/2 table');
}

Future<int> _ink(WidgetTester tester, FontWeight weight) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: Text(
              '¥21,103.90',
              style: TextStyle(
                fontFamily: JiabuType.numeralsFamily,
                fontSize: 120,
                fontWeight: weight,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData())!;
    var dark = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) < 128) dark++;
    }
    return dark;
  }))!;
}

void main() {
  // The audit suspected that the numerals font, cut from the variable
  // Caveat[wght], renders at its default 400 instead of the SemiBold 600 of the
  // original design. It does not: the file is a static 600 instance.
  test('jiabu_numerals.ttf is a static SemiBold 600 instance', () {
    final bytes = File('assets/fonts/jiabu_numerals.ttf').readAsBytesSync();
    expect(_tables(bytes), isNot(contains('fvar')), reason: 'not variable');
    expect(_usWeightClass(bytes), 600);
  });
  testWidgets('rendered Caveat numerals carry SemiBold ink at every weight', (
    tester,
  ) async {
    // Measured with the pinned harness at 120px: Caveat 400 draws about 7.2k
    // dark pixels, 600 about 9.6k, 700 about 10.8k. The single static file must
    // land on 600 whatever weight the style asks for, and below w800 Flutter
    // must not fake-bold it.
    final w400 = await _ink(tester, FontWeight.w400);
    final w600 = await _ink(tester, FontWeight.w600);
    final w700 = await _ink(tester, FontWeight.w700);
    expect(w600, inInclusiveRange(8800, 10400));
    expect(w400, w600);
    expect(w700, w600);
  });
  test('no theme text style fakes a bold Caveat', () {
    const type = JiabuType();
    final styles = {
      'subtitle': type.subtitle,
      'englishSubtitle': type.englishSubtitle,
      'heroAmount': type.heroAmount,
      'detailAmount': type.detailAmount,
      'recordAmount': type.recordAmount,
      'balanceAmount': type.balanceAmount,
      'listAmount': type.listAmount,
      'inlineAmount': type.inlineAmount,
      'date': type.date,
      'tapeDate': type.tapeDate,
    };
    for (final entry in styles.entries) {
      if (entry.value.fontFamily == JiabuType.numeralsFamily) {
        expect(
          entry.value.fontWeight!.value,
          lessThan(800),
          reason: '${entry.key} would be synthetic-bolded',
        );
      }
    }
  });
}
