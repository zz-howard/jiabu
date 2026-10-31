import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/data/chat/chat_capabilities.dart';
import 'package:jiabu/data/chat/chatweave_store.dart';
import 'package:jiabu/data/chat/sse_transport.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final class _Refresh implements AuthoritativeRefresh {
  _Refresh(this.session);
  final LocalChatSession session;
  @override
  Future<Message?> refresh(String messageId) async {
    await session.sync();
    return await session.persistence.load(messageId);
  }
}

final class LocalChatSession implements ChatConversation {
  LocalChatSession({
    required this.dao,
    required this.api,
    required this.fence,
    required this.memberId,
    required this.caps,
    required this.sync,
    required this.media,
    this.onEnqueued,
  }) {
    persistence = JiabuChatWeaveStore(dao, fence, memberId);
    transport = JiabuStreamTransport(api, dao, fence);
    conversationId = 'local:$memberId';
    _makeControllers();
  }
  final LocalStore dao;
  final ChatApi api;
  final RequestFence fence;
  final String memberId;
  final ClientCapabilities caps;
  final Future<void> Function() sync;
  final MediaService media;
  final void Function()? onEnqueued;
  late final JiabuChatWeaveStore persistence;
  late final JiabuStreamTransport transport;
  @override
  String get spaceId => fence.spaceId;
  @override
  late String conversationId;
  @override
  BlockStore blocks = BlockStore();
  @override
  late InteractionController interactions;
  @override
  late InterruptComposerController composer;
  late ChatWeaveStreamController _stream;
  final _events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => _events.stream;
  @override
  Map<String, ChatDelivery> delivery = {};
  @override
  Set<String> stopRequested = {};
  @override
  bool online = false;
  @override
  bool get aiUnavailable => blocks.snapshot.messages.keys.any(
    (id) => blocks.activityFor(id)?['phase'] == 'degraded',
  );
  @override
  String? error;
  @override
  String draft = '';
  @override
  void Function(String messageId, String blockId)? revealInterrupt;
  @override
  List<String> draftImages = [];
  @override
  Future<void> saveDraft(String text, List<String> images) async {
    draft = text;
    draftImages = List.unmodifiable(images);
    try {
      await dao.transaction(() async {
        await dao.lockRuntime();
        if (!_closed && await dao.accepts(fence)) {
          await dao.updateChatClientState(
            spaceId,
            '@draft:$memberId',
            (_) => {'text': text, 'images': images},
          );
        }
      });
    } on Object {
      _log('internal');
    }
  }

  StreamSubscription<void>? _database;
  StreamSubscription<StoreSnapshot>? _projection;
  StreamSubscription<void>? _actions;
  bool _closed = false;
  bool _reading = false;
  bool _readAgain = false;
  Future<void>? _recovery;
  bool _attached = true;
  bool _foreground = true;
  bool get attached => _attached;
  final _restored = <String>{};
  final _receipts = <String>{};
  final _discovered = <String>{};
  final _checkpointSeq = <String, int>{};

  void _notify() {
    if (!_closed) {
      _events.add(null);
    }
  }

  void _log(String code) {
    Logger('chat').warning(SafeLogEvent('chat_failed', code: code));
  }

  void _makeControllers() {
    _stream = ChatWeaveStreamController(
      store: blocks,
      persistence: persistence,
      transport: transport,
      authority: _Refresh(this),
      caps: caps,
    );
    interactions = InteractionController(
      store: blocks,
      persistence: persistence,
      transport: JiabuActionTransport(dao, fence, onEnqueued: onEnqueued),
      nextId: () => const Uuid().v7(),
      onResume: (id) async {
        if (_attached && _foreground) {
          unawaited(_subscribe(id, ResumeTrigger.action));
        }
      },
      onRefresh: (_) async {
        await sync();
      },
    );
    composer = InterruptComposerController(
      store: blocks,
      interactions: interactions,
      conversationId: conversationId,
      onReveal: (message, block) => revealInterrupt?.call(message, block),
    );
    _projection = blocks.changes.listen((snapshot) {
      for (final message in snapshot.messages.values) {
        final seq = snapshot.cursors[message.id] ?? 0;
        if (message['role'] == 'assistant' &&
            message.rev == 0 &&
            seq > (_checkpointSeq[message.id] ?? 0)) {
          _checkpointSeq[message.id] = seq;
          unawaited(
            persistence.saveProvisional(message, lastSeq: seq).catchError((
              Object _,
            ) {
              _log('internal');
            }),
          );
        }
      }
      _notify();
    });
    _actions = interactions.changes.listen((_) => _notify());
  }

