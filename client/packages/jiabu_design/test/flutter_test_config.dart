import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  JiabuTestBinding();
  const defaultFont =
      '/opt/jiabu/dev-tools/test-fonts/NotoSansCJKsc-Regular.otf';
  final systemPath = Platform.environment['JIABU_TEST_FONT'] ?? defaultFont;
  final systemBytes = ByteData.sublistView(
    await File(systemPath).readAsBytes(),
  );
  for (final family in ['Roboto', JiabuType.systemSansFamily]) {
    await (FontLoader(family)..addFont(Future.value(systemBytes))).load();
  }
  const fonts = {
    JiabuType.numeralsFamily: 'jiabu_numerals.ttf',
    JiabuType.handFamily: 'jiabu_hand.ttf',
    JiabuType.serifFamily: 'jiabu_serif.otf',
  };
  for (final entry in fonts.entries) {
    final bytes = await File('assets/fonts/${entry.value}').readAsBytes();
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  await testMain();
}
