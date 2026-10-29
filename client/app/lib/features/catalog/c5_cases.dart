import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/chat_composer.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';
import 'package:jiabu/shared/chatweave/user_message_note.dart';
import 'package:jiabu/shared/ledger/main_frame.dart';
import 'package:jiabu_design/jiabu_design.dart';

const c5States = [
  'empty',
  'setup_entry',
  'streaming',
  'paused',
  'interrupted_retry',
  'stopping',
  'recovering',
  'ai_unavailable',
  'user_pending',
  'user_failed',
  'user_waiting_ai',
  'user_photo',
  'user_manual_takeover',
  'composer_idle',
  'composer_locked',
  'composer_answering',
  'composer_queued',
  'composer_closed_elsewhere',
  'record_ready',
  'record_changed',
  'record_syncing',
  'metric',
  'metric_group',
  'dataset',
  'time_series',
  'choice_open',
  'choice_queued',
  'choice_resolved',
  'confirmation',
  'form_intent',
  'comparison',
  'status',
  'unknown_fallback',
  'process_running',
  'process_parallel',
  'process_failed',
  'process_paused',
  'process_stopped',
  'process_collapsed',
];

/// Fictional protocol content. UI labels themselves always come from ARB.
Json c5Block(String type, {String id = 'card'}) => {
  'id': id,
  'type': type,
  'schemaVersion': 1,
  'status': 'complete',
  'fallbackText': '用户A的示例记录',
  'data': switch (type) {
    'markdown' => {'text': '午饭已记下，可以在卡片上修改或撤销。'},
    'metric' => {
      'label': '餐饮支出',
      'value': 68,
      'unit': '元',
      'asOf': '2026-10-29T12:00:00Z',
    },
    'metric_group' => {
      'title': '用途账户',
      'metrics': [
        {'label': '日常餐饮', 'value': 680, 'unit': '元'},
        {'label': '交通', 'value': 120, 'unit': '元'},
      ],
    },
    'dataset' => {
      'columns': [
        {'key': 'title', 'label': '记录', 'type': 'string'},
        {'key': 'amount', 'label': '金额', 'type': 'number'},
      ],
      'rows': [
        {'title': '午饭', 'amount': 68},
        {'title': '晚饭', 'amount': 32},
      ],
      'totalRows': 2,
    },
    'time_series' => {
      'title': '餐饮变化',
      'xType': 'date',
      'series': [
        {
          'key': 'meal',
          'label': '餐饮',
          'points': [
            {'x': '2026-10-28', 'y': 50},
            {'x': '2026-10-29', 'y': 68},
          ],
        },
      ],
    },
    'choice' => {
      'prompt': '用哪张卡付的？',
      'options': [
        {'id': 'credit', 'label': '信用卡'},
        {'id': 'cash', 'label': '现金'},
      ],
      'selection': 'single',
      'action': {'type': 'choice.select', 'target': 'clarification.answer'},
      'state': {'status': 'open'},
    },
    'confirmation' => {
      'title': '确认修改这笔记录？',
      'severity': 'normal',
      'action': {'type': 'confirmation.respond', 'target': 'record.update'},
      'state': {'status': 'open'},
    },
    'form_intent' => {
      'title': '设置账户',
      'fields': [
        {'key': 'name', 'label': '账户名称', 'type': 'text', 'required': true},
        {'key': 'opening', 'label': '起始余额', 'type': 'number', 'required': true},
      ],
      'action': {'type': 'form.submit', 'target': 'clarification.answer'},
      'state': {'status': 'open'},
    },
    'comparison' => {
      'subjects': [
        {'id': 'a', 'label': '用户A'},
        {'id': 'b', 'label': '用户B'},
      ],
      'attributes': [
        {'key': 'amount', 'label': '餐饮', 'type': 'number'},
      ],
      'values': [
        {'subject': 'a', 'attribute': 'amount', 'value': 68},
        {'subject': 'b', 'attribute': 'amount', 'value': 32},
      ],
    },
    'status' => {
      'label': '整理记录',
      'state': 'running',
      'progress': {'current': 1, 'total': 2},
    },
    'x-jiabu.record_card' => {
      'recordId': 'fictional-record',
      'versionAtReply': 1,
    },
    _ => <String, Object?>{},
  },
};