  Future<void> initialize() async {
    final saved = await dao.chatClientState(spaceId, '@draft:$memberId');
    draft = saved['text'] as String? ?? '';
    draftImages = (saved['images'] as List<Object?>? ?? []).cast<String>();
    await _reload();
    _database = dao
        .watchChatChanges(spaceId)
        .listen(
          (_) {
            unawaited(_reload());
          },
          onError: (Object _, StackTrace _) {
            error = 'local_read_failed';
            _log(error!);
            _notify();
          },
        );
    unawaited(recover());
  }

  Future<void> _reset(String id) async {
    await _projection?.cancel();
    await _actions?.cancel();
    await composer.dispose();
    await interactions.dispose();
    await _stream.dispose();
    await blocks.dispose();
    blocks = BlockStore();
    conversationId = id;
    _restored.clear();
    _receipts.clear();
    _discovered.clear();
    _checkpointSeq.clear();
    _makeControllers();
  }

  Future<void> _reload() async {
    if (_reading) {
      _readAgain = true;
      return;
    }
    _reading = true;
    try {
      do {
        _readAgain = false;
        if (_closed) {
          return;
        }
        if (!await dao.accepts(fence)) {
          await _reset(conversationId);
          draft = '';
          draftImages = [];
          delivery = {};
          error = 'stale_response';
          _attached = false;
          transport.disconnect();
          _notify();
          return;
        }
        final conversations = await dao.entities(spaceId, 'conversation');
        final actual =
            conversations
                    .where((row) => row.data['member_id'] == memberId)
                    .firstOrNull
                    ?.data['id']
                as String?;
        final all = await dao.entities(spaceId, 'chat_entry');
        final own = all
            .where((row) => row.data['member_id'] == memberId)
            .toList();
        final inferred =
            own
                    .where(
                      (row) =>
                          row.syncState == 'synced' &&
                          !(row.data['conversation_id'] as String? ?? '')
                              .startsWith('local:'),
                    )
                    .firstOrNull
                    ?.data['conversation_id']
                as String?;
        final id = actual ?? inferred ?? conversationId;
        if (id != conversationId) {
          await _reset(id);
        }
        final queue = await dao.outbox(spaceId);
        if (queue.any(
          (op) => op.kind == 'chat_action' && op.state == 'failed',
        )) {
          error = 'chat_action_failed';
        } else if (error == 'chat_action_failed') {
          error = null;
        }
        final nextDelivery = <String, ChatDelivery>{};
        final nextStops = <String>{};
        for (final row in own) {
          final messageId = row.data['id']! as String;
          final raw = await dao.chatEntry(spaceId, messageId);
          if (raw == null) {
            continue;
          }
          var message = JiabuChatWeaveStore.decode(raw);
          if (message == null) {
            continue;
          }
          if ((message['conversationId'] as String? ?? '').startsWith(
            'local:',
          )) {
            message = Message.fromJson({
              ...message.json,
              'conversationId': conversationId,
            });
          }
          final old = blocks.snapshot.messages[messageId];
          if (raw['authoritative'] == 1 &&
              old != null &&
              message.rev < old.rev) {
            await _reset(conversationId);
            _readAgain = true;
            break;
          }
          // Keep fresher in-memory deltas during disk throttling.
          if (raw['authoritative'] == 1 ||
              (raw['last_seq']! as int) >=
                  (blocks.snapshot.cursors[messageId] ?? 0)) {
            final checkpoint = Message.fromJson({
              ...message.json,
              'lastSeq': raw['last_seq'],
            });
            blocks.apply(SyncMessage(checkpoint));
            if (_attached &&
                _foreground &&
                old?.status == 'paused' &&
                checkpoint.status != 'paused') {
              unawaited(_subscribe(messageId, ResumeTrigger.checkpoint));
            }
          }
          final local = await dao.chatClientState(spaceId, messageId);
          if (local['stopRequested'] == true) {
            nextStops.add(messageId);
          }
          final assistantId = local['assistantId'] as String?;
          if (_attached &&
              _foreground &&
              assistantId != null &&
              _discovered.add(assistantId)) {
            unawaited(_subscribe(assistantId, ResumeTrigger.conversation));
          }
          final retryId = local['retryMessageId'] as String?;
          if (_attached &&
              _foreground &&
              retryId != null &&
              _discovered.add(retryId)) {
            unawaited(_subscribe(retryId, ResumeTrigger.conversation));
          }
          if (message['role'] == 'user') {
            final op = queue
                .where((op) => op.kind == 'chat_send' && op.id == messageId)
                .firstOrNull;
            // A streamed reply carries no replyTo until the next pull, so the
            // send/retry response ids saved on this message count as links too.
            final replyIds = {
              if (local['assistantId'] case final String id) id,
              if (local['retryMessageId'] case final String id) id,
            };
            final assistant = own
                .where(
                  (row) =>
                      row.data['reply_to_id'] == messageId ||
                      replyIds.contains(row.data['id']),
                )
                .lastOrNull;
            nextDelivery[messageId] = local['manual'] == true
                ? ChatDelivery.manual
                : op != null
                ? (op.state == 'failed' ||
                          queue.any(
                            (dependency) =>
                                dependency.state == 'failed' &&
                                dependency.references
                                    .intersection(op.dependsOn)
                                    .isNotEmpty,
                          )
                      ? ChatDelivery.failed
                      : ChatDelivery.pending)
                : assistant != null &&
                      const {
                        'complete',
                        'interrupted',
                        'error',
                      }.contains(assistant.data['stream_status'])
                ? ChatDelivery.complete
                : ChatDelivery.waitingAi;
          }
          if (_restored.add(messageId)) {
            await interactions.restore(messageId);
          }
          final receipts = local['receipts'] as Map<String, Object?>? ?? {};
          for (final receipt in receipts.entries) {
            if (_receipts.add(receipt.key)) {
              await interactions.retryPending(messageId);
              final result = receipt.value! as Map<String, Object?>;
              if (result['resume'] case final Map<String, Object?> resume) {
                if (_attached && _foreground) {
                  unawaited(
                    _subscribe(
                      resume['messageId']! as String,
                      ResumeTrigger.action,
                    ),
                  );
                }
              }
              if (local['action_refresh'] == true) {
                unawaited(_refreshAfterRejected());
              }
            }
          }
        }
        delivery = Map.unmodifiable(nextDelivery);
        stopRequested = Set.unmodifiable(nextStops);
        _notify();
      } while (_readAgain && !_closed);
    } on Object {
      error = 'local_read_failed';
      _log(error!);
      _notify();
    } finally {
      _reading = false;
    }
  }

