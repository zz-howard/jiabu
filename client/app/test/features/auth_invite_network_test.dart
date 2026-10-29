import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/features/auth/view/auth_shell.dart';

import '../data/runtime_channel_test.dart' show RuntimeAdapter;
import '../support/c3_harness.dart' show pumpDatabaseFrames, pumpUntil;
import '../support/memory_stores.dart';
import 'auth_screens_test.dart' show pumpAuth;

void main() {
  testWidgets('invite_placeholder_sends_no_request_through_the_real_stack', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('jiabu-invite-'),
    ))!;
    final adapter = RuntimeAdapter();
    final memory = MemorySettings()
      ..values['servers'] = jsonEncode(['https://example.invalid/']);
    final runtime = AppRuntime(
      databases: DatabaseManager(directory),
      settings: AppSettingsService(memory),
      sessions: MemorySessions(),
      background: true,
      createDio: () => Dio()..httpClientAdapter = adapter,
      device: const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'test',
        osVersion: 'test',
      ),
    );
    // runtime.close() awaits session work created inside the fake-async test
    // zone, which never resumes after the body; with no signed-in session the
    // databases and the temp directory are the only real resources.
    addTearDown(() async {
      await runtime.databases.close();
      await directory.delete(recursive: true);
    });
    // Real AuthRepository and API client: only the transport is captured.
    await pumpAuth(
      tester,
      ProviderScope(
        overrides: [appRuntimeProvider.overrideWith((ref) => runtime)],
        child: const AuthShell(),
      ),
    );
    await pumpUntil(
      tester,
      () => find.byKey(const Key('invite-signup')).evaluate().isNotEmpty,
      description: 'login page with invite entry',
    );
    await pumpDatabaseFrames(tester);
    final before = adapter.requests.length;

    await tester.ensureVisible(find.byKey(const Key('invite-signup')));
    await tester.tap(find.byKey(const Key('invite-signup')));
    // Bounded pumps, not pumpAndSettle: a regression that starts a request
    // also shows a busy spinner, and must fail on the request check below.
    await pumpDatabaseFrames(tester);

    expect(find.byKey(const Key('invite-signup-placeholder')), findsOneWidget);
    expect(
      adapter.requests.skip(before).map((request) => request.path),
      isEmpty,
      reason: 'the invite placeholder must not reach the network',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
