import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/view_model/auth_view_model.dart';

import '../data/runtime_channel_test.dart' show RuntimeAdapter;
import '../support/memory_stores.dart';

class FakeAuth implements AuthRepository {
  bool forced = true;
  AuthSession? resumed;
  int count = 3;
  int logoutCalls = 0;
  @override
  Future<Result<AuthSession>> login(
    String server,
    String username,
    String password,
  ) async => Ok(
    AuthSession(
      user: const UserDto(id: 'u', username: 'fictional', locale: 'en'),
      partition: Partition('https://example.invalid/', 'u'),
      passwordChangeRequired: forced,
      generation: 1,
    ),
  );
  @override
  Future<Result<AuthSession?>> resume() async => Ok(resumed);
  @override
  Future<Result<void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    forced = false;
    return const Ok(null);
  }

  @override
  Future<int> pendingCount() async => count;
  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

Future<({ProviderContainer container, AppRuntime runtime, Directory dir})>
_fixture({List<String> servers = const [], AuthSession? session}) async {
  final directory = await Directory.systemTemp.createTemp('jiabu-start-');
  final memory = MemorySettings();
  if (servers.isNotEmpty) {
    memory.values['servers'] = jsonEncode(servers);
  }
  final runtime = AppRuntime(
    databases: DatabaseManager(directory),
    settings: AppSettingsService(memory),
    sessions: MemorySessions(),
    background: true,
    device: const DeviceContext(
      appVersion: '0.1.0',
      build: 1,
      model: 'test',
      osVersion: 'test',
    ),
  );
  final fake = FakeAuth()..resumed = session;
  final container = ProviderContainer(
    overrides: [
      appRuntimeProvider.overrideWith((ref) => runtime),
      authRepositoryProvider.overrideWith((ref) => fake),
    ],
  );
  return (container: container, runtime: runtime, dir: directory);
}

Future<void> _dispose(
  ({ProviderContainer container, AppRuntime runtime, Directory dir}) fixture,
) async {
  fixture.container.dispose();
  await fixture.runtime.close();
  await fixture.dir.delete(recursive: true);
}

void main() {
  test('first_launch_without_server_shows_welcome', () async {
    final first = await _fixture();
    await first.container
        .read(authViewModelProvider.notifier)
        .initialize(defaultServer: 'https://default.example.invalid/');
    expect(first.container.read(authViewModelProvider).page, AuthPage.welcome);
    expect(
      first.container.read(authViewModelProvider).defaultServer,
      'https://default.example.invalid/',
    );
    await _dispose(first);
  });

  test('configured_server_without_session_shows_login', () async {
    final configured = await _fixture(
      servers: ['https://saved.example.invalid/'],
    );
    await configured.container
        .read(authViewModelProvider.notifier)
        .initialize();
    final configuredState = configured.container.read(authViewModelProvider);
    expect(configuredState.page, AuthPage.login);
    expect(configuredState.defaultServer, isEmpty);
    await _dispose(configured);
  });

  test('resumed_session_skips_welcome_and_login', () async {
    final resumed = await _fixture(
      session: AuthSession(
        user: const UserDto(id: 'u', username: 'fictional', locale: 'en'),
        partition: Partition('https://saved.example.invalid/', 'u'),
        passwordChangeRequired: false,
        generation: 1,
      ),
    );
    await resumed.container.read(authViewModelProvider.notifier).initialize();
    expect(
      resumed.container.read(authViewModelProvider).page,
      AuthPage.session,
    );
    await _dispose(resumed);
  });

  test('direct_login_without_default_opens_server_page', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-direct-');
    final runtime = AppRuntime(
      databases: DatabaseManager(directory),
      settings: AppSettingsService(MemorySettings()),
      sessions: MemorySessions(),
      background: true,
      device: const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'test',
        osVersion: 'test',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appRuntimeProvider.overrideWith((ref) => runtime),
        authRepositoryProvider.overrideWith((ref) => FakeAuth()),
      ],
    );
    await container.read(authViewModelProvider.notifier).initialize();
    await container.read(authViewModelProvider.notifier).useDefaultServer();
    expect(container.read(authViewModelProvider).page, AuthPage.server);
    container.dispose();
    await runtime.close();
    await directory.delete(recursive: true);
  });

  test('direct_login_with_default_probes_meta_then_opens_login', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-default-');
    final adapter = RuntimeAdapter();
    Dio createDio() => Dio()..httpClientAdapter = adapter;
    final runtime = AppRuntime(
      databases: DatabaseManager(directory),
      settings: AppSettingsService(MemorySettings()),
      sessions: MemorySessions(),
      background: true,
      createDio: createDio,
      device: const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'test',
        osVersion: 'test',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appRuntimeProvider.overrideWith((ref) => runtime),
        authRepositoryProvider.overrideWith((ref) => FakeAuth()),
      ],
    );
    await container
        .read(authViewModelProvider.notifier)
        .initialize(defaultServer: 'https://default.example.invalid/');
    await container.read(authViewModelProvider.notifier).useDefaultServer();
    final state = container.read(authViewModelProvider);
    expect(state.page, AuthPage.login);
    expect(state.serverProbeSucceeded, isTrue);
    expect(
      adapter.requests.where((request) => request.path == 'v1/meta'),
      hasLength(1),
    );
    container.dispose();
    await runtime.close();
    await directory.delete(recursive: true);
  });

  test('view_model_forces_password_and_prompts_before_sw'
      'itch_with_pending_count', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-vm-');
    final runtime = AppRuntime(
      databases: DatabaseManager(directory),
      settings: AppSettingsService(MemorySettings()),
      sessions: MemorySessions(),
      background: true,
      device: const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'test',
        osVersion: 'test',
      ),
    );
    final fake = FakeAuth();
    final container = ProviderContainer(
      overrides: [
        appRuntimeProvider.overrideWith((ref) => runtime),
        authRepositoryProvider.overrideWith((ref) => fake),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await runtime.close();
      await directory.delete(recursive: true);
    });
    final model = container.read(authViewModelProvider.notifier);
    await model.login('fictional', 'fictional-test-password');
    expect(container.read(authViewModelProvider).page, AuthPage.password);
    expect(container.read(authViewModelProvider).forcedPassword, isTrue);
    await model.changePassword('old', 'short', 'different');
    expect(
      container.read(authViewModelProvider).errorCode,
      'invalid_new_password',
    );
    await model.changePassword(
      'old',
      'fictional-new-password',
      'fictional-new-password',
    );
    expect(container.read(authViewModelProvider).page, AuthPage.session);
    await model.requestSwitch();
    expect(container.read(authViewModelProvider).switchCount, 3);
    expect(fake.logoutCalls, 0);
    model.cancelSwitch();
    expect(fake.logoutCalls, 0);
    await model.requestSwitch();
    await model.confirmSwitch();
    expect(fake.logoutCalls, 1);
    expect(container.read(authViewModelProvider).page, AuthPage.server);
  });
}
