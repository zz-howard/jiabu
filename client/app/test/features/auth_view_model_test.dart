import 'dart:io';

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

import '../support/memory_stores.dart';

class FakeAuth implements AuthRepository {
  bool forced = true;
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
    ),
  );
  @override
  Future<Result<AuthSession?>> resume() async => const Ok(null);
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

void main() {
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
