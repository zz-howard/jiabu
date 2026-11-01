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

/// Message [i] with a conversation id of the wrong type: applying it throws,
/// standing in for any failure in the middle of a read.
Map<String, Object?> brokenRow(int i) => {
  ...timelineRow(
    Message.fromJson({...timelineMessage(i).json, 'conversationId': 7}),
  ),
  'conversation_id': 'conversation',
};

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

  group('session window failures and history', () {
    test('a_failed_change_read_is_read_again_in_full', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      await h.h.store.transaction(() async {
        await h.h.store.putChatEntry('s', brokenRow(10), authoritative: true);
        await h.h.store.putChatEntry(
          's',
          timelineRow(timelineMessage(11)),
          authoritative: true,
        );
      });
      await until(() => session.error == 'local_read_failed', 'read fails');
      expect(session.blocks.snapshot.messages[timelineId(11)], isNull);
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(10, rev: 2)),
        authoritative: true,
      );
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(11)),
        'the row written with the failed one arrives',
      );
      expect(loaded(session), range(6, 12));
    });

    test('a_failed_page_keeps_its_bound_and_loads_whole_later', () async {
      await seedTimeline(h, 10);
      await h.h.store.putChatEntry('s', brokenRow(3), authoritative: true);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(await session.loadOlder(), isA<Failure<void>>());
      expect(session.history.oldestId, timelineId(6));
      expect(session.blocks.snapshot.messages[timelineId(4)], isNull);
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(3, rev: 2)),
        authoritative: true,
      );
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(2, 10));
      expect(session.history.oldestId, timelineId(2));
    });

    test('first_sync_into_an_empty_chat_keeps_one_page', () async {
      final session = await h.open();
      addTearDown(session.dispose);
      expect(session.blocks.snapshot.messages, isEmpty);
      await seedTimeline(h, 500);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(499)),
        'latest message arrives',
      );
      expect(loaded(session), range(460, 500));
      expect(session.history.hasOlder, isTrue);
      expect(
        session.history.precedingCreatedAt,
        timelineMessage(459)['createdAt'],
      );
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(420, 500));
    });

    test('offline_catch_up_past_a_page_keeps_the_window_capped', () async {
      // The window starts at the first message and reaches the latest; then
      // more than a page arrives in one sync.
      await seedTimeline(h, 10);
      final session = await h.open();
      addTearDown(session.dispose);
      expect(loaded(session), range(0, 10));
      expect(session.history.hasOlder, isFalse);
      await seedTimeline(h, 55, from: 10);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(54)),
        'latest message arrives',
      );
      expect(loaded(session), range(15, 55));
      expect(session.history.hasOlder, isTrue);
      expect(session.history.hasNewer, isFalse);
      expect(session.history.oldestId, timelineId(15));
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(loaded(session), range(0, 55));
    });

    test('a_catch_up_within_a_page_extends_the_window', () async {
      await seedTimeline(h, 10);
      final session = await h.open();
      addTearDown(session.dispose);
      await seedTimeline(h, 50, from: 10);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(49)),
        'latest message arrives',
      );
      expect(loaded(session), range(0, 50));
      expect(session.history.hasOlder, isFalse);
    });

    test('paging_back_to_the_start_keeps_the_window_on_new_messages', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      for (var page = 0; page < 3; page++) {
        expect(await session.loadOlder(), isA<Ok<void>>());
      }
      expect(loaded(session), range(0, 10));
      expect(session.history.hasOlder, isFalse);
      await seedTimeline(h, 12, from: 10);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(11)),
        'new messages arrive',
      );
      expect(loaded(session), range(0, 12));
      expect(session.history.paged, isNotEmpty);
    });

    test(
      'large_sync_past_a_short_history_reopens_on_the_latest_page',
      () async {
        await seedTimeline(h, 3);
        final session = await h.open(pageSize: 4);
        addTearDown(session.dispose);
        expect(loaded(session), range(0, 3));
        await seedTimeline(h, 50, from: 3);
        await until(
          () => session.blocks.snapshot.messages.containsKey(timelineId(49)),
          'latest message arrives',
        );
        expect(loaded(session), range(46, 50));
        expect(session.history.oldestId, timelineId(46));
      },
    );

    test('paged_in_receipts_and_reply_links_act_at_most_once', () async {
      // The ids are replies that exist only on the server, so a resume opens
      // a stream for them (a local finished reply would not).
      final online = await ChatHarness.create(offline: false);
      addTearDown(online.close);
      await online.session.dispose();
      await seedTimeline(online, 10);
      await online.h.store.updateChatClientState(
        's',
        timelineId(2),
        (_) => {
          'assistantId': 'remote-reply',
          'action_refresh': true,
          'receipts': {
            'receipt-1': {
              'resume': {'messageId': 'remote-resume-1'},
            },
          },
        },
      );
      var syncs = 0;
      final session = await online.open(
        pageSize: 4,
        sync: () async {
          syncs++;
        },
      );
      addTearDown(session.dispose);
      await session.recover();
      Iterable<String> opened() => online.api.opens.map((open) => open.message);
      final before = syncs;
      expect(await session.loadOlder(), isA<Ok<void>>());
      expect(session.blocks.snapshot.messages, contains(timelineId(2)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(opened(), isNot(contains('remote-resume-1')));
      expect(opened(), isNot(contains('remote-reply')));
      // No retry and no action refresh for the settled receipt.
      expect(syncs, before);
      // A receipt that arrives now is new: it acts.
      await online.h.store.updateChatClientState(
        's',
        timelineId(2),
        (state) => {
          ...state,
          'receipts': {
            ...state['receipts']! as Map<String, Object?>,
            'receipt-2': {
              'resume': {'messageId': 'remote-resume-2'},
            },
          },
        },
      );
      await until(
        () => opened().contains('remote-resume-2'),
        'new receipt resumes',
      );
      await until(() => syncs > before, 'new receipt refreshes');
      expect(await session.loadOlder(), isA<Ok<void>>());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(opened(), isNot(contains('remote-resume-1')));
      expect(opened(), isNot(contains('remote-reply')));
    });

    test('receipts_and_reply_links_do_not_fire_again_after_a_reset', () async {
      // Message 3 is a paused reply, so every reopen keeps it loaded and
      // settles it again. Its receipt resumes a server-only message.
      final online = await ChatHarness.create(offline: false);
      addTearDown(online.close);
      await online.session.dispose();
      await seedTimeline(
        online,
        10,
        message: (i) => i == 3
            ? Message.fromJson({
                ...c5Message('paused').json,
                'id': timelineId(3),
                'conversationId': 'conversation',
                'createdAt': timelineMessage(3)['createdAt'],
                'rev': 0,
              })
            : timelineMessage(i),
      );
      await online.h.store.updateChatClientState(
        's',
        timelineId(3),
        (_) => {
          'assistantId': 'remote-reply',
          'action_refresh': true,
          'receipts': {
            'receipt-1': {
              'resume': {'messageId': 'remote-resume-1'},
            },
          },
        },
      );
      final session = await online.open(pageSize: 4);
      addTearDown(session.dispose);
      await session.recover();
      // Resume diagnostics live in the block store, which a reset replaces:
      // after one, any id listed was resumed again.
      Set<String> resumed() =>
          ((session.blocks.inspect()['diagnostics']!
                          as Map<String, Object?>)['resume']
                      as Map<String, Object?>? ??
                  const {})
              .keys
              .toSet();
      await until(
        () => resumed().containsAll(['remote-resume-1', 'remote-reply']),
        'receipt and reply link act once',
      );
      Future<void> expectQuiet(String after) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          session.blocks.snapshot.messages,
          contains(timelineId(3)),
          reason: after,
        );
        expect(
          resumed(),
          isNot(anyOf(contains('remote-resume-1'), contains('remote-reply'))),
          reason: after,
        );
      }

      String? text() =>
          session.blocks.snapshot.messages[timelineId(9)]?['fallbackText']
              as String?;
      await online.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(9, text: '第三版', rev: 3)),
        authoritative: true,
      );
      await until(() => text() == '第三版', 'rev 3 applies');
      await online.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(9, text: '第二版', rev: 2)),
        authoritative: true,
      );
      await until(() => text() == '第二版', 'lower rev reopens');
      await expectQuiet('lower revision reopen');

      await seedTimeline(online, 20, from: 10);
      await until(
        () => session.blocks.snapshot.messages.containsKey(timelineId(19)),
        'catch-up reopens',
      );
      expect(loaded(session), [timelineId(3), ...range(16, 20)]);
      await expectQuiet('catch-up reopen');

      expect(await session.jumpTo(timelineId(5)), isA<Ok<void>>());
      await expectQuiet('jump');

      // A receipt that arrives now is new and still acts.
      await online.h.store.updateChatClientState(
        's',
        timelineId(3),
        (state) => {
          ...state,
          'receipts': {
            ...state['receipts']! as Map<String, Object?>,
            'receipt-2': {
              'resume': {'messageId': 'remote-resume-2'},
            },
          },
        },
      );
      await until(
        () => resumed().contains('remote-resume-2'),
        'new receipt resumes',
      );
      expect(resumed(), isNot(contains('remote-resume-1')));
    });

    test('authoritative_lower_rev_after_paging_reopens_the_window', () async {
      await seedTimeline(h, 10);
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      await session.loadOlder();
      expect(loaded(session), range(2, 10));
      String? text() =>
          session.blocks.snapshot.messages[timelineId(9)]?['fallbackText']
              as String?;
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(9, text: '第三版', rev: 3)),
        authoritative: true,
      );
      await until(() => text() == '第三版', 'rev 3 applies');
      await h.h.store.putChatEntry(
        's',
        timelineRow(timelineMessage(9, text: '第二版', rev: 2)),
        authoritative: true,
      );
      await until(() => text() == '第二版', 'lower authoritative rev wins');
      expect(loaded(session), range(6, 10));
      expect(session.history.paged, isEmpty);
      expect(session.history.oldestId, timelineId(6));
    });

    test('conversation_row_after_paging_reopens_the_window', () async {
      for (var i = 0; i < 10; i++) {
        await h.h.store.putChatEntry(
          's',
          timelineRow(timelineMessage(i, conversation: 'local:m')),
          authoritative: false,
          state: 'pending',
        );
      }
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(session.conversationId, 'local:m');
      await session.loadOlder();
      expect(loaded(session), range(2, 10));
      await h.h.store.putEntity('s', 'conversation', {
        'id': 'conversation',
        'member_id': 'm',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      await until(
        () => session.conversationId == 'conversation',
        'conversation arrives',
      );
      await until(() => loaded(session).length == 4, 'window reopens');
      expect(loaded(session), range(6, 10));
      expect(session.history.paged, isEmpty);
      expect(
        session.blocks.snapshot.messages.values.map(
          (message) => message['conversationId'],
        ),
        everyElement('conversation'),
      );
    });

    test('saved_intents_restore_on_a_paged_in_message', () async {
      await seedTimeline(h, 10);
      await h.h.store.updateChatClientState(
        's',
        timelineId(3),
        (_) => {
          'intents': {'question': h.action('intent-1').json},
        },
      );
      final session = await h.open(pageSize: 4);
      addTearDown(session.dispose);
      expect(
        session.interactions.stateFor(timelineId(3), 'question').request,
        isNull,
      );
      await session.loadOlder();
      await until(
        () =>
            session.interactions
                .stateFor(timelineId(3), 'question')
                .request?['id'] ==
            'intent-1',
        'intent restored',
      );
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
