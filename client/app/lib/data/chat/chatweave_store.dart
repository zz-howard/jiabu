import 'dart:async';
import 'dart:convert';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:logging/logging.dart';

final class JiabuChatWeaveStore implements ChatWeaveStore {
  JiabuChatWeaveStore(this.dao, this.fence, this.memberId);
  final LocalStore dao;
  final RequestFence fence;
  final String memberId;
  final _pending = <String, ({Message message, int seq})>{};
  final _finished = <String, int>{};
  Timer? _timer;
  bool _closed = false;

  static Message? decode(Map<String, Object?> row) {
    final raw = row['message_json'];
    if (raw == null) {
      return null;
    }
    return Message.fromJson(
      raw is String
          ? jsonDecode(raw) as Map<String, Object?>
          : raw as Map<String, Object?>,
    );
  }

  @override
  Stream<List<Message>> watchConversation(String conversationId) async* {
    await for (final _ in dao.watchChatChanges(fence.spaceId)) {
      if (_closed || !await dao.accepts(fence)) {
        return;
      }
      yield (await dao.chatEntries(
        fence.spaceId,
        memberId,
        conversationId,
      )).map(decode).whereType<Message>().toList();
    }
  }

  @override
  Future<Message?> load(String messageId) async {
    if (_closed || !await dao.accepts(fence)) {
      return null;
    }
    final row = await dao.chatEntry(fence.spaceId, messageId);
    return row == null || row['member_id'] != memberId ? null : decode(row);
  }

  @override
  Future<int?> lastSeq(String messageId) async {
    final row = await dao.chatEntry(fence.spaceId, messageId);
    return row == null || row['member_id'] != memberId
        ? null
        : row['last_seq']! as int;
  }

  @override
  Future<void> saveProvisional(Message message, {required int lastSeq}) async {
    if (_closed) {
      return;
    }
    final old = _pending[message.id];
    if (old == null || lastSeq >= old.seq) {
      _pending[message.id] = (message: message, seq: lastSeq);
    }
    final finished = message.blocks
        .where((b) => b['status'] == 'complete')
        .length;
    final blockEnded = finished > (_finished[message.id] ?? 0);
    _finished[message.id] = finished;
    if (message.status == 'paused' || blockEnded) {
      await flush();
    } else {
      _timer ??= Timer(SyncPolicy.chatCheckpoint, () {
        _timer = null;
        unawaited(
          flush().catchError((Object _) {
            Logger('chat')
                .warning(const SafeLogEvent('chat_failed', code: 'internal'));
          }),
        );
      });
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final pending = Map<String, ({Message message, int seq})>.from(_pending);
    _pending.clear();
    for (final item in pending.values) {
      await _save(item.message, item.seq);
    }
  }

  Future<void> _save(Message message, int seq) => dao.transaction(() async {
    if (_closed || !await dao.accepts(fence)) {
      return;
    }
    final existing = await dao.chatEntry(fence.spaceId, message.id);
    if (existing != null && existing['member_id'] != memberId) {
      return;
    }
    await dao.putChatEntry(fence.spaceId, {
      'id': message.id,
      'member_id': memberId,
      'conversation_id': message['conversationId'],
      'role': message['role'],
      'reply_to_id': message['replyTo'] ?? existing?['reply_to_id'],
      'created_at': message['createdAt'],
      'protocol_version': message['protocolVersion'],
      'fallback_text': message['fallbackText'] ?? '',
      'stream_status': message.status,
      'message_json': message.json,
      'rev': message.rev,
      'last_seq': seq,
    }, authoritative: false);
  });
  @override
  Future<void> saveFinal(Message message) async {
    _pending.remove(message.id);
    await _save(
      message,
      (message['lastSeq'] as int?) ?? await lastSeq(message.id) ?? 0,
    );
  }

  @override
  Future<ClientState> loadClientState(String messageId) async {
    final state = await dao.chatClientState(fence.spaceId, messageId);
    return ClientState(
      stopRequested: state['stopRequested'] == true,
      intents: {
        for (final entry
            in (state['intents'] as Map<String, Object?>? ?? {}).entries)
          entry.key: ActionRequest.fromJson(
            entry.value! as Map<String, Object?>,
          ),
      },
    );
  }

  @override
  Future<void> saveClientState(String messageId, ClientState state) =>
      dao.transaction(() async {
        if (_closed || !await dao.accepts(fence)) {
          return;
        }
        await dao.updateChatClientState(
          fence.spaceId,
          messageId,
          (old) => {
            ...old,
            'stopRequested': state.stopRequested,
            'intents': state.intents.map(
              (key, value) => MapEntry(key, value.json),
            ),
          },
        );
      });
  @override
  Future<void> clear() => dao.clearChat(fence.spaceId);
  Future<void> dispose() async {
    await flush();
    _closed = true;
    _timer?.cancel();
  }
}
