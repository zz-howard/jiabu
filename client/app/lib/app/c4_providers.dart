import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/api_keys.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/features/auth/view_model/auth_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'c4_providers.g.dart';

@riverpod
SpacesRepository spacesRepository(Ref ref) {
  final repository = ref.watch(appRuntimeProvider).spaces;
  if (repository == null) {
    throw StateError('no_partition');
  }
  return repository;
}

@riverpod
ApiKeysRepository apiKeysRepository(Ref ref) {
  final repository = ref.watch(appRuntimeProvider).apiKeys;
  if (repository == null) {
    throw StateError('no_partition');
  }
  return repository;
}

@riverpod
Stream<List<SpaceInfo>> spacesDirectory(Ref ref) =>
    ref.watch(spacesRepositoryProvider).watch();

@riverpod
Stream<int> lockEvents(Ref ref) async* {
  final lock = ref.watch(appRuntimeProvider).lock;
  var revision = 0;
  yield revision;
  await for (final _ in lock.events) {
    yield ++revision;
  }
}

@riverpod
Future<String> deviceTimezone(Ref ref) =>
    ref.watch(appRuntimeProvider).privacy.deviceTimezone();

@riverpod
Future<int?> activeKeyCount(Ref ref) async {
  final runtime = ref.watch(appRuntimeProvider);
  final repository = runtime.apiKeys;
  if (!runtime.network.online || repository == null) {
    return null;
  }
  final result = await repository.list();
  return switch (result) {
    Ok<List<Map<String, Object?>>>(:final value) =>
      value.where((row) => row['status'] == 'active').length,
    Failure<List<Map<String, Object?>>>() => null,
  };
}

@riverpod
bool restrictedAuthenticationReady(Ref ref) =>
    ref.watch(authViewModelProvider).forcedPassword;
