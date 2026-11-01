import 'dart:async';
import 'dart:convert';

import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/server_config.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_view_model.g.dart';

@Riverpod(keepAlive: true)
class AuthViewModel extends _$AuthViewModel {
  bool _initialized = false;
  @override
  AuthUiState build() {
    final runtime = ref.watch(appRuntimeProvider);
    final subscription = runtime.events.listen((_) {
      if (!ref.mounted) {
        return;
      }
      final session = runtime.auth.current;
      final signOut = runtime.auth.signOutCode;
      state = state.copyWith(
        authenticated: session != null,
        forcedPassword: session?.passwordChangeRequired ?? false,
        adminResetAt: session?.adminResetAt,
        page: session == null
            ? (state.authenticated ? AuthPage.login : state.page)
            : session.passwordChangeRequired
            ? AuthPage.password
            : state.authenticated &&
                  state.page == AuthPage.password &&
                  !state.forcedPassword
            ? AuthPage.password
            : AuthPage.session,
        partitionRevision: runtime.revision,
        syncStatus: runtime.status,
        // Like a failed resume: a disabled account or another account's
        // session keeps its own message instead of "session expired".
        errorCode: session != null
            ? state.errorCode
            : signOut == 'account_disabled' ||
                  signOut == 'session_user_mismatch'
            ? signOut
            : runtime.status == SyncStatus.loginRequired
            ? 'session_expired'
            : state.errorCode,
        spaceCleared: runtime.spaceCleared,
        clearedCount: runtime.clearedCount,
      );
    });
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    return const AuthUiState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> initialize({String defaultServer = defaultServerAddress}) async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    state = state.copyWith(busy: true);
    final settings = ref.read(appRuntimeProvider).settings;
    final servers = await settings.servers();
    final saved = await settings.current();
    final hasConfiguredServer = saved != null || servers.isNotEmpty;
    var configuredDefault = '';
    if (defaultServer.trim().isNotEmpty) {
      try {
        configuredDefault = _normalizeSecureServer(defaultServer);
      } on FormatException {
        configuredDefault = '';
      }
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      servers: servers,
      server: saved?.server ?? servers.firstOrNull ?? '',
      defaultServer: configuredDefault,
    );
    final result = await _auth.resume();
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok<AuthSession?>(:final value):
        if (value != null) {
          _apply(value);
        } else {
          state = state.copyWith(
            busy: false,
            page: hasConfiguredServer ? AuthPage.login : AuthPage.welcome,
          );
        }
      case Failure<AuthSession?>(:final code, :final status):
        state = state.copyWith(
          busy: false,
          page: AuthPage.login,
          errorCode: status == 401 && code != 'account_disabled'
              ? 'session_expired'
              : code,
        );
    }
  }

  void startSetup() {
    if (!state.busy) {
      state = state.copyWith(page: AuthPage.server, errorCode: null);
    }
  }

  Future<void> useDefaultServer() async {
    if (state.defaultServer.isEmpty) {
      startSetup();
      return;
    }
    state = state.copyWith(page: AuthPage.server, errorCode: null);
    await selectServer(state.defaultServer);
  }

  void _apply(AuthSession session) {
    state = state.copyWith(
      busy: false,
      authenticated: true,
      server: session.partition.server,
      forcedPassword: session.passwordChangeRequired,
      adminResetAt: session.adminResetAt,
      errorCode: null,
      page: session.passwordChangeRequired
          ? AuthPage.password
          : AuthPage.session,
      partitionRevision: ref.read(appRuntimeProvider).revision,
    );
  }

  Future<void> selectServer(String address) async {
    if (state.busy) {
      return;
    }
    try {
      final server = _normalizeSecureServer(address);
      state = state.copyWith(
        busy: true,
        errorCode: null,
        serverProbeSucceeded: false,
      );
      final runtime = ref.read(appRuntimeProvider);
      final handshake = VersionHandshakeService(
        runtime.api(server, null),
        build: runtime.device.build,
        channel: runtime.device.channel,
        clearCache: () => runtime.settings.clearMeta(server),
        readCache: () => runtime.settings.meta(server),
        writeCache: (meta) => runtime.settings.saveMeta(server, meta),
      );
      final compatible = await handshake.check();
      await runtime.settings.rememberServer(server);
      final servers = await runtime.settings.servers();
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        server: server,
        page: AuthPage.login,
        busy: false,
        errorCode: null,
        servers: servers,
        syncStatus: compatible,
        serverProbeSucceeded: true,
      );
    } on FormatException {
      state = state.copyWith(
        busy: false,
        errorCode: 'invalid_server_address',
        serverProbeSucceeded: false,
      );
    } on ApiError catch (error) {
      state = state.copyWith(
        busy: false,
        errorCode: error.code,
        serverProbeSucceeded: false,
      );
    }
  }

  Future<void> login(String username, String password) async {
    if (state.busy) {
      return;
    }
    if (username.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(errorCode: 'credentials_required');
      return;
    }
    state = state.copyWith(busy: true, errorCode: null);
    final result = await _auth.login(state.server, username, password);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok<AuthSession>(:final value):
        _apply(value);
      case Failure<AuthSession>(:final code):
        state = state.copyWith(busy: false, errorCode: code);
    }
  }

  Future<void> changePassword(
    String current,
    String next,
    String repeated,
  ) async {
    if (state.busy) {
      return;
    }
    if (utf8.encode(next).length < 8 ||
        utf8.encode(next).length > 1024 ||
        next != repeated) {
      state = state.copyWith(errorCode: 'invalid_new_password');
      return;
    }
    state = state.copyWith(busy: true, errorCode: null);
    final result = await _auth.changePassword(current, next);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok<void>():
        state = state.copyWith(
          busy: false,
          forcedPassword: false,
          page: AuthPage.session,
        );
      case Failure<void>(:final code):
        state = state.copyWith(busy: false, errorCode: code);
    }
  }

  void showPassword() {
    state = state.copyWith(page: AuthPage.password, errorCode: null);
  }

  Future<void> dismissNotice() =>
      ref.read(appRuntimeProvider).dismissRemovalNotice();
  void backFromPassword() {
    if (state.forcedPassword) {
      unawaited(logout());
    } else {
      state = state.copyWith(page: AuthPage.session, errorCode: null);
    }
  }

  Future<void> requestSwitch() async {
    if (state.busy) {
      return;
    }
    final count = await _auth.pendingCount();
    if (!ref.mounted) {
      return;
    }
    if (count > 0) {
      state = state.copyWith(switchCount: count);
    } else {
      await confirmSwitch();
    }
  }

  void cancelSwitch() {
    state = state.copyWith(switchCount: null);
  }

  Future<void> confirmSwitch() async {
    await _auth.logout();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      page: AuthPage.server,
      authenticated: false,
      forcedPassword: false,
      switchCount: null,
      adminResetAt: null,
      errorCode: null,
      serverProbeSucceeded: false,
    );
  }

  Future<void> logout() async {
    await _auth.logout();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      page: AuthPage.login,
      authenticated: false,
      forcedPassword: false,
      adminResetAt: null,
      errorCode: null,
    );
  }
}

String _normalizeSecureServer(String address) {
  if (!address.trimLeft().toLowerCase().startsWith('https://')) {
    throw const FormatException('invalid_server_address');
  }
  return normalizeServer(address);
}
