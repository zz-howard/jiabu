import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/features/chat/view/chat_screen.dart';

import '../support/c3_harness.dart';
import '../support/chat_harness.dart';
import '../support/ledger_fake.dart';

void main() {
  late ChatHarness h;
  late LocalChatSession session;
  late FakeLedgerRepository ledger;

  setUp(() async {
    h = await ChatHarness.create();
    await h.session.dispose();
    await seedTimeline(
      h,
      30,
      message: (i) => timelineMessage(
        i,
        text: '消息 $i：${'今天买菜和水果一共花了六十八块，记在信用卡日常餐饮里。' * 3}',
      ),
    );
    session = await h.open(pageSize: 10);
    ledger = FakeLedgerRepository(c3Snapshot('card_recorded'));
  });
  tearDown(() async {
    await session.dispose();
    await ledger.changes.close();
    await h.close();
  });

  Finder message(int i) => find.byKey(ValueKey(timelineId(i)));

  testWidgets('scrolling_up_loads_the_older_page_in_place', (tester) async {
    await pumpC3(
      tester,
      repository: ledger,
      settle: false,
      overrides: [
        chatRepositoryProvider.overrideWithValue(FixedChatRepository(session)),
        currentLedgerSpaceProvider.overrideWith(
          (ref) => Stream.value('fictional-c3'),
        ),
      ],
      child: const ChatScreen(),
    );
    await pumpUntil(
      tester,
      () => message(29).evaluate().isNotEmpty,
      description: 'latest page shows',
    );
    expect(session.history.hasOlder, isTrue);
    expect(find.byKey(const Key('chat-history-loading')), findsNothing);

    // Hold the database so the page load stays in flight.
    final gate = Completer<void>();
    late Future<void> held;
    await tester.runAsync(() async {
      held = h.h.store.transaction(() => gate.future);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    final list = find.descendant(
      of: find.byType(ChatWeaveList),
      matching: find.byType(CustomScrollView),
    );
    for (var i = 0; i < 30 && !session.history.loadingOlder; i++) {
      await tester.drag(list, const Offset(0, 200));
      await tester.pump();
    }
    expect(session.history.loadingOlder, isTrue);
    await tester.pump();
    expect(find.byKey(const Key('chat-history-loading')), findsOneWidget);
    // The window's oldest message continues the day before the window (all
    // on one day): no date tape at the page boundary.
    expect(find.byKey(const Key('chat-day-tape')), findsNothing);
    final anchor = [for (var i = 20; i < 30; i++) i]
        .firstWhere((i) => message(i).evaluate().isNotEmpty);
    final before = tester.getTopLeft(message(anchor)).dy;

    gate.complete();
    await tester.runAsync(() => held);
    await pumpUntil(
      tester,
      () =>
          !session.history.loadingOlder &&
          session.blocks.snapshot.messages.containsKey(timelineId(10)),
      description: 'older page loads',
    );
    await tester.pump();
    expect(find.byKey(const Key('chat-history-loading')), findsNothing);
    expect(tester.getTopLeft(message(anchor)).dy, moreOrLessEquals(before));
    expect(session.history.paged, contains(timelineId(10)));
    // History is not new content: no "N new" pill.
    expect(find.textContaining('条新内容'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
