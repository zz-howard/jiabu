import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';

import '../support/c3_harness.dart';

void main() {
  BlockRegistry registry({BlockRenderError? onError}) => jiabuChatRegistry(
    recordBuilder: (_, _) => const SizedBox(),
    onError: onError,
  );

  Block block(String type, Map<String, Object?> data, String fallback) =>
      Block.fromJson({
        'id': '$type-card',
        'type': type,
        'schemaVersion': 1,
        'status': 'complete',
        'data': data,
        'fallbackText': fallback,
      });

  test('registry advertises both chart overrides', () {
    final blocks = registry().capabilities().json['blocks'];
    expect(blocks, containsPair('breakdown', 1));
    expect(blocks, containsPair('category_series', 1));
  });

  testWidgets('breakdown formats minor units, summarizes, and toggles table', (
    tester,
  ) async {
    final chart = block('breakdown', {
      'title': '本月支出',
      'unit': '元',
      'format': {'style': 'currency', 'currency': 'CNY', 'minorUnits': true},
      'parts': [
        {'key': 'food', 'label': '餐饮', 'value': 1250},
        {'key': 'travel', 'label': '交通', 'value': 750},
      ],
    }, '本月支出共20元，餐饮12.5元，交通7.5元');
    await pumpC3(
      tester,
      child: JiabuChatWeaveTheme(child: registry().render(chart)),
    );

    expect(find.byKey(const Key('breakdown-total')), findsOneWidget);
    expect(find.bySemanticsLabel('本月支出共20元，餐饮12.5元，交通7.5元'), findsOneWidget);
    expect(find.textContaining('CNY 20.00'), findsOneWidget);
    expect(find.textContaining('63%'), findsOneWidget);
    await tester.tap(find.text('查看数据表'));
    await tester.pump();
    expect(find.text('查看图表'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('breakdown maximum input remains usable at 200 percent text', (
    tester,
  ) async {
    final chart = block('breakdown', {
      'format': {'style': 'integer'},
      'parts': [
        for (var index = 0; index < 12; index++)
          {
            'key': 'part_$index',
            'label': '很长的分类名称 $index',
            'value': 12 - index,
          },
      ],
    }, '十二个分类的完整占比摘要');
    final errors = <Object>[];
    await pumpC3(
      tester,
      width: 430,
      scale: 2,
      child: SingleChildScrollView(
        child: JiabuChatWeaveTheme(
          child: registry(onError: (_, error) => errors.add(error))
              .render(chart),
        ),
      ),
    );
    expect(errors, isEmpty, reason: '$errors');
    expect(find.text('很长的分类名称 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category series shows reference, assessment, negatives and table',
    (tester) async {
      final chart = block('category_series', {
        'title': '收支净额',
        'xLabel': '月份',
        'yLabel': '净额',
        'format': {'style': 'integer'},
        'points': [
          {'key': 'm1', 'label': '一月', 'value': -20},
          {
            'key': 'm2',
            'label': '二月',
            'value': 30,
            'assessment': {'status': 'warning', 'label': '偏高'},
          },
        ],
        'reference': {'label': '月均', 'value': 5},
      }, '一月负20，二月30，月均5');
      await pumpC3(
        tester,
        child: JiabuChatWeaveTheme(child: registry().render(chart)),
      );
      expect(find.bySemanticsLabel('一月负20，二月30，月均5'), findsOneWidget);
      expect(find.textContaining('月均 · 5'), findsOneWidget);
      await tester.tap(find.text('查看数据表'));
      await tester.pump();
      expect(find.textContaining('30 · 偏高'), findsOneWidget);
      expect(find.text('-20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English long labels and 24 points use overflow-safe layout', (
    tester,
  ) async {
    final chart = block('category_series', {
      'format': {'style': 'integer'},
      'points': [
        for (var index = 0; index < 24; index++)
          {
            'key': 'category_$index',
            'label': 'A very long household category $index',
            'value': index.isEven ? index + 1 : -index - 1,
          },
      ],
    }, 'Twenty-four household categories');
    final errors = <Object>[];
    await pumpC3(
      tester,
      locale: 'en',
      width: 430,
      scale: 2,
      child: SingleChildScrollView(
        child: JiabuChatWeaveTheme(
          child: registry(onError: (_, error) => errors.add(error))
              .render(chart),
        ),
      ),
    );
    expect(errors, isEmpty, reason: '$errors');
    expect(find.text('View data table'), findsOneWidget);
    expect(find.text('A very l…ategory 0'), findsOneWidget);
    expect(find.text('A very l…tegory 23'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending charts use type-specific skeletons', (tester) async {
    for (final type in ['breakdown', 'category_series']) {
      final pending = Block.fromJson({
        'id': '$type-pending',
        'type': type,
        'schemaVersion': 1,
        'status': 'pending',
        'fallbackText': '正在生成',
      });
      await pumpC3(
        tester,
        child: JiabuChatWeaveTheme(child: registry().render(pending)),
      );
      final skeleton = find.byKey(ValueKey('$type-skeleton'));
      expect(skeleton, findsOneWidget);
      final size = tester.getSize(skeleton);
      expect(size.width, greaterThanOrEqualTo(300));
      expect(size.height, greaterThan(100));
      expect(tester.takeException(), isNull);
    }
  });
}
