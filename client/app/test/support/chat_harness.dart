import 'dart:typed_data';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:dio/dio.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/data/chat/chatweave_store.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';

import 'sync_harness.dart';

const chatCapsJson = <String, Object?>{
  'protocolVersions': ['0.1'],
  'blocks': {'markdown': 1, 'choice': 1, 'x-jiabu.record_card': 1},
  'features': [
    'stream.resume',
    'stream.snapshot',
    'stream.activity',
    'stream.steps',
    'action.choice',
  ],
  'locale': 'zh-CN',
};
Message chatMessage({
  String id = 'reply',
  int rev = 0,
  int seq = 0,
  String text = '用户A',
  String status = 'streaming',
}) => Message.fromJson({
  'id': id,
  'protocolVersion': '0.1',
  'conversationId': 'conversation',
  'role': 'assistant',
  'status': status,
  'rev': rev,
  'lastSeq': seq,
  'createdAt': '2026-10-29T12:00:00Z',
  'fallbackText': text,
  'blocks': [
    {
      'id': 'text',
      'type': 'markdown',
      'schemaVersion': 1,
      'status': 'pending',
      'data': {'text': text},
      'fallbackText': text,
    },
  ],
});
Map<String, Object?> chatRow(
  Message message, {
  int? seq,
  String member = 'm',
}) => {
  'id': message.id,
  'member_id': member,
  'conversation_id': message['conversationId'],
  'role': message['role'],
  'message': message.json,
  'rev': message.rev,
  'last_seq': seq ?? message['lastSeq'] ?? 0,
  'created_at': message['createdAt'],
  'stream_status': message.status,
  'fallback_text': message['fallbackText'],
};

class FakeChatApi implements ChatApi {
  bool offline = false;
  ApiError? failure;
  final writes =
      <
        ({
          String endpoint,
          String id,
          String requestId,
          Map<String, Object?> payload,
          String? capabilities,
        })
      >[];
  final opens = <({String space, String message, int? seq, String caps})>[];
  List<ActiveMessage> active = [];
  Future<void> Function()? beforeReply;
  Stream<List<int>> bytes = const Stream.empty();
  Map<String, Object?>? reply;
  @override
  Future<Map<String, Object?>> chatWrite({
    required String spaceId,
    required String endpoint,
    required Map<String, Object?> payload,
    required int joinEpoch,
    required String opId,
    required String requestId,
    String? capabilities,
  }) async {
    if (offline) throw const ApiError('network');
    writes.add((
      endpoint: endpoint,
      id: opId,
      requestId: requestId,
      payload: payload,
      capabilities: capabilities,
    ));
    await beforeReply?.call();
    if (failure != null) throw failure!;
    return reply ??
        (endpoint == 'actions'
            ? {
                'status': 'accepted',
                'resume': {'messageId': 'reply'},
              }
            : endpoint.endsWith('/stop')
            ? {'status': 'accepted'}
            : {'userMessageId': payload['id'] ?? 'user', 'messageId': 'reply'});
  }

  @override
  Future<List<ActiveMessage>> chatActive(String spaceId) async {
    if (offline) throw const ApiError('network');
    return active;
  }

  @override
  Future<StreamConnection> chatStream(
    String spaceId,
    String messageId, {
    required String capabilities,
    int? afterSeq,
    CancelToken? cancelToken,
  }) async {
    if (offline) throw const ApiError('network');
    opens.add((
      space: spaceId,
      message: messageId,
      seq: afterSeq,
      caps: capabilities,
    ));
    return StreamConnection(
      status: 200,
      headers: {'chatweave-protocol': '0.1'},
      bytes: bytes,
    );
  }
}

class _Picker implements ImagePickerPort {
  @override
  Future<List<Uint8List>> pick({
    required bool camera,
    bool files = false,
  }) async => [];
}

class _Codec implements ImageCompressorPort {
  @override
  Future<Uint8List> jpeg(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
    required bool correctOrientation,
  }) async => bytes;
}

class ChatHarness {
  ChatHarness(this.h, this.api, this.session, this.persistence, this.processor);
  final SyncHarness h;
  final FakeChatApi api;
  final LocalChatSession session;
  final JiabuChatWeaveStore persistence;
  final OutboxProcessor processor;
  static Future<ChatHarness> create({bool offline = true}) async {
    final h = await SyncHarness.create();
    final api = FakeChatApi()..offline = offline;
    final fence = (await h.store.fence('s'))!;
    final media = MediaService(
      store: h.store,
      directory: h.directory,
      picker: _Picker(),
      compressor: _Codec(),
    );
    final session = LocalChatSession(
      dao: h.store,
      api: api,
      fence: fence,
      memberId: 'm',
      caps: ClientCapabilities.fromJson(chatCapsJson),
      sync: () async {},
      media: media,
    );
    await session.initialize();
    return ChatHarness(
      h,
      api,
      session,
      session.persistence,
      OutboxProcessor(
        h.store,
        h.api,
        h.conflicts,
        chatApi: api,
        now: () => h.clock,
      ),
    );
  }

  Future<String> owner() async {
    const owner = 'chat-round';
    await h.store.acquireRound(
      owner,
      h.clock.millisecondsSinceEpoch,
      h.clock.add(const Duration(minutes: 12)).millisecondsSinceEpoch,
    );
    return owner;
  }

  Future<void> enqueue(
    String kind,
    String id, {
    String entity = 'reply',
    Set<String> depends = const {},
  }) => h.store.enqueue(
    OutboxOperation(
      id: id,
      spaceId: 's',
      joinEpoch: 1,
      kind: kind,
      requestId: id,
      payload: kind == 'chat_action'
          ? action(id).json
          : kind == 'chat_retry'
          ? {'messageId': entity}
          : {'id': id, 'text': '用户A', 'images': <String>[]},
      entityIds: {'chat_entry:$entity'},
      dependsOn: depends,
      createdAt: h.clock.microsecondsSinceEpoch,
    ),
  );
  ActionRequest action(String id) => ActionRequest.fromJson({
    'protocolVersion': '0.1',
    'id': id,
    'context': {
      'conversationId': 'conversation',
      'messageId': 'reply',
      'blockId': 'question',
    },
    'type': 'choice.select',
    'target': 'clarification.answer',
    'payload': {
      'selected': ['credit'],
    },
  });
  Future<void> close() async {
    await session.dispose();
    await h.close();
  }
}

class FixedChatRepository implements ChatRepository {
  FixedChatRepository(this.session);
  final ChatConversation session;
  @override
  Future<Result<ChatConversation>> open(
    String spaceId,
    ClientCapabilities caps,
  ) async => Ok(session);
  @override
  Future<void> foreground() async {}
  @override
  Future<void> disconnect() => session.disconnect();
  @override
  Future<void> dispose() async {}
}
