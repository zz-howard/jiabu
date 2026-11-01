import 'dart:async';
import 'dart:convert';

import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/session_store_service.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

final class AuthSession {
  const AuthSession({
    required this.user,
    required this.partition,
    required this.passwordChangeRequired,
    required this.generation,
    this.adminResetAt,
  });
  final UserDto user;
  final Partition partition;
  final bool passwordChangeRequired;

  /// Ownership captured by the transaction that accepted this session.
  final int generation;
  final DateTime? adminResetAt;
}

abstract interface class AuthRepository {
  Future<Result<AuthSession>> login(
    String server,
    String username,
    String password,
  );
  Future<Result<AuthSession?>> resume();
  Future<Result<void>> changePassword(
    String currentPassword,
    String newPassword,
  );
  Future<int> pendingCount();
  Future<void> logout();
}

final class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required this.databases,
    required this.settings,
    required this.sessions,
    required this.apiFactory,
    this.onChanged,
    this.onSessionUpdated,
    this.activateOnResume = true,
  });
  final DatabaseManager databases;
  final AppSettingsService settings;
  final SessionStore sessions;
  final ApiClient Function(String server, Partition? partition) apiFactory;
  final void Function(AuthSession?)? onChanged;

  /// Session details changed without a new runtime: a refreshed profile or a
  /// recorded [signOutCode].
  final void Function()? onSessionUpdated;
  final bool activateOnResume;
  AuthSession? current;

  /// Why a background identity check signed the session out, when that is
  /// more specific than an expired session (`account_disabled`,
  /// `session_user_mismatch`, or the 401 code). Cleared on the next sign-out.
  String? signOutCode;
  AuthSession? _lastCleared;
  int _profileWrites = 0;
  PartitionDatabase? handle;
  Future<void> _logoutWork = Future<void>.value();
  Future<void> get logoutWork => _logoutWork;
  Future<void> _verificationWork = Future<void>.value();

  /// Background identity checks started by local-first resumes.
  Future<void> get verificationWork => _verificationWork;

  @override
  Future<Result<AuthSession>> login(
    String server,
    String username,
    String password,
  ) async {
    try {
      final normalized = normalizeServer(server);
      final response = await apiFactory(normalized, null).login(
        LoginRequestDto(
          username: username.trim(),
          password: password,
          deviceName: 'Jiabu mobile',
        ),
      );
      if (!const {'full', 'password_change'}.contains(response.sessionKind)) {
        return const Failure('invalid_response');
      }
      if (current != null) {
        await logout();
      }
      final partition = Partition(normalized, response.user.id);
      await settings.rememberServer(normalized);
      await settings.setCurrent(partition);
      handle = await databases.open(partition);
      final restricted = response.sessionKind == 'password_change';
      final opened = handle;
      if (opened == null) {
        return const Failure('database_unavailable');
      }
      final loginGeneration = await opened.store.transaction(() async {
        await opened.store.lockRuntime();
        await sessions.write(partition, response.token);
        await opened.store.saveIdentity(
          response.user.toJson(),
          response.sessionKind,
        );
        return await opened.store.activate(authenticated: false);
      });
      var generation = loginGeneration;
      var user = response.user;
      if (!restricted) {
        user = await apiFactory(normalized, partition).me();
        if (user.id != partition.userId) {
          await invalidate(partition, expectedGeneration: loginGeneration);
          return const Failure('session_user_mismatch');
        }
        final accepted = await opened.store.transaction(() async {
          await opened.store.lockRuntime();
          if ((await opened.store.runtime())['generation'] != loginGeneration) {
            return null;
          }
          await opened.store.saveIdentity(user.toJson(), 'full');
          return await opened.store.activate(authenticated: true);
        });
        if (accepted == null) {
          return const Failure('stale_response');
        }
        generation = accepted;
      }
      final session = AuthSession(
        user: user,
        partition: partition,
        passwordChangeRequired: restricted,
        generation: generation,
        adminResetAt: response.adminResetAt,
      );
      current = session;
      onChanged?.call(session);
      return Ok(session);
    } on ApiError catch (error) {
      return Failure(
        error.code,
        status: error.status,
        requestId: error.requestId,
      );
    } on FormatException {
      return const Failure('invalid_server_address');
    } on Object {
      return const Failure('local_storage_unavailable');
    }
  }

  @override
  Future<Result<AuthSession?>> resume() async {
    try {
      return await _resume();
    } on Object {
      return const Failure('local_storage_unavailable');
    }
  }

  Future<Result<AuthSession?>> _resume() async {
    final partition = await settings.current();
    if (partition == null || await sessions.read(partition) == null) {
      return const Ok(null);
    }
    handle = await databases.open(partition);
    final resumeHandle = handle;
    if (resumeHandle == null) {
      return const Failure('database_unavailable');
    }
    final resumeRow = await resumeHandle.store.runtime();
    if (!activateOnResume && resumeRow['authenticated'] != 1) {
      handle = null;
      return const Ok(null);
    }
    final resumeGeneration = requireValue<int>(resumeRow['generation']);
    if (resumeRow['authenticated'] == 1 &&
        resumeRow['session_kind'] == 'full' &&
        _persistedUser(resumeRow, partition) != null) {
      // Local-first: all data is local, so open it from the identity accepted
      // earlier and confirm it online without blocking the first frame.
      final session = await _resumePersisted(
        resumeHandle,
        partition,
        resumeGeneration,
      );
      if (session == null) {
        return const Failure('stale_response');
      }
      current = session;
      onChanged?.call(session);
      // Started after onChanged so the request belongs to this runtime.
      _verifyInBackground(session, resumeHandle);
      return Ok(session);
    }
    try {
      final user = await apiFactory(partition.server, partition).me();
      if (user.id != partition.userId) {
        return const Failure('session_user_mismatch');
      }
      final accepted = await resumeHandle.store.transaction(() async {
        await resumeHandle.store.lockRuntime();
        if ((await resumeHandle.store.runtime())['generation'] !=
            resumeGeneration) {
          return null;
        }
        await resumeHandle.store.saveIdentity(user.toJson(), 'full');
        if (activateOnResume) {
          return await resumeHandle.store.activate(authenticated: true);
        }
        return resumeGeneration;
      });
      if (accepted == null) {
        return const Failure('stale_response');
      }
      final session = AuthSession(
        user: user,
        partition: partition,
        passwordChangeRequired: false,
        generation: accepted,
      );
      current = session;
      onChanged?.call(session);
      return Ok(session);
    } on ApiError catch (error) {
      if ((await resumeHandle.store.runtime())['generation'] !=
          resumeGeneration) {
        return Failure(
          error.status == 401 ? error.code : 'stale_response',
          status: error.status,
        );
      }
      if (error.code == 'network' || error.status == 426) {
        final session = await _resumePersisted(
          resumeHandle,
          partition,
          resumeGeneration,
        );
        if (session != null) {
          current = session;
          onChanged?.call(session);
          return Ok(session);
        }
      }
      if (error.status == 401) {
        await invalidate(partition, expectedGeneration: resumeGeneration);
      }
      if (error.code == 'password_change_required') {
        // /me is forbidden for restricted sessions; allow only the password
        // page.
        final session = await _restrict(
          resumeHandle,
          partition,
          resumeGeneration,
        );
        if (session == null) {
          return const Failure('stale_response');
        }
        current = session;
        onChanged?.call(session);
        return Ok(session);
      }
      return Failure(
        error.code,
        status: error.status,
        requestId: error.requestId,
      );
    }
  }

  /// Rebuilds the session from the identity persisted by an earlier online
  /// check, or null when the generation moved or no identity was saved.
  Future<AuthSession?> _resumePersisted(
    PartitionDatabase opened,
    Partition partition,
    int expectedGeneration,
  ) => opened.store.transaction(() async {
    await opened.store.lockRuntime();
    final persisted = await opened.store.runtime();
    if (persisted['generation'] != expectedGeneration) {
      return null;
    }
    final user = _persistedUser(persisted, partition);
    if (user == null) {
      return null;
    }
    final restricted = persisted['session_kind'] == 'password_change';
    final generation = activateOnResume
        ? await opened.store.activate(authenticated: !restricted)
        : expectedGeneration;
    return AuthSession(
      user: user,
      partition: partition,
      passwordChangeRequired: restricted,
      generation: generation,
    );
  });

  /// The identity saved by an earlier online check, only when it belongs to
  /// [partition]'s account.
  static UserDto? _persistedUser(
    Map<String, Object?> row,
    Partition partition,
  ) {
    final identity = row['identity_json'] as String?;
    if (identity == null) {
      return null;
    }
    final user = UserDto.fromJson(
      (jsonDecode(identity) as Map<String, Object?>).cast<String, Object?>(),
    );
    return user.id == partition.userId ? user : null;
  }

  /// Same accepted session, even when its profile object was replaced.
  static bool _sameSession(AuthSession? a, AuthSession b) =>
      a != null &&
      a.partition.prefix == b.partition.prefix &&
      a.generation == b.generation &&
      a.user.id == b.user.id &&
      a.passwordChangeRequired == b.passwordChangeRequired;

  /// Activates a password-change-only session, or null when stale.
  Future<AuthSession?> _restrict(
    PartitionDatabase opened,
    Partition partition,
    int expectedGeneration,
  ) async {
    final generation = await opened.store.transaction(() async {
      await opened.store.lockRuntime();
      if ((await opened.store.runtime())['generation'] != expectedGeneration) {
        return null;
      }
      return await opened.store.activate(authenticated: false);
    });
    if (generation == null) {
      return null;
    }
    return AuthSession(
      user: UserDto(id: partition.userId, username: '', locale: 'system'),
      partition: partition,
      passwordChangeRequired: true,
      generation: generation,
    );
  }

  void _verifyInBackground(AuthSession session, PartitionDatabase opened) {
    // Late results are discarded by the guards below; a closed database or a
    // dead network must never surface as an unhandled error.
    final work = _verifyIdentity(session, opened).catchError((Object _) {});
    _verificationWork = Future.wait<void>([_verificationWork, work])
        .then((_) {});
    unawaited(_verificationWork);
  }

  /// Applies the online identity check to [session] only while it is still
  /// the current session and owns the runtime generation it was built with.
  Future<void> _verifyIdentity(
    AuthSession session,
    PartitionDatabase opened,
  ) async {
    final partition = session.partition;
    final profileWrites = _profileWrites;
    bool owns() => _sameSession(current, session);
    // A profile change made meanwhile (setLocale) is newer than this answer.
    bool profileUnchanged() => owns() && _profileWrites == profileWrites;
    try {
      final user = await apiFactory(partition.server, partition).me();
      if (!owns()) {
        return;
      }
      if (user.id != partition.userId) {
        await _dropSession(session, 'session_user_mismatch');
        return;
      }
      final accepted = await opened.store.transaction(() async {
        await opened.store.lockRuntime();
        if (!profileUnchanged() ||
            (await opened.store.runtime())['generation'] !=
                session.generation) {
          return false;
        }
        await opened.store.saveIdentity(user.toJson(), 'full');
        return true;
      });
      final latest = current;
      if (accepted &&
          profileUnchanged() &&
          latest != null &&
          user != latest.user) {
        // Same account and ownership; only the profile changed, so the
        // runtime built for this session stays and only observers refresh.
        current = AuthSession(
          user: user,
          partition: partition,
          passwordChangeRequired: latest.passwordChangeRequired,
          generation: latest.generation,
          adminResetAt: latest.adminResetAt,
        );
        onSessionUpdated?.call();
      }
    } on ApiError catch (error) {
      if (error.status == 401) {
        await _dropSession(session, error.code);
      }
      // Network, 426, 403 and other errors keep the local session: sync
      // reports them and the transport handles client-too-old.
    }
  }

  /// The authentication-lost path: revoke this session's ownership, then
  /// detach it even when another instance already moved the generation.
  /// [code] is recorded when this session (and not a newer one) ended,
  /// whether here or by the transport's own 401 handling.
  Future<void> _dropSession(AuthSession session, String code) async {
    if (_sameSession(current, session)) {
      await invalidate(
        session.partition,
        expectedGeneration: session.generation,
      );
      if (_sameSession(current, session)) {
        clearLocalSession();
      }
    }
    if (current == null && _sameSession(_lastCleared, session)) {
      signOutCode = code;
      onSessionUpdated?.call();
    }
  }

  @override
  Future<Result<void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final session = current;
    if (session == null) {
      return const Failure('unauthenticated');
    }
    final opened = handle;
    if (opened == null) {
      return const Failure('database_unavailable');
    }
    final expectedGeneration = session.generation;
    try {
      final api = apiFactory(session.partition.server, session.partition);
      await api.changePassword(
        ChangePasswordDto(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      final user = await api.me();
      final accepted = await opened.store.transaction(() async {
        await opened.store.lockRuntime();
        if (!_sameSession(current, session) ||
            (await opened.store.runtime())['generation'] !=
                expectedGeneration) {
          return null;
        }
        await opened.store.saveIdentity(user.toJson(), 'full');
        return await opened.store.activate(authenticated: true);
      });
      if (accepted == null) {
        return const Failure('stale_response');
      }
      final next = AuthSession(
        user: user,
        partition: session.partition,
        passwordChangeRequired: false,
        generation: accepted,
        adminResetAt: session.adminResetAt,
      );
      current = next;
      onChanged?.call(next);
      return const Ok(null);
    } on ApiError catch (error) {
      return Failure(
        error.code,
        status: error.status,
        requestId: error.requestId,
      );
    } on Object {
      return const Failure('local_storage_unavailable');
    }
  }

  @override
  Future<int> pendingCount() async {
    final opened = handle;
    return opened == null ? 0 : await databases.pendingCount(opened);
  }

  Future<Result<void>> setLocale(String locale) async {
    final session = current;
    final opened = handle;
    if (session == null || opened == null) {
      return const Failure('unauthenticated');
    }
    _profileWrites++;
    try {
      final body = await apiFactory(
        session.partition.server,
        session.partition,
      ).accountRequest('v1/me', method: 'PATCH', body: {'locale': locale});
      final user = UserDto.fromJson(body);
      await opened.store.transaction(() async {
        await opened.store.lockRuntime();
        if (!_sameSession(current, session) ||
            (await opened.store.runtime())['generation'] !=
                session.generation) {
          throw const ApiError('stale_response');
        }
        await opened.store.saveIdentity(user.toJson(), 'full');
      });
      if (!_sameSession(current, session)) {
        return const Failure('stale_response');
      }
      current = AuthSession(
        user: user,
        partition: session.partition,
        passwordChangeRequired: session.passwordChangeRequired,
        generation: session.generation,
        adminResetAt: session.adminResetAt,
      );
      return const Ok(null);
    } on ApiError catch (error) {
      return Failure(error.code);
    } on Object {
      return const Failure('invalid_response');
    }
  }

  Future<void> invalidate(
    Partition partition, {
    int? expectedGeneration,
  }) async {
    // A late 401 from A may not log B out. Database generation is checked by
    // the transport callback too, covering A -> B -> A with the same key.
    if (current?.partition.prefix != partition.prefix && current != null) {
      return;
    }
    final expectedSession = current;
    final opened = await databases.open(partition);
    var invalidated = false;
    await opened.store.transaction(() async {
      await opened.store.lockRuntime();
      if (expectedGeneration != null &&
          (await opened.store.runtime())['generation'] != expectedGeneration) {
        return;
      }
      await opened.store.activate(authenticated: false);
      await sessions.delete(partition);
      invalidated = true;
    });
    if (invalidated &&
        (expectedSession == null
            ? current == null
            : _sameSession(current, expectedSession))) {
      clearLocalSession();
    }
  }

  /// Detach an obsolete runtime without changing shared credentials or state.
  void clearLocalSession() {
    _lastCleared = current;
    signOutCode = null;
    current = null;
    handle = null;
    onChanged?.call(null);
  }

  @override
  Future<void> logout() async {
    final session = current;
    if (session == null) {
      return;
    }
    // Revoke local ownership before awaiting a network result.
    final opened = handle;
    if (opened == null) {
      return;
    }
    final logoutGeneration = session.generation;
    String? token;
    var revoked = false;
    await opened.store.transaction(() async {
      await opened.store.lockRuntime();
      if ((await opened.store.runtime())['generation'] != logoutGeneration) {
        return;
      }
      token = await sessions.read(session.partition);
      await opened.store.activate(authenticated: false);
      await sessions.delete(session.partition);
      revoked = true;
    });
    if (revoked && token != null) {
      // Start outside drift's transaction Zone. The response can arrive after
      // commit; it must never query a released transaction executor or use the
      // next login's token. Revocation needs only the captured credential.
      final pendingLogout = apiFactory(
        session.partition.server,
        null,
      ).logout(token: token).catchError((Object _) {});
      _logoutWork = Future.wait<void>([_logoutWork, pendingLogout])
          .then((_) {});
      unawaited(_logoutWork);
    }
    if (!_sameSession(current, session)) {
      return;
    }
    _lastCleared = null;
    signOutCode = null;
    current = null;
    handle = null;
    onChanged?.call(null);
  }
}
