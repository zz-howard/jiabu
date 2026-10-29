import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:logging/logging.dart';

final class LeasedOperation {
  const LeasedOperation(this.op, this.fence, this.wire, this.leaseUntil);
  final OutboxOperation op;
  final RequestFence fence;
  final PushOpDto? wire;
  final int leaseUntil;
}

final class OutboxProcessor {
  OutboxProcessor(
    this.store,
    this.api,
    this.conflicts, {
    this.chatApi,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final LocalStore store;
  final ApiClient api;
  final ChatApi? chatApi;
  final ConflictService conflicts;
  final DateTime Function() now;

  Future<List<LeasedOperation>> selectAndLeaseBatch(String owner) =>
      store.transaction(() async {
        final instant = now().millisecondsSinceEpoch;
        if (!await store.ownsRound(owner, instant)) {
          return <LeasedOperation>[];
        }
        if ((await store.runtime())['write_allowed'] != 1) {
          return <LeasedOperation>[];
        }
        final all = <OutboxOperation>[];
        for (final spaceId in await store.spaceIds()) {
          all.addAll(await store.outbox(spaceId));
        }
        all.sort((a, b) {
          final order = a.createdAt.compareTo(b.createdAt);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
        final batch = <LeasedOperation>[];
        for (var index = 0; index < all.length; index++) {
          final op = all[index];
          if (!const {
                'tool',
                'blob',
                'chat_send',
                'chat_action',
                'chat_retry',
              }.contains(op.kind) ||
              (op.kind.startsWith('chat_') && chatApi == null)) {
            continue;
          }
          if (op.state != 'pending' &&
              !(op.state == 'sending' && (op.leaseUntil ?? 0) <= instant)) {
            continue;
          }
          if (op.retryAt > instant) {
            continue;
          }
          final fence = await store.fence(op.spaceId);
          if (fence == null || fence.joinEpoch != op.joinEpoch) {
            continue;
          }
          final overlapsEarlier = all
              .take(index)
              .any(
                (earlier) =>
                    earlier.spaceId == op.spaceId &&
                    earlier.references.intersection(op.references).isNotEmpty,
              );
          if (overlapsEarlier) {
            continue;
          }
          var blocked = false;
          for (final reference in op.dependsOn) {
            if (reference.startsWith('blob:')) {
              final parts = reference.split(':');
              final matches = (await store.blobs(op.spaceId)).where(
                (blob) =>
                    blob['module'] == parts[1] && blob['sha256'] == parts[2],
              );
              if (matches.isEmpty ||
                  matches.any((blob) => blob['uploaded'] != 1)) {
                blocked = true;
              }
            } else {
              final colon = reference.indexOf(':');
              if (colon > 0 &&
                  await store.conflict(
                        op.spaceId,
                        reference.substring(0, colon),
                        reference.substring(colon + 1),
                      ) !=
                      null) {
                blocked = true;
              }
            }
          }
          if (blocked) {
            continue;
          }
          if (op.kind != 'tool' && batch.isNotEmpty) {
            break;
          }
          final leaseUntil = instant + SyncPolicy.lease.inMilliseconds;
          var payload = op.payload;
          PushOpDto? wire;
          if (op.kind == 'tool') {
            final args = Map<String, Object?>.from(
              requireValue<Map<String, Object?>>(payload['args']),
            );
            final tool = requireValue<String>(payload['tool']);
            if (!args.containsKey('expected_version') &&
                !tool.startsWith('create_')) {
              final ref = op.entityIds.single;
              final colon = ref.indexOf(':');
              final row = await store.entity(
                op.spaceId,
                ref.substring(0, colon),
                ref.substring(colon + 1),
              );
              if (row == null) {
                await store.setOutboxState(
                  op.spaceId,
                  op.id,
                  'failed',
                  error: {'code': 'local_entity_missing'},
                );
                continue;
              }
              if (tool != 'set_allocation_plan' || (row.baseVersion ?? 0) > 0) {
                args['expected_version'] = row.baseVersion;
              }
            }
            payload = {'tool': tool, 'args': args};
            wire = PushOpDto(
              opId: op.id,
              spaceId: op.spaceId,
              joinEpoch: op.joinEpoch,
              requestId: op.requestId,
              tool: tool,
              args: args,
            );
            final wires = [
              ...batch.map((b) => b.wire).whereType<PushOpDto>(),
              wire,
            ];
            final bytes = utf8
                .encode(jsonEncode(PushRequestDto(ops: wires).toJson()))
                .length;
            if (bytes > SyncPolicy.maxBatchBytes) {
              if (batch.isEmpty) {
                await store.setOutboxState(
                  op.spaceId,
                  op.id,
                  'failed',
                  error: {'code': 'payload_too_large'},
                );
                continue;
              }
              break;
            }
          }
          await store.lease(op, payload, leaseUntil);
          batch.add(LeasedOperation(op, fence, wire, leaseUntil));
          if (op.kind != 'tool' || batch.length == SyncPolicy.maxBatchItems) {
            break;
          }
        }
        return batch;
      });

  Future<bool> _accepts(String owner, LeasedOperation sent) async {
    if (!await store.ownsRound(owner, now().millisecondsSinceEpoch)) {
      return false;
    }
    if (!await store.accepts(sent.fence)) {
      return false;
    }
    final current = (await store.outbox(sent.op.spaceId))
        .where((op) => op.id == sent.op.id);
    return current.isNotEmpty &&
        current.single.state == 'sending' &&
        current.single.leaseUntil == sent.leaseUntil &&
        current.single.attempts == sent.op.attempts + 1;
  }

  Future<void> drain(String owner, {Future<void> Function()? reconcile}) async {
    while (true) {
      final batch = await selectAndLeaseBatch(owner);
      if (batch.isEmpty) {
        return;
      }
      try {
        // A lease does not authorize dispatch after a membership change.
        final valid = await store.transaction(() async {
          for (final sent in batch) {
            if (!await _accepts(owner, sent)) return false;
          }
          return true;
        });
        if (!valid) return;
        if (batch.first.op.kind.startsWith('chat_')) {
          await uploadLeasedChat(owner, batch.single);
        } else if (batch.first.op.kind == 'blob') {
          final sent = batch.single;
          final payload = sent.op.payload;
          final path = requireValue<String>(payload['path']);
          final file = File(path);
          final Uint8List bytes;
          try {
            bytes = await file.readAsBytes();
          } on FileSystemException {
            // Keep the operation retryable without waiting for its sending
            // lease. Do not persist the exception or the private cache path.
            throw const ApiError('local_blob_unreadable');
          }
          await api.uploadBlob(
            spaceId: sent.op.spaceId,
            joinEpoch: sent.fence.joinEpoch,
            module: requireValue<String>(payload['module']),
            hash: requireValue<String>(payload['sha256']),
            bytes: bytes,
            opId: sent.op.id,
            requestId: sent.op.requestId,
          );
          await store.transaction(() async {
            if (!await _accepts(owner, sent)) {
              return;
            }
            await store.uploadedBlob(
              sent.op.spaceId,
              requireValue<String>(payload['module']),
              requireValue<String>(payload['sha256']),
              now().millisecondsSinceEpoch,
            );
            await store.removeOp(sent.op.spaceId, sent.op.id);
          });
        } else {
          final response = await api.push(
            batch.map((sent) => sent.wire).whereType<PushOpDto>().toList(),
          );
          final stop = await applyPushBatch(owner, batch, response);
          for (final result in response.results) {
            if (const {401, 426}.contains(result.problem?.status)) {
              throw ApiError(
                result.problem?.code ?? 'unauthenticated',
                status: result.problem?.status,
                requestId: result.problem?.requestId,
              );
            }
          }
          if (response.results.any(
            (result) =>
                result.status == 'space_unavailable' ||
                result.status == 'membership_changed',
          )) {
            await reconcile?.call();
          }
          if (stop) return;
        }
      } on ApiError catch (error) {
        if (batch.any((sent) => sent.op.kind.startsWith('chat_'))) {
          Logger('chat').warning(
            SafeLogEvent(
              'chat_failed',
              code: error.code,
              requestId: error.requestId,
            ),
          );
        }
        await store.transaction(() async {
          for (final sent in batch) {
            if (!await _accepts(owner, sent)) {
              continue;
            }
            final status = error.status;
            if (sent.op.kind == 'chat_action' &&
                const {
                  'interrupt_resolved',
                  'interrupt_expired',
                }.contains(error.code)) {
              final context =
                  sent.op.payload['context']! as Map<String, Object?>;
              await store.updateChatClientState(
                sent.op.spaceId,
                context['messageId']! as String,
                (state) => {
                  ...state,
                  'action_refresh': true,
                  'receipts': {
                    ...?(state['receipts'] as Map<String, Object?>?),
                    sent.op.id: {
                      'protocolVersion': '0.1',
                      'actionId': sent.op.id,
                      'status': 'rejected',
                      'error': {'code': error.code},
                    },
                  },
                },
              );
              await store.removeOp(sent.op.spaceId, sent.op.id);
              continue;
            }
            final permanent =
                status != null &&
                    status >= 400 &&
                    status < 500 &&
                    !const {401, 404, 409, 426, 429}.contains(status) ||
                (sent.op.kind.startsWith('chat_') &&
                    const {
                      'retry_unavailable',
                      'idempotency_conflict',
                      'idempotency_key_mismatch',
                      'runtime_conflict',
                    }.contains(error.code));
            if (permanent && sent.op.kind == 'chat_action') {
              final context =
                  sent.op.payload['context']! as Map<String, Object?>;
              await store.updateChatClientState(
                sent.op.spaceId,
                context['messageId']! as String,
                (state) => {
                  ...state,
                  'receipts': {
                    ...?(state['receipts'] as Map<String, Object?>?),
                    sent.op.id: {
                      'protocolVersion': '0.1',
                      'actionId': sent.op.id,
                      'status': 'rejected',
                      'error': {'code': error.code},
                    },
                  },
                },
              );
            }
            await store.setOutboxState(
              sent.op.spaceId,
              sent.op.id,
              permanent ? 'failed' : 'pending',
              error: {
                'code': error.code,
                'status': error.status,
                'retry_at':
                    now().millisecondsSinceEpoch +
                    SyncPolicy.retry(
                      sent.op.attempts,
                      retryAfter: error.retryAfter,
                    ).inMilliseconds,
              },
            );
          }
        });
        if (error.code == 'membership_changed' || error.status == 404) {
          await reconcile?.call();
        }
        if (const {401, 426}.contains(error.status)) {
          rethrow;
        }
        return;
      }
    }
  }

  Future<void> uploadLeasedChat(String owner, LeasedOperation sent) async {
    if (!await _accepts(owner, sent)) return;
    final api = chatApi;
    if (api == null) throw const ApiError('chat_transport_missing');
    final op = sent.op;
    final endpoint = switch (op.kind) {
      'chat_send' => 'messages',
      'chat_action' => 'actions',
      'chat_retry' => 'messages/${op.payload['messageId']}/retry',
      _ => throw const ApiError('invalid_chat_kind'),
    };
    final response = await api.chatWrite(
      spaceId: op.spaceId,
      endpoint: endpoint,
      payload: op.kind == 'chat_retry' ? const {} : op.payload,
      joinEpoch: sent.fence.joinEpoch,
      opId: op.id,
      requestId: op.requestId,
    );
    await store.transaction(() async {
      if (!await _accepts(owner, sent)) return;
      if (op.kind == 'chat_action') {
        final context = op.payload['context']! as Map<String, Object?>;
        await store.updateChatClientState(
          op.spaceId,
          context['messageId']! as String,
          (state) => {
            ...state,
            'receipts': {
              ...?(state['receipts'] as Map<String, Object?>?),
              op.id: response,
            },
          },
        );
      } else {
        final user = response['userMessageId'];
        final assistant = response['messageId'];
        if (user is! String ||
            assistant is! String ||
            (op.kind == 'chat_send' && user != op.id))
          throw const ApiError('invalid_chat_response');
        await store.updateChatClientState(
          op.spaceId,
          user,
          (state) => {
            ...state,
            'assistantId': assistant,
            'delivery': 'waiting_ai',
          },
        );
        if (op.kind == 'chat_retry') {
          await store.updateChatClientState(
            op.spaceId,
            op.payload['messageId']! as String,
            (state) => {...state, 'retryMessageId': assistant},
          );
        }
      }
      await store.removeOp(op.spaceId, op.id);
    });
  }

  /// Validates the entire envelope before mutating anything. A null op_id is
  /// legal only for an ordered malformed-item rejection, never for success.
  Future<bool> applyPushBatch(
    String owner,
    List<LeasedOperation> batch,
    PushResponseDto response,
  ) async {
    if (response.results.length != batch.length) {
      throw const ApiError('invalid_push_response');
    }
    for (var i = 0; i < batch.length; i++) {
      final result = response.results[i];
      if (result.opId != batch[i].op.id &&
          !(result.opId == null &&
              result.status == 'rejected' &&
              result.problem?.status == 422)) {
        throw const ApiError('invalid_push_response');
      }
    }
    return await store.transaction(() async {
      var stop = false;
      for (var i = 0; i < batch.length; i++) {
        final sent = batch[i];
        if (!await _accepts(owner, sent)) {
          continue;
        }
        final op = sent.op;
        final result = response.results[i];
        switch (result.status) {
          case 'ok':
            final server = result.result;
            if (server == null) {
              throw const ApiError('invalid_tool_result');
            }
            await store.removeOp(op.spaceId, op.id);
            for (final ref in op.entityIds) {
              final colon = ref.indexOf(':');
              final kind = ref.substring(0, colon);
              final id = store.keyOf(kind, server);
              if (id.toString() != ref.substring(colon + 1)) {
                throw const ApiError('invalid_tool_result');
              }
              await conflicts.applySuccess(op.spaceId, kind, id, server);
            }
          case 'conflict':
            final current = result.problem?.current;
            if (current == null) {
              throw const ApiError('invalid_conflict');
            }
            for (final ref in op.entityIds) {
              final colon = ref.indexOf(':');
              await conflicts.captureConflict(
                op.spaceId,
                ref.substring(0, colon),
                ref.substring(colon + 1),
                current,
              );
            }
          case 'rejected':
            Logger('sync').warning(
              SafeLogEvent(
                'sync_failed',
                code: result.problem?.code,
                requestId: result.problem?.requestId ?? op.requestId,
              ),
            );
            final limited = result.problem?.status == 429;
            final gated = const {401, 426}.contains(result.problem?.status);
            await store.setOutboxState(
              op.spaceId,
              op.id,
              limited || gated ? 'pending' : 'failed',
              error: {
                'code': result.problem?.code ?? 'rejected',
                'status': result.problem?.status,
                if (limited)
                  'retry_at':
                      now().millisecondsSinceEpoch +
                      SyncPolicy.retry(
                        op.attempts,
                        retryAfter: result.problem?.retryAfter,
                      ).inMilliseconds,
              },
            );
            if (limited || gated) {
              stop = true;
            }
          case 'space_unavailable':
          case 'membership_changed':
            await store.setOutboxState(op.spaceId, op.id, 'pending');
            stop = true;
          case 'not_processed':
            await store.setOutboxState(op.spaceId, op.id, 'pending');
            stop = true;
          default:
            throw const ApiError('unknown_push_status');
        }
      }
      return stop;
    });
  }
}
