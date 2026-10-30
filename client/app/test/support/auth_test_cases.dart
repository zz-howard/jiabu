import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view/welcome_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';

typedef AuthTestCase = ({
  String state,
  Widget Function() builder,
  String? tapKey,
  int minimumPairs,
});

final authPrimaryTestCases = <AuthTestCase>[
  (
    state: 'welcome',
    builder: () => WelcomeScreen(busy: false, onStart: () {}, onLogin: () {}),
    tapKey: null,
    minimumPairs: 4,
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
    minimumPairs: 5,
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
    minimumPairs: 5,
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
    minimumPairs: 6,
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
    minimumPairs: 8,
  ),
];

final authSecondaryTestCases = <AuthTestCase>[
  (
    state: 'server_unreachable',
    builder: () => ServerAddressScreen(
      state: const AuthUiState(page: AuthPage.server, errorCode: 'network'),
      onSelect: (_) {},
    ),
    tapKey: null,
    minimumPairs: 6,
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
    minimumPairs: 7,
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
    minimumPairs: 7,
  ),
  (
    state: 'password_forced',
    builder: () => ChangePasswordScreen(
      state: const AuthUiState(page: AuthPage.password, forcedPassword: true),
      onSave: (_, _, _) {},
      onBack: () {},
    ),
    tapKey: null,
    minimumPairs: 6,
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
    minimumPairs: 6,
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
    minimumPairs: 3,
  ),
  (
    state: 'session_admin_reset',
    builder: () => SessionStatusScreen(
      state: AuthUiState(page: AuthPage.session, adminResetAt: DateTime(2026)),
      onPassword: () {},
      onSwitch: () {},
      onLogout: () {},
    ),
    tapKey: null,
    minimumPairs: 4,
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
    minimumPairs: 5,
  ),
  (
    state: 'switch_pending',
    builder: () => Scaffold(
      body: SwitchPartitionPrompt(count: 3, onContinue: () {}, onCancel: () {}),
    ),
    tapKey: null,
    minimumPairs: 2,
  ),
];

List<AuthTestCase> get allAuthTestCases => [
  ...authPrimaryTestCases,
  ...authSecondaryTestCases,
];
