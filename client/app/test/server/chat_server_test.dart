@Tags(['server'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/data/db/database.dart' hide Tags;
import 'package:jiabu/data/repositories/ledger_repository.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/chat/blocks/record_card_block.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';

import '../fixtures/jpeg_fixture.dart';
import '../support/c3_harness.dart';
import '../support/sync_harness.dart';
import 'local_sync_server_test.dart'
    show
        JpegCodecStub,
        RecordedRealApi,
        ServerFixture,
        UnusedPickerStub,
        env,
        uuid;

class _ObservedChat implements ChatApi {
  _ObservedChat(this.real);
  final ChatApi real;
  bool offline = false;
  bool loseNextSend = false;
  Future<void> Function(String, Map<String, Object?>)? beforeWrite;
  final writes = <({String endpoint, String id})>[];
  final opens = <({String message, int? after})>[];
  @override
  Future<Map<String, Object?>> chatWrite({
    required String spaceId,
    required String endpoint,
    required Map<String, Object?> payload,
    required int joinEpoch,
    required String opId,
    required String requestId,
  }) async {
    if (offline) {
      throw const ApiError('network');
    }
    await beforeWrite?.call(endpoint, payload);
    writes.add((endpoint: endpoint, id: opId));
    final result = await real.chatWrite(
      spaceId: spaceId,
      endpoint: endpoint,
      payload: payload,
      joinEpoch: joinEpoch,
      opId: opId,
      requestId: requestId,
    );
    if (loseNextSend && endpoint == 'messages') {
      loseNextSend = false;
      throw const ApiError('network');
    }
    return result;
  }

  @override
  Future<List<ActiveMessage>> chatActive(String spaceId) async {
    if (offline) {
      throw const ApiError('network');
    }
    return await real.chatActive(spaceId);
  }

  @override
  Future<StreamConnection> chatStream(
    String spaceId,
    String messageId, {
    required String capabilities,
    int? afterSeq,
    CancelToken? cancelToken,
  }) async {
    if (offline) {
      throw const ApiError('network');
    }
    opens.add((message: messageId, after: afterSeq));
    return await real.chatStream(
      spaceId,
      messageId,
      capabilities: capabilities,
      afterSeq: afterSeq,
      cancelToken: cancelToken,
    );
  }
}

class _Device {
  _Device(
    this.fixture,
    this.h,
    this.api,
    this.media,
    this.engine,
    this.session,
  );
  final ServerFixture fixture;
  final SyncHarness h;
  final _ObservedChat api;
  final MediaService media;
  final SyncEngine engine;
  final LocalChatSession session;
  LocalLedgerRepository get ledger => LocalLedgerRepository(
    h.store,
    h.mutations,
    h.records,
    h.conflicts,
    api: fixture.b,
  );
  static Future<_Device> create(ServerFixture fixture, {File? file}) async {
    final observed = RecordedRealApi(fixture.b)
      ..spaceResponse = await fixture.b.spaces();
    final h = await SyncHarness.create(
      api: observed,
      newId: uuid,
      database: file == null ? null : JiabuDatabase(NativeDatabase(file)),
    );
    await h.memberships.reconcile(await fixture.b.spaces());
    final api = _ObservedChat(fixture.b)
      ..beforeWrite = (endpoint, payload) async {
        if (endpoint == 'messages') {
          for (final hash in (payload['images'] as List<Object?>? ?? [])) {
            expect(
              (await h.store.blobs(fixture.space))
                  .singleWhere((row) => row['sha256'] == hash)['uploaded'],
              1,
            );
          }
          observed.events.add('chat:messages');
        }
      };
    final engine = SyncEngine(
      store: h.store,
      api: observed,
      handshake: h.engine.handshake,
      memberships: h.memberships,
      outbox: OutboxProcessor(h.store, observed, h.conflicts, chatApi: api),
      pull: h.pull,
      currentSpace: () => fixture.space,
    );
    await engine.runRound();
    final media = MediaService(
      store: h.store,
      directory: h.directory,
      picker: UnusedPickerStub(),
      compressor: JpegCodecStub(),
    );
    final fence = (await h.store.fence(fixture.space))!;
    final member =
        (await h.store.entity(
              fixture.space,
              'space',
              fixture.space,
            ))!.data['member_id']!
            as String;
    final caps = jiabuChatRegistry(recordBuilder: (_, _) => const SizedBox())
        .capabilities();
    final session = LocalChatSession(
      dao: h.store,
      api: api,
      fence: fence,
      memberId: member,
      caps: caps,
      sync: () async {
        if (api.offline) {
          throw const ApiError('network');
        }
        await engine.runRound();
        await engine.refreshChat(fixture.space);
      },
      media: media,
    );
    await session.initialize();
    await session.recover();
    return _Device(fixture, h, api, media, engine, session);
  }

  Future<void> sync() async {
    if (!api.offline) {
      await engine.runRound();
    }
  }

  Future<void> close() async {
    await session.dispose();
    await h.close();
  }

  Future<void> until(Future<bool> Function() condition) async {
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(end)) {
      await sync();
      if (session.blocks.snapshot.messages.values.any(
            (message) => message['role'] == 'assistant',
          ) &&
          await condition()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail(
      'C5 real-server condition timed out; check loopback endpoint support '
      'and fixture script',
    );
  }

  Future<List<String>> records() async => (await h.store.entities(
    fixture.space,
    'record',
  )).map((row) => row.data['id']! as String).toList();
  Message get reply => session.blocks.snapshot.messages.values
      .where((message) => message['role'] == 'assistant')
      .last;
  Future<void> send(String text, {List<String> images = const []}) async {
    expect(await session.send(text, images), isA<Ok<void>>());
    await sync();
    await session.recover();
  }
}

final _control = Dio();
Future<void> script(String match, List<Map<String, Object?>> turns) async {
  await _control.post<Object?>(
    '${env('JIABU_IT_AI_URL')}/__control/script',
    data: {'match': match, 'turns': turns},
  );
}

Future<void> release(String barrier) async {
  await _control.post<Object?>(
    '${env('JIABU_IT_AI_URL')}/__control/release',
    data: {'barrier': barrier},
  );
}

Map<String, Object?> createTool(
  ServerFixture f,
  String id, {
  int amount = 6800,
  List<String> images = const [],
}) => {
  'name': 'create_record',
  'arguments': f.expense(id, amount: amount, images: images),
};
Map<String, Object?> askTool() => {
  'name': 'ask_user',
  'arguments': {
    'prompt': '用哪张卡付的？',
    'options': [
      {'id': 'credit', 'label': '信用卡'},
      {'id': 'cash', 'label': '现金'},
    ],
    'fields': <Object?>[],
  },
};

void main() {
  late ServerFixture f;
  late _Device a;
  HttpOverrides? previous;
  setUpAll(() {
    previous = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDownAll(() {
    HttpOverrides.global = previous;
    _control.close();
  });
  setUp(() async {
    f = ServerFixture();
    await f.start();
    a = await _Device.create(f);
  });
  tearDown(() async {
    await a.close();
    await f.close();
  });

  testWidgets('chat_flow1_stream_record_card_edit_and_void', (tester) async {
    final record = uuid();
    final partial = <String>{};
    final subscription = a.session.changes.listen((_) {
      for (final message in a.session.blocks.snapshot.messages.values.where(
        (message) => message['role'] == 'assistant',
      )) {
        partial.add(
          message.blocks
              .where((block) => block.type == 'markdown')
              .map((block) => block.data['text'] ?? '')
              .join(),
        );
      }
    });
    await tester.runAsync(() async {
      await script('午饭 68，信用卡，日常餐饮', [
        {
          'text': '正在记下这笔午饭。',
          'slow': true,
          'tools': [createTool(f, record)],
        },
        {'text': '已记录，可以在卡片上修改或撤销。', 'slow': true},
      ]);
      await a.send('午饭 68，信用卡，日常餐饮');
      await a.until(
        () async => (await a.records()).contains(record) && a.reply.rev > 0,
      );
    });
    expect(
      a.reply.blocks.any((block) => block.type == 'x-jiabu.record_card'),
      isTrue,
    );
    expect(partial.where((text) => text.isNotEmpty).length, greaterThan(1));
    final registry = jiabuChatRegistry(
      recordBuilder: (_, block) => RecordCardBlock(
        spaceId: f.space,
        recordId: block.data['recordId']! as String,
        versionAtReply: block.data['versionAtReply']! as int,
      ),
    );
    await pumpC3(
      tester,
      repository: a.ledger,
      sessionSpaceId: f.space,
      child: JiabuChatWeaveTheme(
        child: ChatWeaveList(
          store: a.session.blocks,
          registry: registry,
          conversationId: a.session.conversationId,
          messageFrameBuilder: (_, _, child) =>
              child is MessageView ? JiabuMessageView(source: child) : child,
        ),
      ),
    );
    expect(find.byType(RecordCardBlock), findsWidgets);
    expect(find.text('编辑'), findsWidgets);
    expect(find.text('撤销'), findsWidgets);
    // C3's real tool queue is the command path used by these card buttons.
    await tester.runAsync(() async {
      final row = (await a.h.store.entity(f.space, 'record', record))!;
      expect(
        await a.ledger.editRecord(f.space, record, {
          'amount_minor': 7200,
        }, openedVersion: row.baseVersion),
        isA<Ok<String>>(),
      );
      await a.sync();
      expect(
        (await a.h.store.entity(
          f.space,
          'record',
          record,
        ))!.data['amount_minor'],
        7200,
      );
      expect(
        await a.ledger.recordStatus(f.space, record, restore: false),
        isA<Ok<String>>(),
      );
      await a.sync();
      expect(
        (await a.h.store.entity(f.space, 'record', record))!.data['status'],
        'voided',
      );
      await subscription.cancel();
    });
    await pumpDatabaseFrames(tester);
    expect(find.text('已撤销'), findsWidgets);
  });

  test(
    'chat_flow3_offline_text_photo_order_failure_and_same_id_retry',
    () async {
      final record = uuid();
      final imported = await a.media.importImage(
        f.space,
        'chat',
        testJpeg(gps: true),
      );
      final hash = (imported as Ok<String>).value;
      await script('离线午饭', [
        {
          'tools': [
            createTool(f, record, images: [hash]),
          ],
        },
        {'text': '已记录午饭和原图。'},
      ]);
      a.api.offline = true;
      expect(await a.session.send('离线午饭 68', [hash]), isA<Ok<void>>());
      final user = (await a.h.store.outbox(f.space))
          .singleWhere((op) => op.kind == 'chat_send')
          .id;
      await a.sync();
      expect(
        (await a.h.store.outbox(f.space)).any((op) => op.id == user),
        isTrue,
      );
      expect(a.api.writes, isEmpty);
      a.api.offline = false;
      a.api.loseNextSend = true;
      await a.session.retryUpload(user);
      await a.sync();
      expect(
        (await a.h.store.outbox(f.space)).any((op) => op.id == user),
        isTrue,
      );
      await a.session.retryUpload(user);
      await a.session.recover();
      await a.until(() async => (await a.records()).contains(record));
      expect(
        a.api.writes.where((write) => write.endpoint == 'messages').length,
        greaterThanOrEqualTo(2),
      );
      expect(
        a.api.writes
            .where((write) => write.endpoint == 'messages')
            .map((write) => write.id)
            .toSet(),
        {user},
      );
      final events = (a.h.api as RecordedRealApi).events;
      expect(
        events.indexOf('blob:$hash'),
        lessThan(events.indexOf('chat:messages')),
      );
      expect(
        (await a.h.store.blobs(f.space))
            .singleWhere((blob) => blob['sha256'] == hash)['uploaded'],
        1,
      );
      expect(
        (await a.h.store.entities(
          f.space,
          'record',
        )).where((row) => row.data['id'] == record),
        hasLength(1),
      );
    },
  );

  test('chat_two_devices_answer_same_reply_without_user_message', () async {
    final b = await _Device.create(f);
    addTearDown(b.close);
    final record = uuid();
    await script('追问午饭', [
      {
        'tools': [askTool()],
      },
      {
        'tools': [createTool(f, record)],
      },
      {'text': '按你的回答记好了。'},
    ]);
    await a.send('追问午饭 68');
    await a.until(() async => a.reply.status == 'paused');
    await b.session.recover();
    await b.until(
      () async => b.session.blocks.snapshot.messages.values.any(
        (message) => message.status == 'paused',
      ),
    );
    final originalReply = a.reply.id;
    final before = (await a.h.store.entities(
      f.space,
      'chat_entry',
    )).where((row) => row.data['role'] == 'user').length;
    b.session.composer.beginOtherInput();
    await b.session.composer.submitOtherInput('信用卡');
    await b.sync();
    await a.until(
      () async => (await a.records()).contains(record) && a.reply.rev > 0,
    );
    expect(a.reply.id, originalReply);
    final answer =
        a.reply.blocks
                .firstWhere((block) => block.type == 'choice')
                .data['state']!
            as Map<String, Object?>;
    expect(answer['freeText'], '信用卡');
    expect(
      (await a.h.store.entities(
        f.space,
        'chat_entry',
      )).where((row) => row.data['role'] == 'user').length,
      before,
    );
    expect(await a.records(), [record]);
  });

  test('chat_two_devices_race_only_one_answer_effect', () async {
    final b = await _Device.create(f);
    addTearDown(b.close);
    final record = uuid();
    await script('同时追问午饭', [
      {
        'tools': [askTool()],
      },
      {
        'tools': [createTool(f, record)],
      },
      {'text': '已记录。'},
    ]);
    await a.send('同时追问午饭 68');
    await a.until(() async => a.reply.status == 'paused');
    await b.session.recover();
    await b.until(
      () async => b.session.blocks.snapshot.messages.values.any(
        (message) => message.status == 'paused',
      ),
    );
    final message = a.reply.id;
    final block = a.reply.blocks
        .firstWhere((block) => block.type == 'choice')
        .id;
    await Future.wait([
      a.session.interactions.submit(message, block, {
        'selected': ['cash'],
      }),
      b.session.interactions.submit(message, block, {
        'selected': ['credit'],
      }),
    ]);
    await Future.wait([a.sync(), b.sync()]);
    await a.until(
      () async => (await a.records()).contains(record) && a.reply.rev > 0,
    );
    await b.sync();
    final left = await a.h.store.chatClientState(f.space, message);
    final right = await b.h.store.chatClientState(f.space, message);
    final statuses = [
      for (final state in [left, right])
        for (final receipt
            in (state['receipts']! as Map<String, Object?>).values)
          (receipt! as Map<String, Object?>)['status'],
    ];
    expect(statuses.where((status) => status == 'accepted'), hasLength(1));
    expect(statuses.where((status) => status == 'rejected'), hasLength(1));
    expect(await a.records(), [record]);
  });

  test('chat_stop_preserves_first_record_and_retry_never_duplicates', () async {
    final first = uuid();
    final second = uuid();
    await script('两笔停止', [
      {
        'tools': [createTool(f, first), askTool()],
      },
    ]);
    await a.send('两笔停止：午饭 68，停车 10');
    await a.until(() async => a.reply.status == 'paused');
    expect(await a.session.stop(a.reply.id), isA<Ok<void>>());
    await a.until(() async => a.reply.rev > 0);
    expect(await a.records(), [first]);
    expect('${a.reply['fallbackText']}', contains('1'));
    await script('两笔重试', [
      {
        'tools': [createTool(f, second, amount: 1000)],
      },
      {'text': '处理中', 'omit_completed': true},
      {'text': '剩余部分已完成。'},
    ]);
    await a.send('两笔重试：停车 10');
    await a.until(
      () async => const {'error', 'interrupted'}.contains(a.reply.status),
    );
    final oldId = a.reply.id;
    expect(await a.session.retry(oldId), isA<Ok<void>>());
    await a.session.recover();
    await a.until(() async => a.reply.id != oldId && a.reply.rev > 0);
    expect((await a.records()).toSet(), {first, second});
    expect(await a.records(), hasLength(2));
  });

  test('chat_killed_app_recovers_from_active_messages', () async {
    final directory = await Directory.systemTemp.createTemp('c5-killed-');
    final file = File('${directory.path}/client.sqlite');
    final device = await _Device.create(f, file: file);
    final record = uuid();
    await script('杀进程午饭', [
      {
        'text': '正在处理午饭',
        'barrier': 'killed-app',
        'tools': [createTool(f, record)],
      },
      {'text': '已记录。'},
    ]);
    await device.send('杀进程午饭 68');
    await device.until(
      () async => device.session.blocks.snapshot.messages.values.any(
        (message) => message['role'] == 'assistant',
      ),
    );
    final replyId = device.reply.id;
    expect(await f.b.chatActive(f.space), isNotEmpty);
    await device.close();
    final restarted = await _Device.create(f, file: file);
    try {
      await restarted.session.recover();
      await restarted.until(
        () async => restarted.api.opens.any((open) => open.message == replyId),
      );
      expect(
        restarted.api.opens.firstWhere((open) => open.message == replyId).after,
        greaterThanOrEqualTo(1),
      );
      await release('killed-app');
      await restarted.until(
        () async =>
            (await restarted.records()).contains(record) &&
            restarted.reply.rev > 0,
      );
      expect(restarted.reply.id, replyId);
    } finally {
      await restarted.close();
      await directory.delete(recursive: true);
    }
  });

  test('chat_ai_unavailable_manual_takeover_cancels_server_queue', () async {
    final aiRecord = uuid();
    final manualRecord = uuid();
    await script('手动接管午饭', [
      {
        'before_barrier': 'degraded',
        'http_error': 503,
        'error': 'fixture_unavailable',
      },
      {
        'tools': [createTool(f, aiRecord)],
      },
      {'text': '已记录。'},
    ]);
    await a.send('手动接管午饭 68');
    await a.until(
      () async => a.session.blocks.snapshot.messages.values.any(
        (message) => message['role'] == 'assistant',
      ),
    );
    await release('degraded');
    await a.until(() async => a.session.aiUnavailable);
    final user = a.session.blocks.snapshot.messages.values
        .firstWhere((message) => message['role'] == 'user')
        .id;
    expect(await a.session.takeOver(user), isA<Ok<Map<String, Object?>>>());
    final manual = await a.ledger.createRecord(
      f.space,
      f.expense(manualRecord),
    );
    expect(manual, isA<Ok<String>>());
    await a.sync();
    await Future<void>.delayed(const Duration(seconds: 7));
    await a.sync();
    expect(await a.records(), [manualRecord]);
    expect(
      (await f.b.chatActive(f.space))
          .where((message) => message['replyTo'] == user),
      isEmpty,
    );
  });

  test('chat_first_setup_uses_real_tools_without_income_or_expense', () async {
    await a.close();
    f.space = uuid();
    await f.post(f.b, 'v1/spaces', {
      'id': f.space,
      'name': '用户A设置',
      'accent_color': 'pine',
      'currency': 'CNY',
      'timezone': 'Asia/Shanghai',
    });
    a = await _Device.create(f);
    final real = uuid();
    final purpose = uuid();
    await script('设置新账户', [
      {
        'tools': [
          {
            'name': 'ask_user',
            'arguments': {
              'prompt': '设置账户名称',
              'options': <Object?>[],
              'fields': [
                {
                  'key': 'name',
                  'label': '账户名称',
                  'type': 'text',
                  'required': true,
                },
              ],
            },
          },
        ],
      },
      {
        'tools': [
          {
            'name': 'create_account',
            'arguments': {
              'id': real,
              'kind': 'real',
              'name': '用户A银行卡',
              'opening_balance_minor': 10000,
              'opening_on': '2026-01-01',
            },
          },
          {
            'name': 'create_account',
            'arguments': {
              'id': purpose,
              'kind': 'purpose',
              'name': '日常餐饮',
              'opening_balance_minor': 10000,
              'opening_on': '2026-01-01',
            },
          },
        ],
      },
      {
        'tools': [
          {
            'name': 'set_allocation_plan',
            'arguments': {
              'account_id': purpose,
              'amount_minor': 30000,
              'day_of_month': 1,
              'enabled': true,
            },
          },
        ],
      },
      {
        'tools': [
          {'name': 'query_balance', 'arguments': <String, Object?>{}},
        ],
      },
      {'text': '账户、起始余额和每月拨入计划已设置。'},
    ]);
    await a.send('设置新账户');
    await a.until(() async => a.reply.status == 'paused');
    final block = a.reply.blocks.firstWhere(
      (block) => block.type == 'form_intent',
    );
    await a.session.interactions.submit(a.reply.id, block.id, {
      'values': {'name': '用户A银行卡'},
    });
    await a.sync();
    await a.until(() async => a.reply.rev > 0);
    expect(await a.h.store.entity(f.space, 'account', real), isNotNull);
    expect(
      await a.h.store.entity(f.space, 'allocation_plan', purpose),
      isNotNull,
    );
    expect(
      a.reply.blocks.any(
        (block) => const {'metric', 'metric_group'}.contains(block.type),
      ),
      isTrue,
    );
    expect(await a.records(), isEmpty);
  });
}
