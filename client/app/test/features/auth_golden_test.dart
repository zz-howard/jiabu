@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';

import 'auth_screens_test.dart' show pumpAuth;

// Every path is relative to this test file:
// ../goldens/auth/<state>_<zh|en>_<pine|indigo>_w<360|430>_text<100|200>.png
// The state names below are the exact filename stems. PNGs are produced and
// reviewed by luna.coco on the fixed build host, never hand-written here.
void main() {
  final cases = <String, Widget Function()>{
    for (final name in [
      'server_empty',
      'server_saved',
      'server_invalid',
      'server_busy',
      'server_unreachable',
    ])
      name: () => ServerAddressScreen(
        state: AuthUiState(
          servers: name == 'server_saved'
              ? ['https://example.invalid/proxy/']
              : const [],
          busy: name == 'server_busy',
          errorCode: name == 'server_invalid'
              ? 'invalid_server_address'
              : name == 'server_unreachable'
              ? 'network'
              : null,
        ),
        onSelect: (_) {},
      ),
    for (final name in [
      'login_initial',
      'login_busy',
      'login_invalid',
      'login_limited',
      'login_expired',
      'login_disabled',
    ])
      name: () => LoginScreen(
        state: AuthUiState(
          server: 'https://example.invalid/',
          busy: name == 'login_busy',
          errorCode: switch (name) {
            'login_invalid' => 'unauthenticated',
            'login_limited' => 'rate_limited',
            'login_expired' => 'session_expired',
            'login_disabled' => 'account_disabled',
            _ => null,
          },
        ),
        onLogin: (a, b) {},
        onServer: () {},
      ),
    for (final name in [
      'password_normal',
      'password_forced',
      'password_invalid',
      'password_busy',
      'password_failed',
    ])
      name: () => ChangePasswordScreen(
        state: AuthUiState(
          forcedPassword: name == 'password_forced',
          busy: name == 'password_busy',
          errorCode: name == 'password_invalid'
              ? 'invalid_new_password'
              : name == 'password_failed'
              ? 'network'
              : null,
        ),
        onSave: (a, b, c) {},
        onBack: () {},
      ),
    'switch_pending': () => Scaffold(
      body: SwitchPartitionPrompt(count: 3, onContinue: () {}, onCancel: () {}),
    ),
    for (final status in [
      SyncStatus.idle,
      SyncStatus.clientTooOld,
      SyncStatus.serverTooOld,
    ])
      'session_${status.name}': () => SessionStatusScreen(
        state: AuthUiState(syncStatus: status),
        onPassword: () {},
        onSwitch: () {},
        onLogout: () {},
      ),
    'session_admin_reset': () => SessionStatusScreen(
      state: AuthUiState(adminResetAt: DateTime(2026)),
      onPassword: () {},
      onSwitch: () {},
      onLogout: () {},
    ),
    'session_space_cleared': () => SessionStatusScreen(
      state: const AuthUiState(spaceCleared: true, clearedCount: 3),
      onDismissNotice: () {},
      onPassword: () {},
      onSwitch: () {},
      onLogout: () {},
    ),
  };
  for (final entry in cases.entries) {
    for (final locale in ['zh', 'en']) {
      for (final accent in ['pine', 'indigo']) {
        for (final width in [360, 430]) {
          for (final text in [100, 200]) {
            final path =
                '../goldens/auth/${entry.key}_${locale}_$accent'
                '_w${width}_text$text.png';
            testWidgets(path, (tester) async {
              await pumpAuth(
                tester,
                entry.value(),
                width: width.toDouble(),
                scale: text / 100,
                locale: locale,
                accent: accent,
              );
              expect(tester.takeException(), isNull);
              await expectLater(
                find.byKey(const Key('auth-golden')),
                matchesGoldenFile(path),
              );
            });
          }
        }
      }
    }
  }
}