Message c5Message(String state) {
  final paused =
      state == 'paused' ||
      state.contains('locked') ||
      state.contains('answering') ||
      state.contains('queued') ||
      state == 'process_paused';
  final type = state.startsWith('record_')
      ? 'x-jiabu.record_card'
      : state.startsWith('choice_') || paused
      ? 'choice'
      : [
          'metric',
          'metric_group',
          'dataset',
          'time_series',
          'confirmation',
          'form_intent',
          'comparison',
          'status',
        ].contains(state)
      ? state
      : state == 'unknown_fallback'
      ? 'x-jiabu.document_card'
      : 'markdown';
  var block = c5Block(type);
  if (state == 'choice_resolved')
    block = {
      ...block,
      'data': {
        ...object(block['data']),
        'state': {
          'status': 'resolved',
          'selected': ['credit'],
          'freeText': '信用卡',
          'resolvedAt': '2026-10-29T12:00:00Z',
          'resolvedBy': '用户A',
        },
      },
    };
  if (state == 'ai_unavailable' || state == 'recovering')
    block = {
      ...c5Block('markdown'),
      'data': {'text': '等待处理这条消息。'},
    };
  final hasSteps =
      state.startsWith('process_') || state == 'streaming' || state == 'paused';
  final status = paused
      ? 'paused'
      : state == 'interrupted_retry'
      ? 'error'
      : state == 'process_stopped'
      ? 'interrupted'
      : [
          'streaming',
          'stopping',
          'recovering',
          'ai_unavailable',
          'process_running',
          'process_parallel',
        ].contains(state)
      ? 'streaming'
      : 'complete';
  return Message.fromJson({
    'protocolVersion': '0.1',
    'id': 'reply',
    'conversationId': 'conversation',
    'role': 'assistant',
    'status': status,
    'rev': const {'complete', 'error', 'interrupted'}.contains(status) ? 1 : 0,
    'createdAt': '2026-10-29T12:00:00Z',
    'fallbackText': '午饭已记下',
    'blocks': [block],
    if (paused)
      'interrupt': {
        'id': 'question',
        'blockId': 'card',
        'otherInput': true,
        'expiresAt': '2026-11-05T12:00:00Z',
      },
    if (hasSteps)
      'steps': [
        {
          'id': 'lookup',
          'label': '查找账户',
          'kind': 'tool',
          'state': state == 'process_failed' ? 'failed' : 'succeeded',
          'durationMs': 800,
        },
        {
          'id': 'write',
          'label': '整理午饭记录',
          'kind': 'tool',
          'state': paused
              ? 'awaiting_user'
              : state == 'process_stopped'
              ? 'cancelled'
              : status == 'complete'
              ? 'succeeded'
              : 'running',
          if (paused) 'blockId': 'card',
          if (status == 'complete') 'durationMs': 400,
        },
      ],
  });
}

class CatalogChatStore implements ChatWeaveStore {
  final messages = <String, Message>{};
  final clients = <String, ClientState>{};
  @override
  Future<Message?> load(String id) async => messages[id];
  @override
  Future<int?> lastSeq(String id) async => 0;
  @override
  Future<ClientState> loadClientState(String id) async =>
      clients[id] ?? ClientState();
  @override
  Future<void> saveClientState(String id, ClientState state) async {
    clients[id] = state;
  }

  @override
  Future<void> saveProvisional(Message message, {required int lastSeq}) async {
    messages[message.id] = message;
  }

  @override
  Future<void> saveFinal(Message message) async {
    messages[message.id] = message;
  }

  @override
  Stream<List<Message>> watchConversation(String id) => Stream.value(
    messages.values.where((m) => m['conversationId'] == id).toList(),
  );
  @override
  Future<void> clear() async {
    messages.clear();
    clients.clear();
  }
}

class CatalogQueuedAction implements ActionTransport {
  @override
  Future<ActionSubmission> submit(ActionRequest request) async =>
      const ActionSubmission.queued();
}

class C5Preview extends StatefulWidget {
  const C5Preview({required this.state, this.accent = 'pine', super.key});
  final String state;
  final String accent;
  @override
  State<C5Preview> createState() => _C5PreviewState();
}

