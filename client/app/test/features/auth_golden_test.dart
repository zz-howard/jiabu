@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view/welcome_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';

import 'auth_screens_test.dart' show pumpAuth;

typedef _GoldenCase = ({
  String state,
  Widget Function() builder,
  String? tapKey,
});

typedef _Variant = ({String locale, int width, double scale, String suffix});

const _fullVariants = <_Variant>[
  (locale: 'zh', width: 360, scale: 1.0, suffix: 'zh_pine_w360_text100'),
  (locale: 'zh', width: 430, scale: 2.0, suffix: 'zh_pine_w430_text200'),
  (locale: 'en', width: 360, scale: 1.0, suffix: 'en_pine_w360_text100'),
];

// Error, busy and secondary screens: one variant each, so the C2 auth set's
// states keep pixel coverage on the new AuthFrame without a full matrix.
const _stateVariants = <_Variant>[
  (locale: 'zh', width: 360, scale: 1.0, suffix: 'zh_pine_w360_text100'),
];

void main() {
  final cases = <_GoldenCase>[
    (
      state: 'welcome',
      builder: () => WelcomeScreen(busy: false, onStart: () {}, onLogin: () {}),
      tapKey: null,
    ),
    (
      state: 'server_collapsed',
      builder: () => ServerAddressScreen(
        state: const AuthUiState(
          page: AuthPage.server,
          defaultServer: 'https://example.invalid/',
        ),
        onSelect: (_) {},
      ),
      tapKey: null,
    ),
    (
      state: 'server_expanded',
      builder: () => ServerAddressScreen(
        state: const AuthUiState(
          page: AuthPage.server,
          defaultServer: 'https://example.invalid/',
        ),
        onSelect: (_) {},
      ),
      tapKey: 'advanced-settings',
    ),
    (
      state: 'login_connected',
      builder: () => LoginScreen(
        state: const AuthUiState(
          page: AuthPage.login,
          server: 'https://example.invalid/',
          defaultServer: 'https://example.invalid/',
          serverProbeSucceeded: true,
        ),
        onLogin: (_, _) {},
        onServer: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'invite_placeholder',
      builder: () => LoginScreen(
        state: const AuthUiState(
          page: AuthPage.login,
          server: 'https://example.invalid/',
        ),
        onLogin: (_, _) {},
        onServer: () {},
      ),
      tapKey: 'invite-signup',
    ),
  ];
  final stateCases = <_GoldenCase>[
    (
      state: 'server_unreachable',
      builder: () => ServerAddressScreen(
        state: const AuthUiState(page: AuthPage.server, errorCode: 'network'),
        onSelect: (_) {},
      ),
      tapKey: null,
    ),
    (
      state: 'login_invalid',
      builder: () => LoginScreen(
        state: const AuthUiState(
          page: AuthPage.login,
          server: 'https://example.invalid/',
          errorCode: 'unauthenticated',
        ),
        onLogin: (_, _) {},
        onServer: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'login_busy',
      builder: () => LoginScreen(
        state: const AuthUiState(
          page: AuthPage.login,
          server: 'https://example.invalid/',
          busy: true,
        ),
        onLogin: (_, _) {},
        onServer: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'password_forced',
      builder: () => ChangePasswordScreen(
        state: const AuthUiState(page: AuthPage.password, forcedPassword: true),
        onSave: (_, _, _) {},
        onBack: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'password_invalid',
      builder: () => ChangePasswordScreen(
        state: const AuthUiState(
          page: AuthPage.password,
          errorCode: 'invalid_new_password',
        ),
        onSave: (_, _, _) {},
        onBack: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'session_idle',
      builder: () => SessionStatusScreen(
        state: const AuthUiState(page: AuthPage.session),
        onPassword: () {},
        onSwitch: () {},
        onLogout: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'session_admin_reset',
      builder: () => SessionStatusScreen(
        state: AuthUiState(
          page: AuthPage.session,
          adminResetAt: DateTime(2026),
        ),
        onPassword: () {},
        onSwitch: () {},
        onLogout: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'session_space_cleared',
      builder: () => SessionStatusScreen(
        state: const AuthUiState(
          page: AuthPage.session,
          spaceCleared: true,
          clearedCount: 3,
        ),
        onDismissNotice: () {},
        onPassword: () {},
        onSwitch: () {},
        onLogout: () {},
      ),
      tapKey: null,
    ),
    (
      state: 'switch_pending',
      builder: () => Scaffold(
        body: SwitchPartitionPrompt(
          count: 3,
          onContinue: () {},
          onCancel: () {},
        ),
      ),
      tapKey: null,
    ),
  ];
  for (final (samples, variants) in [
    (cases, _fullVariants),
    (stateCases, _stateVariants),
  ]) {
    for (final sample in samples) {
      for (final variant in variants) {
        final path = '../goldens/c4b/${sample.state}_${variant.suffix}.png';
        testWidgets(path, (tester) async {
          await pumpAuth(
            tester,
            sample.builder(),
            width: variant.width.toDouble(),
            scale: variant.scale,
            locale: variant.locale,
          );
          if (sample.tapKey case final String key) {
            final target = find.byKey(Key(key));
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
          }
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
