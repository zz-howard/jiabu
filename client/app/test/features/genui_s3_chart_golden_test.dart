@Tags(['golden'])
library;

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';

import '../support/c3_harness.dart';

void main() {
  Block block(String type, Map<String, Object?> data, {bool pending = false}) =>
      Block.fromJson({
        'id': '$type-golden',
        'type': type,
        'schemaVersion': 1,
        'status': pending ? 'pending' : 'complete',
        if (!pending) 'data': data,
        'fallbackText': type == 'breakdown'
            ? '本月支出：餐饮980元、居家620元、交通360元'
            : '一月120元、二月负80元、三月240元',
      });

  Widget frame(Block chart) {
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
    );
    return SingleChildScrollView(
      child: JiabuChatWeaveTheme(child: registry.render(chart)),
    );
  }

  final breakdown = block('breakdown', {
    'title': '本月支出构成',
    'unit': '元',
    'format': {'style': 'currency', 'currency': 'CNY', 'minorUnits': true},
    'parts': [
      {'key': 'food', 'label': '餐饮', 'value': 98000},
      {'key': 'home', 'label': '居家', 'value': 62000},
      {'key': 'travel', 'label': '交通', 'value': 36000},
      {'key': 'health', 'label': '健康', 'value': 18000},
      {'key': 'other', 'label': '其他（3 项）', 'value': 12000, 'mergedCount': 3},
    ],
    'summary': '餐饮占比最高',
  });
  final breakdownMaximum = block('breakdown', {
    'format': {'style': 'integer'},
    'parts': [
      for (var index = 0; index < 12; index++)
        {
          'key': 'part_$index',
          'label': '家庭共同使用的超长分类名称 $index',
          'value': 24 - index,
        },
    ],
  });
  final categorySeries = block('category_series', {
    'title': '近月收支净额',
    'xLabel': '月份',
    'yLabel': '净额',
    'unit': '元',
    'format': {'style': 'currency', 'currency': 'CNY', 'minorUnits': true},
    'points': [
      {'key': 'jan', 'label': '一月', 'value': 12000},
      {'key': 'feb', 'label': '二月', 'value': -8000},
      {
        'key': 'mar',
        'label': '三月',
        'value': 24000,
        'assessment': {'status': 'warning', 'label': '偏高'},
      },
    ],
    'reference': {'label': '月均', 'value': 9333},
  });
  final categoryMaximum = block('category_series', {
    'format': {'style': 'integer'},
    'points': [
      for (var index = 0; index < 24; index++)
        {
          'key': 'category_$index',
          'label': 'A very long household category $index',
          'value': index.isEven ? index + 1 : -index - 1,
        },
    ],
  });

  Future<void> golden(
    WidgetTester tester, {
    required Block chart,
    required String path,
    double width = 360,
    double scale = 1,
    String locale = 'zh',
    bool table = false,
  }) async {
    await pumpC3(
      tester,
      width: width,
      scale: scale,
      locale: locale,
      child: frame(chart),
    );
    if (table) {
      await tester.tap(find.text(locale == 'en' ? 'View data table' : '查看数据表'));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(c3Boundary), matchesGoldenFile(path));
  }

  testWidgets('breakdown chart 360 100', (tester) async {
    await golden(
      tester,
      chart: breakdown,
      path: '../goldens/chat/breakdown_zh_pine_w360_text100.png',
    );
  });
  testWidgets('breakdown maximum long labels 430 200', (tester) async {
    await golden(
      tester,
      chart: breakdownMaximum,
      width: 430,
      scale: 2,
      path: '../goldens/chat/breakdown_max_zh_pine_w430_text200.png',
    );
  });
  testWidgets('breakdown table', (tester) async {
    await golden(
      tester,
      chart: breakdown,
      table: true,
      path: '../goldens/chat/breakdown_table_zh_pine_w360_text100.png',
    );
  });
  testWidgets('breakdown skeleton', (tester) async {
    await golden(
      tester,
      chart: block('breakdown', const {}, pending: true),
      path: '../goldens/chat/breakdown_skeleton_zh_pine_w360_text100.png',
    );
  });
  testWidgets('category series chart 360 100', (tester) async {
    await golden(
      tester,
      chart: categorySeries,
      path: '../goldens/chat/category_series_zh_pine_w360_text100.png',
    );
  });
  testWidgets('category series maximum English 430 200', (tester) async {
    await golden(
      tester,
      chart: categoryMaximum,
      width: 430,
      scale: 2,
      locale: 'en',
      path: '../goldens/chat/category_series_max_en_pine_w430_text200.png',
    );
  });
  testWidgets('category series table', (tester) async {
    await golden(
      tester,
      chart: categorySeries,
      table: true,
      path: '../goldens/chat/category_series_table_zh_pine_w360_text100.png',
    );
  });
  testWidgets('category series skeleton', (tester) async {
    await golden(
      tester,
      chart: block('category_series', const {}, pending: true),
      path: '../goldens/chat/category_series_skeleton_zh_pine_w360_text100.png',
    );
  });
}