class _C5PreviewState extends State<C5Preview> {
  final _store = BlockStore();
  final _persistence = CatalogChatStore();
  final _process = ProcessState();
  late InteractionController _actions;
  late InterruptComposerController _composer;
  @override
  void initState() {
    super.initState();
    _store.apply(SyncMessage(c5Message(widget.state)));
    if (const {
      'streaming',
      'paused',
      'interrupted_retry',
      'stopping',
      'recovering',
      'ai_unavailable',
    }.contains(widget.state)) {
      _store.apply(
        SyncMessage(
          Message.fromJson({
            'id': 'input',
            'role': 'user',
            'status': 'complete',
            'rev': 1,
            'conversationId': 'conversation',
            'protocolVersion': '0.1',
            'createdAt': '2026-10-29T11:59:59Z',
            'fallbackText': '午饭 68，信用卡，日常餐饮',
            'blocks': <Object?>[],
            'metadata': {
              'input': {'text': '午饭 68，信用卡，日常餐饮', 'images': <String>[]},
            },
          }),
        ),
      );
    }
    _actions = InteractionController(
      store: _store,
      persistence: _persistence,
      nextId: () => '00000000-0000-7000-8000-000000000001',
      transport: CatalogQueuedAction(),
    );
    _composer = InterruptComposerController(
      store: _store,
      interactions: _actions,
      conversationId: 'conversation',
    );
    if (widget.state == 'composer_answering') _composer.beginOtherInput();
    if (widget.state.contains('queued'))
      unawaited(
        _actions.submit('reply', 'card', {
          'selected': ['credit'],
        }),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = widget.state;
    final message = _store.snapshot.messages['reply']!;
    final registry = jiabuChatRegistry(
      recordBuilder: (context, block) => C3Preview(
        state: state == 'record_changed'
            ? 'card_changed'
            : state == 'record_syncing'
            ? 'card_loading'
            : 'card_recorded',
        accent: widget.accent,
      ),
    );
    Widget body;
    if (state == 'empty' || state == 'setup_entry') {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.chatEmpty),
          if (state == 'setup_entry')
            TextButton(onPressed: () {}, child: Text(l.chatSetup)),
        ],
      );
    } else if (state == 'ai_unavailable') {
      body = NoteBubble(
        id: state,
        child: Wrap(
          children: [
            Text(l.chatUnavailable),
            TextButton(onPressed: () {}, child: Text(l.ledgerManual)),
          ],
        ),
      );
    } else if (state.startsWith('user_')) {
      body = UserMessageNote(
        message: Message.fromJson({
          'id': 'user',
          'role': 'user',
          'rev': 1,
          'status': 'complete',
          'conversationId': 'conversation',
          'createdAt': '2026-10-29T12:00:00Z',
          'blocks': [],
          'fallbackText': '午饭 68，信用卡，日常餐饮',
          'metadata': {
            'input': {
              'text': '午饭 68，信用卡，日常餐饮',
              'images': state == 'user_photo'
                  ? ['fictional-photo']
                  : <String>[],
            },
          },
        }),
        delivery: switch (state) {
          'user_failed' => ChatDelivery.failed,
          'user_waiting_ai' => ChatDelivery.waitingAi,
          'user_manual_takeover' => ChatDelivery.manual,
          _ => ChatDelivery.pending,
        },
        onRetry: () {},
        onManual: () {},
      );
    } else if (state.startsWith('composer_')) {
      body = JiabuChatComposer(
        composer: _composer,
        draft: '',
        onDraft: (_) {},
        onSend: (_) async => true,
        onPhoto: () {},
        onGallery: () {},
      );
    } else {
      body = JiabuMessageView(
        source: MessageView(
          message: message,
          registry: registry,
          processState: _process,
          interactions: _actions,
          composer: _composer,
          stopRequested: state == 'stopping',
          onStop: () {},
        ),
        onRetry: () {},
      );
    }
    if (const {
      'empty',
      'setup_entry',
      'streaming',
      'paused',
      'interrupted_retry',
      'stopping',
      'recovering',
      'ai_unavailable',
    }.contains(state)) {
      final empty = state == 'empty' || state == 'setup_entry';
      return JiabuChatWeaveTheme(
        child: MainFrame(
          spaceName: '虚构空间A',
          accent:
              context.jiabu.colors.spaceAccents[widget.accent] ??
              context.jiabu.colors.primaryText,
          settingsLabel: l.ledgerMySettings,
          labels: [l.ledgerChat, l.ledgerOverview, l.ledgerHistory],
          selected: 0,
          onSelect: (_) {},
          onSettings: () {},
          child: Column(
            children: [
              if (state == 'ai_unavailable')
                Padding(
                  padding: const EdgeInsets.all(JiabuChatMetrics.gap),
                  child: body,
                ),
              Expanded(
                child: empty
                    ? Center(child: body)
                    : ChatWeaveList(
                        store: _store,
                        registry: registry,
                        conversationId: 'conversation',
                        interactions: _actions,
                        composer: _composer,
                        stopRequested: state == 'stopping'
                            ? {'reply'}
                            : const {},
                        onStop: (_) {},
                        userMessageBuilder: (_, message) => UserMessageNote(
                          message: message,
                          delivery: ChatDelivery.waitingAi,
                        ),
                        messageFrameBuilder: (_, _, child) =>
                            child is MessageView
                            ? JiabuMessageView(source: child, onRetry: () {})
                            : child,
                      ),
              ),
              JiabuChatComposer(
                composer: _composer,
                draft: '',
                onDraft: (_) {},
                onSend: (_) async => true,
                onPhoto: () {},
                onGallery: () {},
              ),
            ],
          ),
        ),
      );
    }
    return JiabuChatWeaveTheme(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JiabuChatMetrics.gap),
        child: body,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_composer.dispose());
    unawaited(_actions.dispose());
    unawaited(_store.dispose());
    super.dispose();
  }
}
