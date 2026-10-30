import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';
import 'package:jiabu/shared/chatweave/jiabu_thinking_indicator.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

Message _reply({
  String status = 'streaming',
  List<Map<String, Object?>> blocks = const [],
  List<Map<String, Object?>> steps = const [],
}) => Message.fromJson({
  'protocolVersion': '0.1',
  'id': 'reply',
  'conversationId': 'conversation',
  'role': 'assistant',
  'status': status,
  'rev': status == 'streaming' ? 0 : 1,
  'createdAt': '2026-10-30T12:00:00Z',
  'fallbackText': '',
  'blocks': blocks,
  if (steps.isNotEmpty) 'steps': steps,
});

Map<String, Object?> _text(String text, {String status = 'pending'}) => {
  'id': 'text',
  'type': 'markdown',
  'schemaVersion': 1,
  'status': status,
  'fallbackText': text,
  'data': {'text': text},
};

Map<String, Object?> _step(String state) => {
  'id': 'step-$state',
  'label': '查找账户',
  'kind': 'tool',
  'state': state,
  'durationMs': 800,
};

Widget _view(
  Message message, {
  Map<String, Object?>? activity,
  bool stopRequested = false,
}) => JiabuChatWeaveTheme(
  child: JiabuMessageView(
    source: MessageView(
      message: message,
      registry: jiabuChatRegistry(recordBuilder: (_, _) => const SizedBox()),
      processState: ProcessState(),
      activity: activity,
      stopRequested: stopRequested,
    ),
  ),
);

void main() {
  group('thinking indicator', () {
    testWidgets('before_first_token_shows_thinking_not_working', (
      tester,
    ) async {
      await pumpC3(tester, child: _view(_reply()));
      expect(find.text('思考中'), findsOneWidget);
      expect(find.text('处理中'), findsNothing);
    });

    testWidgets('thinking_sits_on_the_assistant_name_line', (tester) async {
      await pumpC3(tester, child: _view(_reply()));
      final name = tester.getRect(find.text('家簿助手'));
      final label = tester.getRect(find.text('思考中'));
      final dots = tester.getRect(find.byType(JiabuThinkingDots));
      expect(label.center.dy, closeTo(name.center.dy, 2));
      expect(dots.center.dy, closeTo(name.center.dy, 2));
      expect(dots.left, greaterThan(name.right));
      expect(label.left, greaterThan(dots.right));
    });

    testWidgets('english_label_is_thinking', (tester) async {
      await pumpC3(tester, locale: 'en', child: _view(_reply()));
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('Working'), findsNothing);
    });

    testWidgets('hidden_while_text_is_streaming', (tester) async {
      await pumpC3(
        tester,
        child: _view(_reply(blocks: [_text('我主要能帮你做两大类事情')])),
      );
      expect(find.text('思考中'), findsNothing);
      expect(find.text('处理中'), findsNothing);
      expect(find.byType(JiabuThinkingDots), findsNothing);
    });

    testWidgets('hidden_while_a_tool_step_runs', (tester) async {
      await pumpC3(tester, child: _view(_reply(steps: [_step('running')])));
      expect(find.text('思考中'), findsNothing);
      expect(find.textContaining('查找账户'), findsOneWidget);
    });

    testWidgets('shown_again_between_tool_calls', (tester) async {
      await pumpC3(
        tester,
        child: _view(
          _reply(
            blocks: [_text('先查一下', status: 'complete')],
            steps: [_step('succeeded')],
          ),
        ),
      );
      expect(find.text('思考中'), findsOneWidget);
    });

    testWidgets('hidden_when_complete_or_stopping', (tester) async {
      await pumpC3(
        tester,
        child: _view(
          _reply(
            status: 'complete',
            blocks: [_text('好了', status: 'complete')],
          ),
        ),
      );
      expect(find.text('思考中'), findsNothing);
      await pumpC3(tester, child: _view(_reply(), stopRequested: true));
      expect(find.text('思考中'), findsNothing);
      expect(find.text('正在停止…'), findsOneWidget);
    });

    testWidgets('degraded_activity_says_waiting_for_ai', (tester) async {
      await pumpC3(
        tester,
        child: _view(_reply(), activity: {'phase': 'degraded'}),
      );
      expect(find.text('待 AI 处理'), findsOneWidget);
      expect(find.text('思考中'), findsNothing);
    });

    test('rule_is_pure_in_message_state', () {
      expect(jiabuShowsThinking(_reply()), isTrue);
      expect(jiabuShowsThinking(_reply(blocks: [_text('x')])), isFalse);
      expect(jiabuShowsThinking(_reply(steps: [_step('running')])), isFalse);
      expect(
        jiabuShowsThinking(_reply(blocks: [_text('x', status: 'complete')])),
        isTrue,
      );
      expect(jiabuShowsThinking(_reply(status: 'complete')), isFalse);
    });
  });

  group('markdown while streaming', () {
    const head = '我主要能帮你做两大类事情：**家庭记账**和**家庭资料管理**。\n\n💰 **家庭记账**\n\n';
    const first = '$head- **记收支**：记录支出、收入、退款，也能修改或撤销。';
    const second =
        '$first\n- **管理账户**：建立银行卡、现金等真实资金账户，查询余额。\n'
        '- **规划用途**：建立生活用途。';

    Widget frame(String text, {String status = 'pending'}) {
      final registry = jiabuChatRegistry(
        recordBuilder: (_, _) => const SizedBox(),
      );
      return JiabuChatWeaveTheme(
        child: SingleChildScrollView(
          child: registry.render(Block.fromJson(_text(text, status: status))),
        ),
      );
    }

    testWidgets('list_and_bold_are_parsed_on_every_streamed_update', (
      tester,
    ) async {
      await pumpC3(tester, child: frame(first));
      await pumpC3(tester, child: frame(second));
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('- ', findRichText: true), findsNothing);
      expect(find.textContaining('管理账户', findRichText: true), findsOneWidget);
    });

    testWidgets('finished_message_renders_the_same', (tester) async {
      await pumpC3(tester, child: frame(second, status: 'complete'));
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('- ', findRichText: true), findsNothing);
    });
  });
}
