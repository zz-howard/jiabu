import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';

final class LocalChatRepository implements ChatRepository {
  LocalChatRepository({
    required this.dao,
    required this.api,
    required this.sync,
    required this.media,
    required this.memberForSpace,
    this.onEnqueued,
  });
  final LocalStore dao;
  final ChatApi api;
  final Future<void> Function(String spaceId) sync;
  final MediaService media;
  final Future<String?> Function(String) memberForSpace;
  final void Function()? onEnqueued;
  final _sessions = <String, LocalChatSession>{};
  bool _closed = false;

  @override
  Future<Result<ChatConversation>> open(
    String spaceId,
    ClientCapabilities caps,
  ) async {
    if (_closed) return const Failure('stale_response');
    final existing = _sessions[spaceId];
    if (existing != null) {
      if (await dao.accepts(existing.fence)) return Ok(existing);
      _sessions.remove(spaceId);
      await existing.dispose();
    }
    final fence = await dao.fence(spaceId);
    final member = await memberForSpace(spaceId);
    if (fence == null || member == null || _closed)
      return const Failure('unauthenticated');
    final session = LocalChatSession(
      dao: dao,
      api: api,
      fence: fence,
      memberId: member,
      caps: caps,
      sync: () => sync(spaceId),
      media: media,
      onEnqueued: onEnqueued,
    );
    _sessions[spaceId] = session;
    try {
      await session.initialize();
      return Ok(session);
    } on Object {
      _sessions.remove(spaceId);
      await session.dispose();
      return const Failure('local_read_failed');
    }
  }

  @override
  Future<void> foreground() async {
    for (final session in _sessions.values.toList()) {
      if (session.attached) await session.recover();
    }
  }

  @override
  Future<void> disconnect() async {
    for (final session in _sessions.values.toList()) {
      await session.suspend();
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    for (final session in _sessions.values.toList()) {
      await session.dispose();
    }
    _sessions.clear();
  }
}
