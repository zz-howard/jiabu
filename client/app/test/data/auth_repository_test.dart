import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

import '../support/memory_stores.dart';
import '../support/sync_harness.dart';

class TransactionTrackingSessions extends MemorySessions {
  Zone? deletionZone;

  @override
  Future<void> delete(Partition partition) async {
    deletionZone = Zone.current;
    await super.delete(partition);
  }
}

class LogoutProbeApi extends AuthApi {
  Zone? logoutZone;
  String? logoutToken;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> logout({String? token}) async {
    logoutZone = Zone.current;
    logoutToken = token;
    started.complete();
    await release.future;
  }
}

class AuthApi extends FakeApi {
  bool restricted = false;
  bool offline = false;
  bool unauthorized = false;
  int passwordCalls = 0;
  int meCalls = 0;

  /// Holds each identity check started while it is set; flags are read after.
  Future<void>? meGate;
  UserDto? meUser;
  @override
  Future<LoginResponseDto> login(LoginRequestDto request) async =>
      LoginResponseDto(
        token: 'fictional-session',
        sessionKind: restricted ? 'password_change' : 'full',
        adminResetAt: DateTime.utc(2026),
        user: const UserDto(id: 'u', username: 'fictional', locale: 'en'),
      );
  @override
  Future<UserDto> me() async {
    meCalls++;
    final gate = meGate;
    if (gate != null) {
      await gate;
    }
    if (offline) {
      throw const ApiError('network');
    }
    if (unauthorized) {
      throw const ApiError('unauthenticated', status: 401);
    }
    if (restricted) {
      throw const ApiError('password_change_required', status: 403);
    }
    return meUser ?? await super.me();
  }

  @override
  Future<void> changePassword(ChangePasswordDto request) async {
    passwordCalls++;
    restricted = false;
  }
}

