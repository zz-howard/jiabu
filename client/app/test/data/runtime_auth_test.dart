import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/sync_state.dart';

import '../support/memory_stores.dart';
import 'api_contract_test.dart' show CapturingAdapter;
import 'runtime_channel_test.dart' show loadTestDevice;

class SessionRuntimeAdapter extends CapturingAdapter {
  String loginToken = 'fictional-old-token';
  String sessionKind = 'full';
  final logoutStarted = Completer<void>();
  final releaseLogout = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body = switch (options.path) {
      'v1/auth/login' => {
        'token': loginToken,
        'session_kind': sessionKind,
        'user': {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      },
      'v1/me' => {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      'v1/auth/logout' || 'v1/me/password' => <String, Object?>{},
      _ => throw StateError('unexpected_test_route'),
    };
    final response = super.fetch(options, requestStream, cancelFuture);
    if (options.path == 'v1/auth/logout') {
      logoutStarted.complete();
      await releaseLogout.future;
    }
    return await response;
  }
}

void main() {
  for (final name in [
    'stale_runtime_cannot_invalidate_new_login_token',
    'runtime_observing_external_logout_only_clears_local_session',
    'resume_authenticated_before_relogin_cannot_adopt_new_generation',
  ]) {
    final relogin =
        name != 'runtime_observing_external_logout_only_clears_local_session';
    final pauseInitialization =
        name ==
        'resume_authenticated_before_relogin_cannot_adopt_new_generation';
    test(name, () async {
      final directory = await Directory.systemTemp.createTemp('jiabu-auth-');
      final storage = MemorySettings();
      final sessions = MemorySessions();
      final adapter = SessionRuntimeAdapter();
      final workerAdapter = SessionRuntimeAdapter();
      final device = await loadTestDevice('stable');
      final authenticated = Completer<void>();
      final initialize = Completer<void>();
      AppRuntime runtime(
        SessionRuntimeAdapter transport, {
        bool worker = false,
      }) => AppRuntime(
        databases: DatabaseManager(directory),
        settings: AppSettingsService(storage),
        sessions: sessions,
        device: device,
        // Disable platform triggers; foreground auth actions still use the
        // real repository, transport and a separate SQLite connection.
        background: true,
        createDio: () => Dio()..httpClientAdapter = transport,
        beforeSessionInitialization: worker && pauseInitialization
            ? (session) async {
                authenticated.complete();
                await initialize.future;
              }
            : null,
      );
      final foreground = runtime(adapter);
      final worker = runtime(workerAdapter, worker: true);
      expect(identical(foreground.databases, worker.databases), isFalse);
      try {
        final login = await foreground.auth.login(
          'https://example.invalid/',
          'fictional',
          'fictional-password',
        );
        expect(login, isA<Ok<AuthSession>>());
        await foreground.sessionWork;
        final partition = (login as Ok<AuthSession>).value.partition;
        final resumed = await worker.auth.resume();
        expect(resumed, isA<Ok<AuthSession?>>());
        final oldSession = (resumed as Ok<AuthSession?>).value!;
        final oldStore = worker.auth.handle!.store;
        final oldGeneration = oldSession.generation;
        expect((await oldStore.runtime())['generation'], oldGeneration);
        if (pauseInitialization) {
          // Auth has committed, but runtime has not consumed its ownership.
          await authenticated.future;
          expect(worker.engine, isNull);
        } else {
          await worker.sessionWork;
        }

        await foreground.auth.logout();
        await foreground.sessionWork;
        await adapter.logoutStarted.future;
        // Keep the remote logout response in flight across local logout and
        // relogin. No transaction executor may escape into that response.
        if (relogin) {
          adapter
            ..loginToken = 'fictional-new-token'
            ..sessionKind = 'password_change';
          expect(
            await foreground.auth.login(
              partition.server,
              'fictional',
              'fictional-temporary-password',
            ),
            isA<Ok<AuthSession>>(),
          );
          await foreground.sessionWork;
          expect(foreground.auth.current?.passwordChangeRequired, isTrue);
          expect(await sessions.read(partition), 'fictional-new-token');
        }
        final before = await oldStore.runtime();
        expect(before['generation'], isNot(oldGeneration));
        expect(before['authenticated'], 0);

        if (pauseInitialization) {
          initialize.complete();
          await worker.sessionWork;
        }
        final oldEngine = worker.engine!;
        // Both the late-initialized and already initialized engines must use
        // the ownership accepted by resume, even with authenticated=0 now.
        await oldEngine.runRound();
        await worker.sessionWork;
        expect(
          await sessions.read(partition),
          relogin ? 'fictional-new-token' : isNull,
        );
        expect(
          (await oldEngine.store.runtime())['generation'],
          before['generation'],
        );
        expect(
          [
            ...adapter.requests,
            ...workerAdapter.requests,
          ].any((request) => request.path.startsWith('v1/sync/')),
          isFalse,
        );
        expect(worker.engine, isNull);
        expect(worker.auth.current, isNull);
        expect(worker.auth.handle, isNull);
        expect(worker.status, SyncStatus.loginRequired);
        adapter.releaseLogout.complete();
        await foreground.auth.logoutWork;
        final logoutRequest = adapter.requests.singleWhere(
          (request) => request.path == 'v1/auth/logout',
        );
        expect(
          logoutRequest.headers['Authorization'],
          'Bearer fictional-old-token',
        );
        expect(
          await sessions.read(partition),
          relogin ? 'fictional-new-token' : isNull,
        );

        if (relogin) {
          expect(
            await foreground.auth.changePassword(
              'fictional-temporary-password',
              'fictional-new-password',
            ),
            isA<Ok<void>>(),
          );
          await foreground.sessionWork;
          final passwordRequest = adapter.requests.singleWhere(
            (request) => request.path == 'v1/me/password',
          );
          expect(
            passwordRequest.headers['Authorization'],
            'Bearer fictional-new-token',
          );
          expect(foreground.auth.current?.passwordChangeRequired, isFalse);
        }
      } finally {
        if (!initialize.isCompleted) {
          initialize.complete();
        }
        if (!adapter.releaseLogout.isCompleted) {
          adapter.releaseLogout.complete();
        }
        await worker.sessionWork;
        await foreground.sessionWork;
        await foreground.auth.logoutWork;
        await worker.close();
        await foreground.close();
        await directory.delete(recursive: true);
      }
    });
  }
}
