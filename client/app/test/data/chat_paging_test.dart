import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/shared/chatweave/chat_day_tape.dart';

import '../support/chat_harness.dart';

List<String> ids(List<Map<String, Object?>> rows) => [
  for (final row in rows) row['id']! as String,
];

List<String> loaded(LocalChatSession session) =>
    session.blocks.snapshot.messages.keys.toList()..sort();

List<String> range(int from, int to) => [
  for (var i = from; i < to; i++) timelineId(i),
];

/// Reply 1 of the timeline asking a question (an interrupt), as the catalog
/// draws it.
Message pausedReply({required String status, required int seq}) =>
    Message.fromJson({
      ...c5Message('paused').json,
      'id': timelineId(1),
      'conversationId': 'conversation',
      'createdAt': timelineMessage(1)['createdAt'],
      'status': status,
      'rev': 0,
      'lastSeq': seq,
    });

Future<void> until(bool Function() condition, String description) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Not reached: $description');
}

void main() {
  late ChatHarness h;
  setUp(() async {
    h = await ChatHarness.create();
    await h.session.dispose();
  });
  tearDown(() async {
    await h.close();
  });

  group('dao pages', () {
    test('page_orders_created_at_ties_by_id_and_honours_limits', () async {
      const at = '2026-01-01T00:00:00.000Z';
      await seedTimeline(
        h,
        6,
        message: (i) => timelineMessage(i, createdAt: i < 4 ? at : null),
      );
      final store = h.h.store;
      expect(ids(await store.chatPage('s', 'm', limit: 3)), range(3, 6));
      expect(ids(await store.chatPage('s', 'm', limit: 50)), range(0, 6));
      final tie = (createdAt: at, id: timelineId(2));
      expect(
        ids(await store.chatPage('s', 'm', limit: 10, before: tie)),
        range(0, 2),
      );
      expect(
        ids(await store.chatPage('s', 'm', limit: 2, after: tie)),
        range(3, 5),
      );
      expect(ids(await store.chatPage('s', 'm', limit: 1, before: tie)), [
        timelineId(1),
      ]);
    });

    test('page_and_changes_stay_inside_member_and_space', () async {
      await seedTimeline(h, 3);
      final store = h.h.store;
      final watermark = await store.chatRevision();
      await store.putChatEntry(
        's',
        timelineRow(timelineMessage(10, text: '用户B'), member: 'other'),
        authoritative: true,
      );
      await store.putChatEntry(
        't',
        timelineRow(timelineMessage(11, text: '用户C')),
        authoritative: true,
      );
      await store.updateChatClientState('t', timelineId(0), (_) => {'a': 1});
      expect(ids(await store.chatPage('s', 'm', limit: 50)), range(0, 3));
      expect(await store.chatEntriesChangedSince('s', 'm', watermark), isEmpty);
      expect(await store.chatClientStatesChangedSince('s', watermark), isEmpty);
      expect(ids(await store.chatPage('s', 'other', limit: 50)), [
        timelineId(10),
      ]);
      expect(
        await store.chatReplies('s', 'other', [timelineId(0)], const []),
        isEmpty,
      );
    });

    test('changes_since_watermark_read_only_rewritten_rows', () async {
      await seedTimeline(h, 5);
      final store = h.h.store;
      final watermark = await store.chatRevision();
      await store.putChatEntry(
        's',
        timelineRow(timelineMessage(3, text: '改过', rev: 2)),
        authoritative: true,
      );
      await store.updateChatClientState(
        's',
        timelineId(1),
        (_) => {'stopRequested': true},
      );
      expect(ids(await store.chatEntriesChangedSince('s', 'm', watermark)), [
        timelineId(3),
      ]);
      expect((await store.chatClientStatesChangedSince('s', watermark)).keys, [
        timelineId(1),
      ]);
      expect(
        await store.chatEntriesChangedSince(
          's',
          'm',
          await store.chatRevision(),
        ),
        isEmpty,
      );
    });

    test('client_states_and_replies_are_batched_lookups', () async {
      await seedTimeline(h, 6);
      final store = h.h.store;
      for (final i in [0, 2]) {
        await store.updateChatClientState('s', timelineId(i), (_) => {'n': i});
      }
      final states = await store.chatClientStates('s', range(0, 6));
      expect(states.keys.toSet(), {timelineId(0), timelineId(2)});
      expect(states[timelineId(2)], {'n': 2});
      final replies = await store.chatReplies(
        's',
        'm',
        [timelineId(0), timelineId(4)],
        [timelineId(3)],
      );
      expect(ids(replies), [timelineId(1), timelineId(3), timelineId(5)]);
      expect(replies.first['stream_status'], 'complete');
    });
  });

  group('session window', () {
    test('opens_on_the_latest_page_and_pages_older_to_the_start', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(loaded(session), range(6, 10));
      var history = session.history;
      expect(history.hasOlder, isTrue);
      expect(history.hasNewer, isFalse);
      expect(history.oldestId, timelineId(6));
      expect(history.precedingCreatedAt, timelineMessage(5)['createdAt']);
      expect(history.paged, isEmpty);

      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(2, 10));
      expect(session.history.paged, range(2, 6).toSet());
      expect(await session.loadOlder(), isA<Ok<void>>());
      history = session.history;
      expect(loaded(session), range(0, 10));
      expect(history.hasOlder, isFalse);
      expect(history.oldestId, isNull);
      expect(history.precedingCreatedAt, isNull);
      // Nothing more: a no-op.
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(0, 10));
    });

    test('a_short_history_opens_whole', () async {
      await seedTimeline(h, 3);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(loaded(session), range(0, 3));
      expect(session.history.hasOlder, isFalse);
    });

    test('jump_then_load_newer_back_to_the_latest', () async {
      await seedTimeline(h, 20);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(await session.jumpTo(timelineId(9)), isA<Ok<void>>());
      expect(loaded(session), range(7, 11));
      expect(session.history.hasNewer, isTrue);
      expect(session.history.hasOlder, isTrue);
      // The reply to the window's newest message lies beyond the window.
      expect(session.delivery[timelineId(10)], ChatDelivery.complete);
      for (var i = 0; i < 5 && session.history.hasNewer; i++) {
        expect(await session.loadNewer(), isA<Ok<void>>());
      }
      expect(loaded(session), range(7, 20));
      expect(session.history.hasNewer, isFalse);
      expect(session.history.paged, range(11, 20).toSet());
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(3, 20));
    });

    test('send_after_a_jump_returns_to_the_latest_page', () async {
      await seedTimeline(h, 20);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      await session.jumpTo(timelineId(4));
      expect(await session.send('午饭 68', const []), isA<Ok<void>>());
      await until(
        () => session.blocks.snapshot.messages.length == 5,
        'latest page plus the new message',
      );
      expect(session.history.hasNewer, isFalse);
      expect(session.blocks.snapshot.messages.keys, containsAll(range(16, 20)));
    });

    test('live_changes_apply_inside_and_newer_than_the_window', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(7, text: '改过', rev: 2)),
        authoritative: true,
      );
      await seedTimeline(h, 11, from: 10);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(10)),
        'newer message arrives',
      );
      await until(
        () =>
            session.blocks.snapshot.messages[timelineId(7)]?['fallbackText'] ==
            '改过',
        'window message updates',
      );
      expect(session.history.paged, isEmpty);
      expect(session.delivery[timelineId(10)], ChatDelivery.waitingAi);
      await seedTimeline(h, 12, from: 11);
      await until(
        () => session.delivery[timelineId(10)] == ChatDelivery.complete,
        'reply completes the new message',
      );
    });

    test('changes_older_than_the_window_wait_for_their_page', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(1, text: '改过', rev: 2)),
        authoritative: true,
      );
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(9, text: '也改过', rev: 2)),
        authoritative: true,
      );
      await until(
        () =>
            session.blocks.snapshot.messages[timelineId(9)]?['fallbackText'] ==
            '也改过',
        'window message updates',
      );
      expect(session.blocks.snapshot.messages[timelineId(1)], isNull);
      await session.loadOlder();
      await session.loadOlder();
      expect(
        session.blocks.snapshot.messages[timelineId(1)]?['fallbackText'],
        '改过',
      );
    });

    test(
      'paused_reply_outside_the_first_window_is_loaded_and_resumed',
      () async {
        final online = await ChatHarness.create(offline: false);
        addTearDown(online.close);
        await online.session.dispose();
        await seedTimeline(
          online,
          12,
          message: (i) => i == 1
              ? pausedReply(status: 'paused', seq: 4)
              : timelineMessage(i),
        );
        final session = await online.open(pageSize: 4);
        addTearDown(session.dispose);
        expect(loaded(session), [timelineId(1), ...range(8, 12)]);
        expect(
          session.blocks.snapshot.messages[timelineId(1)]?.status,
          'paused',
        );
        expect(session.history.oldestId, timelineId(8));
        // The answer arrives elsewhere: the checkpoint leaves paused, and the
        // session resumes the stream although the reply is not in the window.
        await online.h.store.putChatEntry(
          's',
          timelineRow(pausedReply(status: 'streaming', seq: 6)),
          authoritative: false,
        );
        await until(
          () => online.api.opens.any((open) => open.message == timelineId(1)),
          'stream resumes',
        );
      },
    );

    test('stop_request_outside_the_page_survives_reopen', () async {
      await seedTimeline(
        h,
        12,
        message: (i) => i == 3
            ? timelineMessage(3, status: 'streaming', rev: 0, seq: 2)
            : timelineMessage(i),
      );
      await h.h.store.updateChatClientState(
        's',
        timelineId(3),
        (_) => {'stopRequested': true},
      );
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(session.stopRequested, {timelineId(3)});
    });

    test(
      'conversation_is_inferred_from_a_synced_row_outside_the_window',
      () async {
        for (var i = 0; i < 8; i++) {
          await h.h.store.putChatEntry(
            's',
            timelineRow(
              timelineMessage(
                i,
                conversation: i == 0 ? 'conversation' : 'local:m',
              ),
            ),
            authoritative: i == 0,
            state: i == 0 ? 'synced' : 'pending',
          );
        }
        final session = await h.open(pageSize: 4);
        addTearDown(session.dispose);
        expect(session.conversationId, 'conversation');
        expect(loaded(session), range(4, 8));
        expect(
          session.blocks.snapshot.messages.values.map(
            (message) => message['conversationId'],
          ),
          everyElement('conversation'),
        );
      },
    );

    test('pending_send_is_pending_and_failed_dependency_fails', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(await session.send('午饭 68', const []), isA<Ok<void>>());
      final id = (await h.h.store.outbox('s')).single.id;
      await until(
        () => session.delivery[id] == ChatDelivery.pending,
        'pending delivery',
      );
      await h.h.store.setOutboxState('s', id, 'failed');
      await until(
        () => session.delivery[id] == ChatDelivery.failed,
        'failed delivery',
      );
      expect(session.delivery[timelineId(8)], ChatDelivery.complete);
    });
  });

  group('day tapes at a page boundary', () {
    Message at(String id, String createdAt) => Message.fromJson({
      ...timelineMessage(0).json,
      'id': id,
      'createdAt': createdAt,
    });
    final messages = [
      at('a', '2026-01-02T08:00:00Z'),
      at('b', '2026-01-02T09:00:00Z'),
      at('c', '2026-01-03T09:00:00Z'),
    ];

    test('oldest_message_continues_the_day_before_the_window', () {
      expect(
        ChatDayBreaks.dayStarts(
          messages,
          'conversation',
          continuedId: 'a',
          continuesFrom: '2026-01-02T07:00:00Z',
        ).keys,
        ['c'],
      );
    });

    test('oldest_message_opens_a_new_day_after_the_window', () {
      expect(
        ChatDayBreaks.dayStarts(
          messages,
          'conversation',
          continuedId: 'a',
          continuesFrom: '2026-01-01T07:00:00Z',
        ).keys,
        ['a', 'c'],
      );
    });
  });

  test('cursor_order_breaks_created_at_ties_by_id', () {
    ChatCursor c(String at, String id) => (createdAt: at, id: id);
    expect(compareChatCursors(c('1', 'b'), c('1', 'a')), greaterThan(0));
    expect(compareChatCursors(c('1', 'b'), c('2', 'a')), lessThan(0));
  });
}