void main() {
  late Directory directory;
  late DatabaseManager manager;
  late TransactionTrackingSessions sessions;
  late AppSettingsService settings;
  late AuthApi api;
  late LocalAuthRepository auth;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jiabu-auth-');
    manager = DatabaseManager(directory);
    sessions = TransactionTrackingSessions();
    settings = AppSettingsService(MemorySettings());
    api = AuthApi();
    auth = LocalAuthRepository(
      databases: manager,
      settings: settings,
      sessions: sessions,
      apiFactory: (server, partition) => api,
    );
  });
  tearDown(() async {
    await manager.close();
    await directory.delete(recursive: true);
  });

  test('temporary_password_disables_sync_until_password_change', () async {
    api.restricted = true;
    final result = await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    final session = (result as Ok<AuthSession>).value;
    expect(session.passwordChangeRequired, isTrue);
    expect(session.adminResetAt, isNotNull);
    expect((await auth.handle?.store.runtime())?['authenticated'], 0);
    expect(
      await auth.changePassword('fictional-old', 'fictional-new'),
      isA<Ok<void>>(),
    );
    expect(auth.current?.passwordChangeRequired, isFalse);
    expect((await auth.handle?.store.runtime())?['authenticated'], 1);
    expect(await sessions.read(session.partition), 'fictional-session');
  });

  test('logout_retains_database_and_next_login_reopens_it', () async {
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    final old = auth.handle!;
    await old.store.putEntity('s', 'record', sampleRecord('r'));
    await auth.logout();
    expect(await sessions.read(old.partition), isNull);
    expect(await old.store.entity('s', 'record', 'r'), isNotNull);
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    expect(await auth.handle?.store.entity('s', 'record', 'r'), isNotNull);
  });

  test('offline_cold_start_uses_partition_identity_witho'
      'ut_losing_data', () async {
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    await auth.handle?.store.putEntity('s', 'record', sampleRecord('r'));
    api.offline = true;
    final resumed = LocalAuthRepository(
      databases: manager,
      settings: settings,
      sessions: sessions,
      apiFactory: (server, partition) => api,
    );
    expect(await resumed.resume(), isA<Ok<AuthSession?>>());
    expect(resumed.current?.user.username, 'fictional');
    expect(await resumed.handle?.store.entity('s', 'record', 'r'), isNotNull);
    await resumed.verificationWork;
    expect(resumed.current, isNotNull);
    expect((await resumed.handle?.store.runtime())?['authenticated'], 1);
  });

  test('401_clears_token_stops_sync_and_keeps_partition', () async {
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    final old = auth.handle!;
    await old.store.putEntity('s', 'record', sampleRecord('r'));
    api.unauthorized = true;
    // Local-first resume opens the persisted session; the background identity
    // check then takes the authentication-lost path.
    expect(await auth.resume(), isA<Ok<AuthSession?>>());
    await auth.verificationWork;
    expect(auth.current, isNull);
    expect(await sessions.read(old.partition), isNull);
    expect((await old.store.runtime())['authenticated'], 0);
    expect(await old.store.entity('s', 'record', 'r'), isNotNull);
  });

  LocalAuthRepository coldStart(List<AuthSession?> changes) =>
      LocalAuthRepository(
        databases: manager,
        settings: settings,
        sessions: sessions,
        apiFactory: (server, partition) => api,
        onChanged: changes.add,
      );

  Future<AuthSession> signIn() async => (await auth.login(
    'https://example.invalid/',
    'fictional',
    'fictional-test-password',
  ) as Ok<AuthSession>).value;

  test('cold_start_opens_local_data_while_identity_check_is_pending', () async {
    final first = await signIn();
    await auth.handle?.store.putEntity('s', 'record', sampleRecord('r'));
    // The online check never answers.
    api.meGate = Completer<void>().future;
    final calls = api.meCalls;
    final changes = <AuthSession?>[];
    final resumed = coldStart(changes);
    final result = await resumed.resume().timeout(const Duration(seconds: 5));
    final session = (result as Ok<AuthSession?>).value!;
    expect(session.user.username, 'fictional');
    expect(session.partition.prefix, first.partition.prefix);
    expect(session.passwordChangeRequired, isFalse);
    expect(changes, [session]);
    expect(api.meCalls, calls + 1);
    final store = resumed.handle!.store;
    expect((await store.runtime())['generation'], session.generation);
    expect((await store.runtime())['authenticated'], 1);
    expect(await store.entity('s', 'record', 'r'), isNotNull);
  });

  for (final state in ['identity_missing', 'login_unconfirmed']) {
    test('${state}_resume_still_waits_for_identity_check', () async {
      await signIn();
      final store = auth.handle!.store;
      if (state == 'identity_missing') {
        await store.db.customStatement(
          'UPDATE sync_runtime SET identity_json = NULL WHERE id = 1',
        );
      } else {
        // Token saved, but the login's own /me confirmation never committed.
        await store.activate(authenticated: false);
      }
      final gate = Completer<void>();
      api.meGate = gate.future;
      final changes = <AuthSession?>[];
      final resumed = coldStart(changes);
      var finished = false;
      final pending = resumed.resume().whenComplete(() => finished = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(finished, isFalse);
      expect(changes, isEmpty);
      gate.complete();
      final session = ((await pending) as Ok<AuthSession?>).value!;
      expect(changes, [session]);
      expect((await store.runtime())['authenticated'], 1);
    });
  }

  test('background_identity_check_refreshes_identity_in_place', () async {
    await signIn();
    api.meUser = const UserDto(
      id: 'u',
      username: 'fictional-renamed',
      locale: 'zh',
    );
    final changes = <AuthSession?>[];
    final resumed = coldStart(changes);
    final session = ((await resumed.resume()) as Ok<AuthSession?>).value!;
    await resumed.verificationWork;
    // Same ownership: no runtime teardown, only the profile is refreshed.
    expect(changes, [session]);
    expect(resumed.current?.user.username, 'fictional-renamed');
    expect(resumed.current?.generation, session.generation);
    final row = await resumed.handle!.store.runtime();
    expect(row['identity_json'], contains('fictional-renamed'));
    expect(row['session_kind'], 'full');
    expect(row['generation'], session.generation);
  });

  test('background_user_mismatch_signs_out', () async {
    final first = await signIn();
    api.meUser = const UserDto(id: 'other', username: 'other', locale: 'en');
    final changes = <AuthSession?>[];
    final resumed = coldStart(changes);
    final session = ((await resumed.resume()) as Ok<AuthSession?>).value!;
    await resumed.verificationWork;
    expect(changes, [session, null]);
    expect(resumed.current, isNull);
    expect(await sessions.read(first.partition), isNull);
    final store = (await manager.open(first.partition)).store;
    expect((await store.runtime())['authenticated'], 0);
  });

  test('background_password_change_required_restricts_session', () async {
    await signIn();
    api.restricted = true;
    final changes = <AuthSession?>[];
    final resumed = coldStart(changes);
    final session = ((await resumed.resume()) as Ok<AuthSession?>).value!;
    expect(session.passwordChangeRequired, isFalse);
    await resumed.verificationWork;
    expect(changes, hasLength(2));
    expect(resumed.current?.passwordChangeRequired, isTrue);
    expect((await resumed.handle!.store.runtime())['authenticated'], 0);
    expect(await sessions.read(session.partition), 'fictional-session');
  });

  test('late_identity_result_cannot_touch_a_newer_session', () async {
    await signIn();
    final gate = Completer<void>();
    api.meGate = gate.future;
    final changes = <AuthSession?>[];
    final resumed = coldStart(changes);
    final old = ((await resumed.resume()) as Ok<AuthSession?>).value!;
    api.meGate = null;
    final login = await resumed.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    final newer = (login as Ok<AuthSession>).value;
    expect(newer.generation, isNot(old.generation));
    // The old check now answers 401, after the newer session took over.
    api.unauthorized = true;
    gate.complete();
    await resumed.verificationWork;
    expect(identical(resumed.current, newer), isTrue);
    expect(await sessions.read(newer.partition), 'fictional-session');
    final row = await resumed.handle!.store.runtime();
    expect(row['authenticated'], 1);
    expect(row['generation'], newer.generation);
    expect(changes.last, same(newer));
  });

  test('stale_401_generation_cannot_delete_a_new_session', () async {
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    final first = auth.handle!;
    final oldGeneration = requireValue<int>(
      (await first.store.runtime())['generation'],
    );
    await auth.login(
      'https://example.invalid/',
      'fictional',
      'fictional-test-password',
    );
    await auth.invalidate(first.partition, expectedGeneration: oldGeneration);
    expect(auth.current, isNotNull);
    expect(await sessions.read(first.partition), isNotNull);
    expect((await first.store.runtime())['authenticated'], 1);
  });

  test('logout_dispatches_outside_transaction_with_captured_token', () async {
    final probe = LogoutProbeApi();
    api = probe;
    final callerZone = Zone.current;
    try {
      final login = await auth.login(
        'https://example.invalid/',
        'fictional',
        'fictional-test-password',
      );
      final session = (login as Ok<AuthSession>).value;
      final store = auth.handle!.store;
      expect(session.generation, (await store.runtime())['generation']);
      await auth.logout();
      await probe.started.future;
      // Zone identity is deterministic: the old implementation starts logout
      // in the same drift transaction Zone that deletes the credential.
      expect(sessions.deletionZone, isNotNull);
      expect(identical(sessions.deletionZone, callerZone), isFalse);
      expect(identical(probe.logoutZone, sessions.deletionZone), isFalse);
      expect(identical(probe.logoutZone, callerZone), isTrue);
      expect(probe.logoutToken, 'fictional-session');
      expect(await sessions.read(session.partition), isNull);
      expect((await store.runtime())['authenticated'], 0);
      expect(auth.current, isNull);
      // The response stays pending while another operation uses the database.
      await store.setWriteAllowed(allowed: false);
    } finally {
      probe.release.complete();
      await auth.logoutWork;
    }
  });
}
