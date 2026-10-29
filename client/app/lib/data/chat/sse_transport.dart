import 'package:chatweave_core/chatweave_core.dart';
import 'package:dio/dio.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/chat/chat_capabilities.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:uuid/uuid.dart';

final class JiabuStreamTransport implements StreamTransport {
  JiabuStreamTransport(this.api, this.store, this.fence);
  final ChatApi api;
  final LocalStore store;
  final RequestFence fence;
  final _connections = <CancelToken>{};
  bool _closed = false;

  Future<void> _check() async {
    if (_closed || !await store.accepts(fence)) {
      throw const ApiError('stale_response');
    }
  }

  @override
  Future<StreamConnection> open(
    String messageId, {
    required ClientCapabilities caps,
    int? afterSeq,
  }) async {
    await _check();
    final cancel = CancelToken();
    _connections.add(cancel);
    try {
      final connection = await api.chatStream(
        fence.spaceId,
        messageId,
        capabilities: chatCapabilitiesHeader(caps),
        afterSeq: afterSeq,
        cancelToken: cancel,
      );
      await _check();
      return StreamConnection(
        status: connection.status,
        headers: connection.headers,
        bytes: _guard(connection.bytes, cancel),
      );
    } on Object {
      cancel.cancel();
      _connections.remove(cancel);
      rethrow;
    }
  }

  Stream<List<int>> _guard(Stream<List<int>> bytes, CancelToken cancel) async* {
    try {
      await for (final chunk in bytes) {
        await _check();
        yield chunk;
      }
    } finally {
      cancel.cancel();
      _connections.remove(cancel);
    }
  }

  @override
  Future<StopResult> stop(String messageId) async {
    await _check();
    final result = await api.chatWrite(
      spaceId: fence.spaceId,
      endpoint: 'messages/$messageId/stop',
      payload: const {},
      joinEpoch: fence.joinEpoch,
      opId: const Uuid().v7(),
      requestId: const Uuid().v7(),
    );
    await _check();
    return StopResult.fromJson(result);
  }

  @override
  Future<List<ActiveMessage>> activeMessages(String conversationId) async {
    await _check();
    final messages = await api.chatActive(fence.spaceId);
    await _check();
    return messages
        .where((message) => message['conversationId'] == conversationId)
        .toList();
  }

  void disconnect() {
    for (final token in _connections.toList()) {
      token.cancel();
    }
    _connections.clear();
  }

  void dispose() {
    _closed = true;
    disconnect();
  }
}
