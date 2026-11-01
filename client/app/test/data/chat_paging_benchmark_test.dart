@Tags(['benchmark'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chat_session.dart';

import '../support/chat_harness.dart';

/// Opening cost of the chat against the size of the local history (#70).
/// Skipped in CI; run with:
/// flutter test --run-skipped --tags benchmark test/data/chat_paging_benchmark_test.dart
void main() {
  for (final count in [50, 500, 5000]) {
    test('chat_open_with_${count}_messages', () async {
      final h = await ChatHarness.create();
      addTearDown(h.close);
      await h.session.dispose();
      await seedTimeline(h, count);
      final opens = <int>[];
      final pages = <int>[];
      for (var run = 0; run < 3; run++) {
        final session = LocalChatSession(
          dao: h.h.store,
          api: h.api,
          fence: (await h.h.store.fence('s'))!,
          memberId: 'm',
          caps: h.session.caps,
          sync: () async {},
          media: h.session.media,
        );
        final watch = Stopwatch()..start();
        await session.initialize();
        opens.add(watch.elapsedMilliseconds);
        await session.recover();
        watch // page
          ..reset() // page
          ..start(); // page
        await session.loadOlder(); // page
        pages.add(watch.elapsedMilliseconds); // page
        expect(session.blocks.snapshot.messages, isNotEmpty);
        await session.dispose();
      }
      opens.sort();
      pages.sort();
      stdout.writeln(
        'chat_benchmark messages=$count initialize_ms=${opens[1]} '
        'load_older_ms=${pages.elementAtOrNull(1)} runs=$opens/$pages',
      );
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
