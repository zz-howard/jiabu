import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chatweave_store.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';

import '../support/chat_harness.dart';

void main() {
  late ChatHarness h;
  setUp(() async {
    h = await ChatHarness.create();
  });
  tearDown(() async {
    await h.close();
  });
  test('synced_persisted_revision_replaces_local', () async {
    await h.h.store.putChatEntry(
      's',
      chatRow(chatMessage(rev: 7, text: 'local')),
      authoritative: false,
    );
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(chatMessage(rev: 1, text: 'server')),
    );
    expect((await h.persistence.load('reply'))!['fallbackText'], 'server');
  });
  test('older_checkpoint_cannot_regress_stream', () async {
    await h.h.store.putChatEntry(
      's',
      chatRow(chatMessage(seq: 20)),
      authoritative: false,
    );
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(chatMessage(seq: 19, text: 'old')),
    );
    expect(await h.persistence.lastSeq('reply'), 20);
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(chatMessage(seq: 20, text: 'equal')),
    );
    expect((await h.persistence.load('reply'))!['fallbackText'], 'equal');
  });
  test('delayed_provisional_cannot_replace_synced_final', () async {
    await h.persistence.saveProvisional(
      chatMessage(seq: 30, text: 'temporary'),
      lastSeq: 30,
    );
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(
        chatMessage(rev: 1, seq: 10, text: 'authoritative', status: 'complete'),
      ),
    );
    await h.persistence.flush();
    expect(
      (await h.persistence.load('reply'))!['fallbackText'],
      'authoritative',
    );
    expect(await h.persistence.lastSeq('reply'), 10);
  });
  test('checkpoint_cannot_replace_final_and_steps_roundtrip', () async {
    final message = c5Message('process_collapsed');
    await h.h.store.putEntity('s', 'chat_entry', chatRow(message));
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(chatMessage(seq: 999)),
    );
    expect((await h.persistence.load('reply'))!.json, message.json);
  });
  test('store_filters_member_and_space_and_purge_clears_intents', () async {
    await h.h.store.putEntity('s', 'chat_entry', chatRow(chatMessage()));
    await h.h.store.putEntity(
      'other-space',
      'chat_entry',
      chatRow(chatMessage(text: '用户B')),
    );
    await h.h.store.putEntity(
      's',
      'chat_entry',
      chatRow(chatMessage(id: 'other-member'), member: 'other-member'),
    );
    expect(await h.persistence.load('other-member'), isNull);
    final rows = await h.persistence.watchConversation('conversation').first;
    expect(rows.map((message) => message.id), ['reply']);
    await h.h.store.updateChatClientState(
      's',
      'reply',
      (_) => {'stopRequested': true},
    );
    await h.h.store.purgeSpace('s');
    expect(await h.h.store.chatClientState('s', 'reply'), isEmpty);
    expect(
      JiabuChatWeaveStore.decode(
        (await h.h.store.chatEntry('other-space', 'reply'))!,
      )!['fallbackText'],
      '用户B',
    );
  });
}
