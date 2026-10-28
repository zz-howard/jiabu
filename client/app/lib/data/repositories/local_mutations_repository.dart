import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/sync/tool_dependencies.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';
import 'package:uuid/uuid.dart';

final class LocalMutationsRepository {
  LocalMutationsRepository(
    this.store, {
    DateTime Function()? now,
    String Function()? newId,
    this.onEnqueued,
    this.canWrite,
  }) : now = now ?? DateTime.now,
       newId = newId ?? const Uuid().v7;
  final LocalStore store;
  final DateTime Function() now;
  final String Function() newId;
  final void Function()? onEnqueued;
  final bool Function()? canWrite;

  Future<Result<String>> enqueueTool({
    required String spaceId,
    required String tool,
    required Map<String, Object?> args,
    required String entityKind,
    required String entityId,
    required Map<String, Object?> optimistic,
    Set<String> dependsOn = const {},
  }) async {
    if (canWrite?.call() == false) {
      return const Failure('client_too_old');
    }
    final result = await store.transaction<Result<String>>(() async {
      final fence = await store.fence(spaceId);
      if (fence == null) {
        return const Failure('unauthenticated');
      }
      if ((await store.runtime())['write_allowed'] != 1) {
        return const Failure('client_too_old');
      }
      final module = const {'document', 'subject'}.contains(entityKind)
          ? 'documents'
          : 'ledger';
      final space = await store.entity(spaceId, 'space', spaceId);
      final levels = space?.data['modules'] as Map<String, Object?>?;
      if (!const {'write', 'manage'}.contains(levels?[module])) {
        return const Failure('not_found');
      }
      final existing = await store.entity(spaceId, entityKind, entityId);
      if (existing?.syncState == 'conflict') {
        return const Failure('resolve_conflict_first');
      }
      final id = newId();
      final cleanArgs = {...args}..remove('expected_version');
      await store.putEntity(
        spaceId,
        entityKind,
        optimistic,
        state: 'pending',
        baseVersion: existing?.baseVersion ?? 0,
      );
      await store.enqueue(
        OutboxOperation(
          id: id,
          spaceId: spaceId,
          joinEpoch: fence.joinEpoch,
          kind: 'tool',
          payload: {'tool': tool, 'args': cleanArgs},
          entityIds: {EntityRef(entityKind, entityId).key},
          dependsOn: {
            ...dependsOn,
            ...toolDependencies(
              tool,
              cleanArgs,
              previous: existing?.data ?? const {},
            ),
          },
          requestId: newId(),
          createdAt: now().microsecondsSinceEpoch,
        ),
      );
      return Ok(id);
    });
    if (result is Ok<String>) {
      onEnqueued?.call();
    }
    return result;
  }

  Future<Result<void>> retryFailed(String spaceId, String opId) async {
    await store.transaction(() async {
      for (final op in await store.outbox(spaceId)) {
        if (op.id == opId && op.state == 'failed') {
          await store.setOutboxState(spaceId, opId, 'pending');
        }
      }
    });
    onEnqueued?.call();
    return const Ok(null);
  }
}
