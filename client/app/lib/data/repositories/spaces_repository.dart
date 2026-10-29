import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';

final class LocalSpacesRepository implements SpacesRepository {
  LocalSpacesRepository({
    required this.api,
    required this.store,
    required this.online,
    required this.refresh,
    required this.selectSpace,
    required this.valid,
  });
  final ApiClient api;
  final LocalStore store;
  final bool Function() online;
  final bool Function() valid;
  final Future<void> Function() refresh;
  final Future<void> Function(String) selectSpace;

  @override
  Stream<List<SpaceInfo>> watch() async* {
    await for (final _ in store.watchSpaceDirectory()) {
      final spaces = <SpaceInfo>[];
      for (final id in await store.spaceIds()) {
        final row = await store.entity(id, 'space', id);
        if (row != null) {
          spaces.add(SpaceInfo.fromJson(row.data));
        }
      }
      if (valid()) {
        yield List.unmodifiable(spaces);
      }
    }
  }

  @override
  Future<int> pendingCount(String spaceId) async =>
      (await store.outbox(spaceId)).length;

  @override
  Future<Result<void>> select(String spaceId) async {
    if (!valid() || !(await store.spaceIds()).contains(spaceId)) {
      return const Failure('not_found');
    }
    await selectSpace(spaceId);
    return const Ok(null);
  }

  Future<Result<void>> _write(
    String path,
    String operationId, {
    String method = 'POST',
    Map<String, Object?>? body,
    int? joinEpoch,
  }) async {
    if (!online()) {
      return const Failure('offline');
    }
    try {
      if (!valid()) {
        return const Failure('stale_response');
      }
      await api.accountRequest(
        path,
        method: method,
        body: body,
        operationId: operationId,
        joinEpoch: joinEpoch,
      );
      if (!valid()) {
        return const Failure('stale_response');
      }
      await refresh();
      return const Ok(null);
    } on ApiError catch (error) {
      return Failure(error.code, requestId: error.requestId);
    } on Object {
      return const Failure('invalid_response');
    }
  }

  @override
  Future<Result<void>> create(Map<String, Object?> input, String operationId) =>
      _write('v1/spaces', operationId, body: input);

  @override
  Future<Result<void>> change(
    SpaceInfo space,
    String action,
    String operationId, {
    Map<String, Object?>? body,
    String? target,
  }) async {
    final local = await store.entity(space.id, 'space', space.id);
    if (local == null || local.data['join_epoch'] != space.joinEpoch) {
      return const Failure('membership_changed');
    }
    final (method, suffix) = switch (action) {
      'edit' => ('PATCH', ''),
      'delete' => ('DELETE', ''),
      'invite' => ('POST', '/invitations'),
      'cancel' => ('POST', '/invitations/$target/cancel'),
      'remove' => ('DELETE', '/members/$target'),
      'display_name' => ('PATCH', '/members/me'),
      'transfer' => ('POST', '/transfer-ownership'),
      'leave' => ('POST', '/leave'),
      _ => throw ArgumentError('invalid_space_action'),
    };
    return await _write(
      'v1/spaces/${space.id}$suffix',
      operationId,
      method: method,
      body: body,
      joinEpoch: space.joinEpoch,
    );
  }

  @override
  Future<Result<List<Map<String, Object?>>>> invitations(
    String? spaceId,
  ) async {
    if (!online()) {
      return const Failure('offline');
    }
    try {
      final body = await api.accountRequest(
        spaceId == null
            ? 'v1/me/invitations'
            : 'v1/spaces/$spaceId/invitations',
      );
      if (!valid()) {
        return const Failure('stale_response');
      }
      return Ok(
        requireValue<List<Object?>>(body['invitations'])
            .cast<Map<String, Object?>>(),
      );
    } on ApiError catch (error) {
      return Failure(error.code);
    } on Object {
      return const Failure('invalid_response');
    }
  }

  @override
  Future<Result<void>> decide(
    String id,
    String operationId, {
    required bool accept,
  }) => _write(
    'v1/me/invitations/$id/${accept ? 'accept' : 'decline'}',
    operationId,
  );
}