  Future<void> _refreshAfterRejected() async {
    try {
      await sync();
    } on Object {
      _log('chat_refresh_failed');
    }
  }

  Future<void> _subscribe(String id, ResumeTrigger trigger) async {
    if (_closed || !_attached || !_foreground) {
      return;
    }
    final controller = _stream;
    try {
      await controller.subscribe(id, trigger: trigger);
    } on Object {
      if (!_closed &&
          identical(controller, _stream) &&
          _attached &&
          _foreground) {
        online = false;
        _log('chat_stream_failed');
        _notify();
      }
    }
  }

  @override
  Future<void> recover() {
    if (_closed) {
      return Future<void>.value();
    }
    _attached = true;
    _foreground = true;
    return _recovery ??= _recover().whenComplete(() {
      _recovery = null;
    });
  }

  Future<void> _recover() async {
    try {
      await sync();
      await _reload();
      final active = await transport.activeMessages(conversationId);
      online = true;
      error = null;
      for (final message in active) {
        if (stopRequested.contains(message.id)) {
          await transport.stop(message.id);
          unawaited(_refreshAfterRejected());
        } else {
          final changed =
              blocks.snapshot.messages[message.id]?.status == 'paused' &&
              message['status'] != 'paused';
          unawaited(
            _subscribe(
              message.id,
              changed ? ResumeTrigger.activeChanged : ResumeTrigger.foreground,
            ),
          );
        }
      }
    } on Object {
      online = false;
      _log('chat_recovery_failed');
    } finally {
      _notify();
    }
  }

