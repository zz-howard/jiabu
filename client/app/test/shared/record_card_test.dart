import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/record_presentation.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

void main() {
  for (final entry in {
    'card_denied': '此内容你已无权查看',
    'card_loading': '记录同步中',
    'card_recorded': '已记录',
    'card_pending': '待上传 · 已存在本机',
    'card_failed': '上传失败',
    'card_voided': '已撤销 · 余额已恢复',
    'card_conflict': '有冲突',
    'card_changed': '后来改过',
    'card_left': '用户A · 已退出',
  }.entries) {
    testWidgets('record_card_${entry.key}', (tester) async {
      await pumpC3(tester, state: entry.key);
      expect(find.text(entry.value), findsWidgets);
    });
  }
  testWidgets('record_card_api_key_has_accessible_attribution', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpC3(tester, state: 'card_api_key');
      expect(find.bySemanticsLabel('通过 API key：虚构记账脚本'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('record_card_fields_have_leaders_and_enabled_primary_actions', (
    tester,
  ) async {
    await pumpC3(tester);
    expect(find.byType(DottedValueRow), findsNWidgets(3));
    expect(find.text('真实账户'), findsOneWidget);
    final purpose = tester.widget<DottedValueRow>(
      find.byWidgetPredicate(
        (widget) => widget is DottedValueRow && widget.label == '虚构日常',
      ),
    );
    expect(purpose.value, '¥88.00');
    for (final label in ['编辑', '撤销']) {
      final finder = find.widgetWithText(TextButton, label);
      final button = tester.widget<TextButton>(finder);
      expect(button.onPressed, isNotNull);
      final context = tester.element(finder);
      final style = TextButtonTheme.of(context).style;
      expect(
        style?.foregroundColor?.resolve({}),
        context.jiabu.colors.primaryText,
      );
      expect(style?.minimumSize?.resolve({})?.height, 44);
    }
  });
  testWidgets('record_card_conflict_has_one_status_and_resolve_entry', (
    tester,
  ) async {
    await pumpC3(tester, state: 'card_conflict');
    expect(find.text('有冲突'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '去处理'), findsOneWidget);
  });
  for (final lockedBy in ['permission', 'sending']) {
    testWidgets('record_card_actions_disabled_for_$lockedBy', (tester) async {
      final base = c3Snapshot('card_recorded');
      final data = LedgerSnapshot(
        spaceId: base.spaceId,
        space: LedgerRow({
          ...base.space.data,
          'modules': {'ledger': lockedBy == 'permission' ? 'read' : 'write'},
        }),
        records: base.records,
        accounts: base.accounts,
        pending: [
          if (lockedBy == 'sending')
            LedgerRow({
              'state': 'sending',
              'entity_ids': ['record:record-a'],
            }),
        ],
      );
      await pumpC3(
        tester,
        child: LedgerRecordCard(
          snapshot: data,
          row: data.records.first,
          onEdit: () {},
          onVoid: () {},
        ),
      );
      for (final label in ['编辑', '撤销']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull);
      }
    });
  }
  test('record_status_priority_and_optional_reply_version', () {
    final row = c3Snapshot('card_recorded').records.first;
    expect(recordDisplay(allowed: false, row: row), RecordDisplay.denied);
    expect(recordDisplay(allowed: true, row: null), RecordDisplay.loading);
    expect(
      recordDisplay(
        allowed: true,
        row: LedgerRow({
          ...row.data,
          'status': 'voided',
        }, syncState: 'conflict'),
      ),
      RecordDisplay.conflict,
    );
    expect(
      recordDisplay(
        allowed: true,
        row: LedgerRow({...row.data, 'status': 'voided'}, syncState: 'pending'),
        failed: true,
      ),
      RecordDisplay.voided,
    );
    expect(
      recordDisplay(allowed: true, row: row, versionAtReply: 1),
      RecordDisplay.changed,
    );
  });
}
