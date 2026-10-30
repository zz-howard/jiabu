import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';

import 'features/auth_screens_test.dart' show pumpAuth;

void main() {
  testWidgets('dump', (tester) async {
    final s = tester.ensureSemantics();
    await pumpAuth(
      tester,
      ServerAddressScreen(
        state: const AuthUiState(page: AuthPage.server, errorCode: 'network'),
        onSelect: (_) {},
      ),
    );
    final e = find.byType(EditableText);
    debugPrint('fields=${e.evaluate().length}');
    await tester.ensureVisible(e.first);
    await tester.pump();
    debugPrint(
      'label=[${tester.getSemantics(e.first).getSemanticsData().label}]',
    );
    debugDumpSemanticsTree();
    s.dispose();
  });
}
