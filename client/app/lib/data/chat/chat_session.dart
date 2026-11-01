import 'dart:async';
import 'dart:collection';
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
import 'package:jiabu/domain/chat_files.dart';
import 'package:jiabu/domain/entity_ref.dart';
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

/// What the session keeps of a loaded chat row besides its message.
typedef _ChatRow = ({
  ChatCursor at,
  String? role,
  String? replyTo,
  String? status,
  bool message,
});

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
    this.pageSize = defaultPageSize,
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

  /// Messages per page. 40 fill two to four phone screens, inside the 30–50
  /// the owner asked for: the first screen is full on open and the first
  /// scroll up still has content while the next page loads. Opening reads
  /// one page, so its cost no longer grows with the history.
  static const defaultPageSize = 40;
  final int pageSize;
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
  List<ChatFile> draftFiles = [];
  @override
  Future<void> saveDraft(
    String text,
    List<String> images,
    List<ChatFile> files,
  ) async {
    draft = text;
    draftImages = List.unmodifiable(images);
    draftFiles = List.unmodifiable(files);
    try {
      await dao.transaction(() async {
        await dao.lockRuntime();
        if (!_closed && await dao.accepts(fence)) {
          await dao.updateChatClientState(
            spaceId,
            '@draft:$memberId',
            (_) => {
              'text': text,
              'images': images,
              'files': [for (final file in files) file.toJson()],
            },
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
  Future<void> _work = Future<void>.value();
  Future<void>? _pendingReload;
  bool _fullPending = false;

  /// The window's lower bound while older messages exist before it.
  ChatCursor? _oldest;

  /// The window's upper bound while it stops short of the latest message.
  ChatCursor? _newest;
  String? _precedingCreatedAt;
  bool _loadingOlder = false;
  bool _loadingNewer = false;

  /// Rows written up to this change revision are reflected in the window.
  int _watermark = 0;
  final _rows = <String, _ChatRow>{};
  final _states = <String, Map<String, Object?>>{};
  final _paged = <String>{};
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
    draftFiles = [
      for (final file in saved['files'] as List<Object?>? ?? const [])
        ?ChatFile.fromJson(file),
    ];
    await _reload(full: true);
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
    final sameConversation = id == conversationId;
    // Streams the disposed controller was following, reattached below even
    // when no loaded client state links them (found through recover).
    final streaming = [
      for (final MapEntry(key: messageId, value: row) in _rows.entries)
        if (row.status == 'streaming') messageId,
    ];
    await _projection?.cancel();
    await _actions?.cancel();
    await composer.dispose();
    await interactions.dispose();
    await _stream.dispose();
    await blocks.dispose();
    blocks = BlockStore();
    conversationId = id;
    // New controllers: intents are restored and linked replies followed
    // again (a re-attach, not a second action).
    _restored.clear();
    _discovered.clear();
    if (!sameConversation) {
      // Receipts act at most once per conversation: a reopen of the same
      // one (a jump, a lower revision, a catch-up) does not retry, resume
      // or refresh them again.
      _receipts.clear();
    }
    _checkpointSeq.clear();
    _rows.clear();
    _states.clear();
    _paged.clear();
    _makeControllers();
    if (sameConversation && _attached && _foreground) {
      for (final messageId in streaming) {
        unawaited(_subscribe(messageId, ResumeTrigger.conversation));
      }
    }
  }

  /// Runs reads and page loads one at a time, in call order.
  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _work.then((_) => task());
    _work = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Brings the window up to date. A full read reopens it on the latest page;
  /// otherwise only rows and client states written since the watermark are
  /// read. Calls made while a read is queued join that read.
  Future<void> _reload({bool full = false}) {
    _fullPending = _fullPending || full;
    return _pendingReload ??= _serial(() async {
      _pendingReload = null;
      final reopen = _fullPending;
      _fullPending = false;
      await _read(full: reopen);
    });
  }

  Future<void> _read({required bool full}) async {
    var reopen = full;
    try {
      for (var again = true; again && !_closed;) {
        again = false;
        if (!await dao.accepts(fence)) {
          await _reset(conversationId);
          draft = '';
          draftImages = [];
          draftFiles = [];
          delivery = {};
          error = 'stale_response';
          _attached = false;
          transport.disconnect();
          _notify();
          return;
        }
        final id =
            await dao.chatConversationId(spaceId, memberId) ??
            await dao.chatSyncedConversationId(spaceId, memberId) ??
            conversationId;
        if (id != conversationId) {
          await _reset(id);
          reopen = true;
        }
        final queue = await dao.outbox(spaceId);
        if (queue.any(
          (op) => op.kind == 'chat_action' && op.state == 'failed',
        )) {
          error = 'chat_action_failed';
        } else if (error == 'chat_action_failed') {
          error = null;
        }
        // Read before the rows: a write landing in between is read again on
        // the next pass, never missed.
        final watermark = await dao.chatRevision();
        final List<Map<String, Object?>> rows;
        final Map<String, Map<String, Object?>> states;
        if (reopen) {
          rows = await _openLatest();
          states = await dao.chatClientStates(spaceId, rows.map(_idOf));
        } else {
          if (_newest == null && await _catchUpTooLarge()) {
            // More than a page arrived at once (an offline catch-up or a
            // first sync): show the latest page instead of reading it all in.
            await _reset(conversationId);
            reopen = true;
            again = true;
            continue;
          }
          rows = await _changedRows();
          final ids = {..._rows.keys, ...rows.map(_idOf)};
          final changed = await dao.chatClientStatesChangedSince(
            spaceId,
            _watermark,
          );
          states = {
            for (final entry in changed.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
            ...await dao.chatClientStates(
              spaceId,
              rows
                  .map(_idOf)
                  .where(
                    (id) => !_rows.containsKey(id) && !changed.containsKey(id),
                  ),
            ),
          };
        }
        if (!await _apply(rows, states, paged: false)) {
          await _reset(conversationId);
          reopen = true;
          again = true;
          continue;
        }
        await _settle(queue);
        // Only now: a failed pass reads the same changes again next time.
        _watermark = watermark;
        reopen = false;
        _notify();
      }
    } on Object {
      // A failed reopen leaves a partial window: the next read reopens.
      _fullPending = _fullPending || reopen;
      error = 'local_read_failed';
      _log(error!);
      _notify();
    }
  }

  /// Rows written since the watermark that the window shows: inside its
  /// bounds, or already loaded outside them (replies kept for resuming).
  Future<List<Map<String, Object?>>> _changedRows() async {
    final outside = [
      for (final MapEntry(key: id, value: row) in _rows.entries)
        if (!_inWindowAt(row.at)) id,
    ];
    return [
      ...await dao.chatEntriesChangedSince(
        spaceId,
        memberId,
        _watermark,
        from: _oldest,
        to: _newest,
      ),
      ...await dao.chatEntriesChangedSinceIn(
        spaceId,
        memberId,
        _watermark,
        outside,
      ),
    ]..sort((a, b) => compareChatCursors(chatCursorOf(a), chatCursorOf(b)));
  }

  /// More than a page of rows after the newest one the window holds: the
  /// window would grow past its cap if it read them all.
  Future<bool> _catchUpTooLarge() async {
    ChatCursor? newest;
    for (final row in _rows.values) {
      if (newest == null || compareChatCursors(row.at, newest) > 0) {
        newest = row.at;
      }
    }
    return await dao.chatCountAfter(
          spaceId,
          memberId,
          newest,
          limit: pageSize + 1,
        ) >
        pageSize;
  }

  static String _idOf(Map<String, Object?> row) => row['id']! as String;

  /// Inside the window's bounds; rows older than the window are read with
  /// their page, rows newer than a jumped window with theirs.
  bool _inWindowAt(ChatCursor at) {
    final oldest = _oldest;
    final newest = _newest;
    return (oldest == null || compareChatCursors(at, oldest) >= 0) &&
        (newest == null || compareChatCursors(at, newest) <= 0);
  }

  /// The latest page plus every reply still streaming or waiting for an
  /// answer, so stop, resume and answering work for those outside the page.
  Future<List<Map<String, Object?>>> _openLatest() async {
    _rows.clear();
    _states.clear();
    _paged.clear();
    _newest = null;
    final page = await dao.chatPage(spaceId, memberId, limit: pageSize + 1);
    final (oldest, preceding) = _trim(page, older: true, limit: pageSize);
    _oldest = oldest;
    _precedingCreatedAt = preceding;
    return await _withInFlight(page);
  }

  Future<List<Map<String, Object?>>> _withInFlight(
    List<Map<String, Object?>> page,
  ) async {
    final ids = page.map(_idOf).toSet();
    return [
      for (final row in await dao.chatEntriesInFlight(spaceId, memberId))
        if (!ids.contains(_idOf(row))) row,
      ...page,
    ];
  }

  /// Trims the look-ahead row a page query fetched past [limit] and returns
  /// the window's new bound on that side (null: the window reaches that end)
  /// with, for older pages, the creation time of the row just before it.
  (ChatCursor?, String?) _trim(
    List<Map<String, Object?>> page, {
    required bool older,
    required int limit,
  }) {
    if (page.length <= limit) {
      return (null, null);
    }
    if (older) {
      final preceding = page.removeAt(0)['created_at'] as String?;
      return (chatCursorOf(page.first), preceding);
    }
    page.removeLast();
    return (chatCursorOf(page.last), null);
  }

  /// Applies [rows] to [blocks] and caches their client states. False when an
  /// authoritative row went back a revision, which needs a fresh store.
  Future<bool> _apply(
    List<Map<String, Object?>> rows,
    Map<String, Map<String, Object?>> states, {
    required bool paged,
  }) async {
    _states.addAll(states);
    for (final raw in rows) {
      final messageId = _idOf(raw);
      var message = JiabuChatWeaveStore.decode(raw);
      _rows[messageId] = (
        at: chatCursorOf(raw),
        role: raw['role'] as String?,
        replyTo: raw['reply_to_id'] as String?,
        status: raw['stream_status'] as String?,
        message: message != null,
      );
      if (message == null) {
        continue;
      }
      if ((message['conversationId'] as String? ?? '').startsWith('local:')) {
        message = Message.fromJson({
          ...message.json,
          'conversationId': conversationId,
        });
      }
      final old = blocks.snapshot.messages[messageId];
      if (raw['authoritative'] == 1 && old != null && message.rev < old.rev) {
        return false;
      }
      // Keep fresher in-memory deltas during disk throttling.
      if (raw['authoritative'] == 1 ||
          (raw['last_seq']! as int) >=
              (blocks.snapshot.cursors[messageId] ?? 0)) {
        final checkpoint = Message.fromJson({
          ...message.json,
          'lastSeq': raw['last_seq'],
        });
        if (paged && old == null) {
          // Before apply: the list hears of the message synchronously.
          _paged.add(messageId);
        }
        blocks.apply(SyncMessage(checkpoint));
        if (_attached &&
            _foreground &&
            old?.status == 'paused' &&
            checkpoint.status != 'paused') {
          unawaited(_subscribe(messageId, ResumeTrigger.checkpoint));
        }
      }
    }
    return true;
  }

  /// Derives stop, delivery, resume subscriptions and action receipts for the
  /// messages in the window from their cached rows and client states.
  ///
  /// Messages in [history] just came in with a page: their receipts and reply
  /// links are recorded as handled without acting on them again (no retry,
  /// resume or refresh for something settled long ago). Saved intents are
  /// still restored, since those wait for this device to send them.
  Future<void> _settle(
    List<OutboxOperation> queue, {
    Set<String> history = const {},
  }) async {
    final nextDelivery = <String, ChatDelivery>{};
    final nextStops = <String>{};
    // The latest reply linked to each user message by reply_to_id.
    final linked = <String, String>{};
    for (final MapEntry(key: id, value: row) in _rows.entries) {
      final to = row.replyTo;
      if (to != null) {
        final current = linked[to];
        if (current == null ||
            compareChatCursors(row.at, _rows[current]!.at) > 0) {
          linked[to] = id;
        }
      }
    }
    final unresolved = <String, Set<String>>{};
    final ids = _rows.entries
        .where((entry) => entry.value.message)
        .map((entry) => entry.key)
        .toList();
    for (final messageId in ids) {
      final row = _rows[messageId]!;
      final local = _states[messageId] ?? const <String, Object?>{};
      final settled = history.contains(messageId);
      if (local['stopRequested'] == true) {
        nextStops.add(messageId);
      }
      final assistantId = local['assistantId'] as String?;
      final retryId = local['retryMessageId'] as String?;
      for (final replyId in [?assistantId, ?retryId]) {
        if (settled) {
          _discovered.add(replyId);
        } else if (_attached && _foreground && _discovered.add(replyId)) {
          unawaited(_subscribe(replyId, ResumeTrigger.conversation));
        }
      }
      if (row.role == 'user') {
        final op = queue
            .where((op) => op.kind == 'chat_send' && op.id == messageId)
            .firstOrNull;
        // A streamed reply carries no replyTo until the next pull, so the
        // send/retry response ids saved on this message count as links too.
        final replyIds = {?assistantId, ?retryId};
        if (local['manual'] == true) {
          nextDelivery[messageId] = ChatDelivery.manual;
        } else if (op != null) {
          nextDelivery[messageId] =
              op.state == 'failed' ||
                  queue.any(
                    (dependency) =>
                        dependency.state == 'failed' &&
                        dependency.references
                            .intersection(op.dependsOn)
                            .isNotEmpty,
                  )
              ? ChatDelivery.failed
              : ChatDelivery.pending;
        } else {
          final candidates = [
            ?linked[messageId],
            ...replyIds.where(_rows.containsKey),
          ]..sort((a, b) => compareChatCursors(_rows[a]!.at, _rows[b]!.at));
          // A reply may be newer than a jumped window, or have no reply_to_id
          // row in memory yet: look those up in one query below.
          if (candidates.isEmpty || _newest != null) {
            unresolved[messageId] = replyIds;
          } else {
            nextDelivery[messageId] = _deliveryFor(
              _rows[candidates.last]!.status,
            );
          }
        }
      }
      if (_restored.add(messageId) &&
          (local['intents'] as Map<String, Object?>? ?? const {}).isNotEmpty) {
        // Only saved intents need restoring; the others have nothing to retry.
        await interactions.restore(messageId);
      }
      final receipts = local['receipts'] as Map<String, Object?>? ?? {};
      for (final receipt in receipts.entries) {
        if (_receipts.add(receipt.key) && !settled) {
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
    if (unresolved.isNotEmpty) {
      final replies = await dao.chatReplies(
        spaceId,
        memberId,
        unresolved.keys,
        unresolved.values.expand((ids) => ids),
      );
      for (final MapEntry(key: userId, value: replyIds) in unresolved.entries) {
        final reply = replies
            .where(
              (row) =>
                  row['reply_to_id'] == userId || replyIds.contains(row['id']),
            )
            .lastOrNull;
        nextDelivery[userId] = _deliveryFor(reply?['stream_status'] as String?);
      }
    }
    delivery = Map.unmodifiable(nextDelivery);
    stopRequested = Set.unmodifiable(nextStops);
  }

  static ChatDelivery _deliveryFor(String? replyStatus) =>
      const {'complete', 'interrupted', 'error'}.contains(replyStatus)
      ? ChatDelivery.complete
      : ChatDelivery.waitingAi;

  @override
  ChatHistory get history => ChatHistory(
    hasOlder: _oldest != null,
    hasNewer: _newest != null,
    loadingOlder: _loadingOlder,
    loadingNewer: _loadingNewer,
    oldestId: _oldest?.id,
    precedingCreatedAt: _precedingCreatedAt,
    paged: UnmodifiableSetView(_paged),
  );

  @override
  Future<Result<void>> loadOlder() => _page(older: true);

  @override
  Future<Result<void>> loadNewer() => _page(older: false);

  Future<Result<void>> _page({required bool older}) async {
    if (_closed ||
        (older
            ? _oldest == null || _loadingOlder
            : _newest == null || _loadingNewer)) {
      return const Ok(null);
    }
    if (older) {
      _loadingOlder = true;
    } else {
      _loadingNewer = true;
    }
    _notify();
    try {
      return await _serial<Result<void>>(() async {
        if (_closed || !await dao.accepts(fence)) {
          return const Failure<void>('stale_response');
        }
        final bound = older ? _oldest : _newest;
        if (bound == null) {
          return const Ok(null);
        }
        final queue = await dao.outbox(spaceId);
        final page = await dao.chatPage(
          spaceId,
          memberId,
          limit: pageSize + 1,
          before: older ? bound : null,
          after: older ? null : bound,
        );
        final (next, preceding) = _trim(page, older: older, limit: pageSize);
        final states = await dao.chatClientStates(spaceId, page.map(_idOf));
        if (!await _apply(page, states, paged: true)) {
          unawaited(_reopen());
          return const Ok(null);
        }
        // Old messages coming into view are history: their receipts and
        // reply links were handled when they happened.
        await _settle(queue, history: page.map(_idOf).toSet());
        // Only now: a failed page is fetched again from the same bound.
        if (older) {
          _oldest = next;
          _precedingCreatedAt = preceding;
        } else {
          _newest = next;
        }
        return const Ok(null);
      });
    } on Object {
      _log('local_read_failed');
      return const Failure('local_read_failed');
    } finally {
      if (older) {
        _loadingOlder = false;
      } else {
        _loadingNewer = false;
      }
      _notify();
    }
  }

  /// Starts over on a fresh store with the latest page.
  Future<void> _reopen() => _serial(() async {
    await _reset(conversationId);
    await _read(full: true);
  });

  /// Reopens the window around [messageId] (for a deep link; the list has no
  /// jump of its own yet). The list then pages newer messages back in as it
  /// scrolls down, and a send returns to the latest page first.
  Future<Result<void>> jumpTo(String messageId) async {
    try {
      return await _serial<Result<void>>(() async {
        if (_closed || !await dao.accepts(fence)) {
          return const Failure<void>('stale_response');
        }
        final target = await dao.chatEntry(spaceId, messageId);
        if (target == null || target['member_id'] != memberId) {
          return const Failure<void>('chat_message_missing');
        }
        await _reset(conversationId);
        final watermark = await dao.chatRevision();
        final queue = await dao.outbox(spaceId);
        final at = chatCursorOf(target);
        final older = pageSize ~/ 2;
        final before = await dao.chatPage(
          spaceId,
          memberId,
          limit: older + 1,
          before: at,
        );
        final (oldest, preceding) = _trim(before, older: true, limit: older);
        final after = await dao.chatPage(
          spaceId,
          memberId,
          limit: pageSize - older,
          after: at,
        );
        final (newest, _) = _trim(
          after,
          older: false,
          limit: pageSize - older - 1,
        );
        final rows = await _withInFlight([...before, target, ...after]);
        final states = await dao.chatClientStates(spaceId, rows.map(_idOf));
        _oldest = oldest;
        _precedingCreatedAt = preceding;
        _newest = newest;
        if (!await _apply(rows, states, paged: false)) {
          // Same as a read: start over on the latest page, watermark kept.
          unawaited(_reopen());
          return const Failure<void>('stale_response');
        }
        await _settle(queue);
        _watermark = watermark;
        _notify();
        return const Ok(null);
      });
    } on Object {
      _log('local_read_failed');
      // The store was already reset: start over on the latest page.
      unawaited(_reopen());
      return const Failure('local_read_failed');
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
  Future<Result<void>> send(
    String text,
    List<String> images, {
    List<ChatFile> files = const [],
  }) => _guard(() async {
    if ((await dao.runtime())['write_allowed'] != 1) {
      throw const ApiError('client_too_old');
    }
    if (composer.state.mode != ComposerMode.free) {
      throw const ApiError('chat_answer_first');
    }
    if (text.trim().isEmpty && images.isEmpty && files.isEmpty) {
      throw const ApiError('chat_empty');
    }
    if (utf8.encode(text).length > 32000 || images.length > 8) {
      throw const ApiError('chat_too_large');
    }
    if (files.length > ChatFileLimits.maxFiles ||
        files.map((file) => file.sha256).toSet().length != files.length) {
      throw const ApiError('chat_files_too_many');
    }
    if (files.fold<int>(0, (sum, file) => sum + file.bytes) >
        ChatFileLimits.maxCombinedBytes) {
      throw const ApiError('chat_files_too_large');
    }
    if (_newest != null) {
      // A jumped window would not show the new message: go back to the latest.
      await _reopen();
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
          'input': {
            'text': text,
            'images': images,
            if (files.isNotEmpty)
              'files': [
                for (final file in files)
                  {
                    'sha256': file.sha256,
                    'name': file.name,
                    'mime': ChatFileLimits.mime,
                    'bytes': file.bytes,
                  },
              ],
          },
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
            if (files.isNotEmpty)
              'files': [
                for (final file in files)
                  {'sha256': file.sha256, 'name': file.name},
              ],
            chatCapabilitiesEnvelopeKey: chatCapabilitiesHeader(caps),
          },
          entityIds: {'chat_entry:$id'},
          // The message waits for its photos and PDFs to be uploaded.
          dependsOn: {
            for (final hash in images) EntityRef.blob('chat', hash),
            for (final file in files)
              EntityRef.blob(chatFileModule, file.sha256),
          },
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
  Future<Result<ChatAttachments>> documents({
    List<String> images = const [],
    List<ChatFile> files = const [],
  }) => media.pickDocuments(spaceId, images: images, files: files);
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
              (await dao.chatReplies(spaceId, memberId, [
                    userMessageId,
                  ], const [])).lastOrNull?['id']
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
