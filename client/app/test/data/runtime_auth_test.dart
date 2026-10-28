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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
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
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  for (final relogin in [true, false]) {
    test(
      relogin
          ? 'stale_runtime_cannot_invalidate_new_login_token'
          : 'runtime_observing_external_logout_only_clears_local_session',
      () async {
        final directory = await Directory.systemTemp.createTemp('jiabu-auth-');
        final storage = MemorySettings();
        final sessions = MemorySessions();
        final adapter = SessionRuntimeAdapter();
        final device = await loadTestDevice('stable');
        AppRuntime runtime() => AppRuntime(
          databases: DatabaseManager(directory),
          settings: AppSettingsService(storage),
          sessions: sessions,
          device: device,
          // Disable platform triggers; foreground auth actions still use the
          // real repository, transport and a separate SQLite connection.
          background: true,
          createDio: () => Dio()..httpClientAdapter = adapter,
        );
        final foreground = runtime();
        final worker = runtime();
        try {
          final login = await foreground.auth.login(
            'https://example.invalid/',
            'fictional',
            'fictional-password',
          );
          expect(login, isA<Ok<AuthSession>>());
          await foreground.sessionWork;
          final partition = (login as Ok<AuthSession>).value.partition;
          expect(await worker.auth.resume(), isA<Ok<AuthSession?>>());
          await worker.sessionWork;
          final oldEngine = worker.engine!;
          final oldGeneration = (await oldEngine.store.runtime())['generation'];

          await foreground.auth.logout();
          await foreground.sessionWork;
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
          final before = await oldEngine.store.runtime();
          expect(before['generation'], isNot(oldGeneration));
          expect(before['authenticated'], 0);

          // The old engine starts only after the other runtime has logged out
          // and (optionally) persisted its new restricted login.
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
            adapter.requests.any(
              (request) => request.path.startsWith('v1/sync/'),
            ),
            isFalse,
          );
          expect(worker.engine, isNull);
          expect(worker.auth.current, isNull);
          expect(worker.auth.handle, isNull);
          expect(worker.status, SyncStatus.loginRequired);

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
          await worker.close();
          await foreground.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