  Future<Result<T>> _guard<T>(Future<T> Function() work) async {
    try {
      if (_closed || !await dao.accepts(fence)) {
        return const Failure('stale_response');
      }
      final value = await work();
      if (_closed || !await dao.accepts(fence)) {
        return const Failure('stale_response');
      }
      return Ok(value);
    } on ApiError catch (failure) {
      _log(failure.code);
      return Failure(failure.code);
    } on Object {
      _log('chat_write_failed');
      return const Failure('chat_write_failed');
    }
  }

  @override
  Future<Result<void>> send(String text, List<String> images) =>
      _guard(() async {
        if ((await dao.runtime())['write_allowed'] != 1) {
          throw const ApiError('client_too_old');
        }
        if (composer.state.mode != ComposerMode.free) {
          throw const ApiError('chat_answer_first');
        }
        if (text.trim().isEmpty && images.isEmpty) {
          throw const ApiError('chat_empty');
        }
        if (utf8.encode(text).length > 32000 || images.length > 8) {
          throw const ApiError('chat_too_large');
        }
        final id = const Uuid().v7();
        await dao.transaction(() async {
          await dao.lockRuntime();
          if (!await dao.accepts(fence)) {
            throw const ApiError('stale_response');
          }
          final message = {
            'protocolVersion': '0.1',
            'id': id,
            'conversationId': conversationId,
            'role': 'user',
            'status': 'complete',
            'rev': 0,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'fallbackText': text,
            'blocks': <Object?>[],
            'metadata': {
              'input': {'text': text, 'images': images},
            },
          };
          await dao.putChatEntry(
            spaceId,
            {
              'id': id,
              'member_id': memberId,
              'conversation_id': conversationId,
              'role': 'user',
              'created_at': message['createdAt'],
              'message_json': message,
              'fallback_text': text,
              'stream_status': 'complete',
            },
            authoritative: false,
            state: 'pending',
          );
          await dao.enqueue(
            OutboxOperation(
              id: id,
              spaceId: spaceId,
              joinEpoch: fence.joinEpoch,
              kind: 'chat_send',
              payload: {
                'id': id,
                'text': text,
                'images': images,
                chatCapabilitiesEnvelopeKey: chatCapabilitiesHeader(caps),
              },
              entityIds: {'chat_entry:$id'},
              dependsOn: {for (final hash in images) 'blob:chat:$hash'},
              requestId: const Uuid().v7(),
              createdAt: DateTime.now().microsecondsSinceEpoch,
            ),
          );
          dao.afterCommit(onEnqueued);
        });
      });
  @override
  Future<Result<List<int>>> image(String hash) => _guard(() async {
    final blob = (await dao.blobs(spaceId))
        .where((row) => row['module'] == 'chat' && row['sha256'] == hash)
        .firstOrNull;
    if (blob != null) {
      final file = File(blob['path']! as String);
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    }
    if (api is ApiClient) {
      return await (api as ApiClient).downloadBlob(spaceId, hash, 'original');
    }
    throw const ApiError('image_unavailable');
  });
  @override
  Future<Result<List<String>>> photos({
    required bool camera,
    bool files = false,
    int limit = 8,
  }) => media.pick(
    spaceId,
    'chat',
    camera: camera,
    files: files,
    limit: limit.clamp(0, 8),
  );
  @override
  Future<Result<void>> retry(String messageId) => _guard(() async {
    if ((await dao.runtime())['write_allowed'] != 1) {
      throw const ApiError('client_too_old');
    }
    final current = blocks.snapshot.messages[messageId];
    if (current == null ||
        !const {'error', 'interrupted'}.contains(current.status)) {
      throw const ApiError('retry_unavailable');
    }
    await dao.transaction(() async {
      await dao.lockRuntime();
      if (!await dao.accepts(fence)) {
        throw const ApiError('stale_response');
      }
      final existing = (await dao.outbox(spaceId))
          .where(
            (op) =>
                op.kind == 'chat_retry' && op.payload['messageId'] == messageId,
          )
          .firstOrNull;
      if (existing != null) {
        if (existing.state == 'failed') {
          await dao.setOutboxState(spaceId, existing.id, 'pending');
          dao.afterCommit(onEnqueued);
        }
        return;
      }
      await dao.enqueue(
        OutboxOperation(
          id: const Uuid().v7(),
          spaceId: spaceId,
          joinEpoch: fence.joinEpoch,
          kind: 'chat_retry',
          payload: {
            'messageId': messageId,
            chatCapabilitiesEnvelopeKey: chatCapabilitiesHeader(caps),
          },
          entityIds: {'chat_entry:$messageId'},
          dependsOn: const {},
          requestId: const Uuid().v7(),
          createdAt: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      dao.afterCommit(onEnqueued);
    });
  });
  @override
  Future<Result<void>> retryUpload(String userMessageId) => _guard(() async {
    await dao.transaction(() async {
      if (!await dao.accepts(fence)) {
        throw const ApiError('stale_response');
      }
      final ops = await dao.outbox(spaceId);
      final op = ops
          .where((op) => op.id == userMessageId && op.kind == 'chat_send')
          .firstOrNull;
      if (op == null || op.state == 'sending') {
        return;
      }
      for (final blob in ops.where(
        (candidate) =>
            candidate.kind == 'blob' &&
            candidate.references.intersection(op.dependsOn).isNotEmpty,
      )) {
        if (blob.state == 'failed') {
          await dao.setOutboxState(spaceId, blob.id, 'pending');
        }
      }
      await dao.setOutboxState(spaceId, op.id, 'pending');
      dao.afterCommit(onEnqueued);
    });
  });
  @override
  Future<Result<void>> stop(String messageId) => _guard(() async {
    if (!online) {
      throw const ApiError('chat_online_required');
    }
    await _stream.stop(messageId);
  });
  @override
  Future<Result<Map<String, Object?>>> takeOver(String userMessageId) =>
      _guard(() async {
        final clientState = await dao.chatClientState(spaceId, userMessageId);
        if (clientState['manual'] == true) {
          return <String, Object?>{};
        }
        var localOnly = false;
        await dao.transaction(() async {
          await dao.lockRuntime();
          if (!await dao.accepts(fence)) {
            throw const ApiError('stale_response');
          }
          final op = (await dao.outbox(spaceId))
              .where((op) => op.id == userMessageId && op.kind == 'chat_send')
              .firstOrNull;
          if (op != null &&
              op.state != 'sending' &&
              (op.attempts == 0 ||
                  (op.state == 'failed' && op.lastError?['status'] == 422))) {
            await dao.removeOp(spaceId, op.id);
            localOnly = true;
            await dao.updateChatClientState(
              spaceId,
              userMessageId,
              (state) => {...state, 'manual': true},
            );
          }
        });
        if (!localOnly) {
          if (!online) {
            throw const ApiError('chat_online_required');
          }
          await sync();
          final local = await dao.chatClientState(spaceId, userMessageId);
          var assistant = local['assistantId'] as String?;
          assistant ??=
              (await dao.entities(spaceId, 'chat_entry'))
                      .where((row) => row.data['reply_to_id'] == userMessageId)
                      .lastOrNull
                      ?.data['id']
                  as String?;
          if (assistant == null) {
            throw const ApiError('chat_wait_upload');
          }
          await transport.stop(assistant);
          await sync();
          final finalMessage = await persistence.load(assistant);
          if (finalMessage == null || finalMessage.rev < 1) {
            throw const ApiError('chat_wait_stop');
          }
          // A run may already have saved a record before it entered waiting_ai.
          if (finalMessage.blocks.any(
            (block) => block.type == 'x-jiabu.record_card',
          )) {
            throw const ApiError('chat_already_recorded');
          }
          await dao.updateChatClientState(
            spaceId,
            userMessageId,
            (state) => {...state, 'manual': true},
          );
        }
        await _reload();
        // Never infer amount/account/purpose from natural-language input.
        return <String, Object?>{};
      });
  @override
  Future<void> disconnect() async {
    if (_closed) {
      return;
    }
    _attached = false;
    await suspend();
  }

  Future<void> suspend() async {
    if (_closed) {
      return;
    }
    _foreground = false;
    online = false;
    _notify();
    transport.disconnect();
    await persistence.flush();
    await _stream.dispose();
    _stream = ChatWeaveStreamController(
      store: blocks,
      persistence: persistence,
      transport: transport,
      authority: _Refresh(this),
      caps: caps,
    );
  }

  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    transport.dispose();
    await _database?.cancel();
    await _projection?.cancel();
    await _actions?.cancel();
    await composer.dispose();
    await interactions.dispose();
    await _stream.dispose();
    await persistence.dispose();
    await blocks.dispose();
    await _events.close();
  }
}
