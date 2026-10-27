import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class JiabuTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  JiabuTestBinding();
  const defaultFont =
      '/opt/jiabu/dev-tools/test-fonts/NotoSansCJKsc-Regular.otf';
  final fontPath = Platform.environment['JIABU_TEST_FONT'] ?? defaultFont;
  final bytes = await File(fontPath).readAsBytes();
  // Back Material's default family with the fixed test font, never App assets.
  final loader = FontLoader('Roboto')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
  await testMain();
}
