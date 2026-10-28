import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';
import '../support/ledger_fake.dart';

void main() {
  testWidgets('manual_form_defaults_to_expense_and_switches_all_four_shapes', (
    tester,
  ) async {
    final snapshot = c3Snapshot('manual_expense');
    final repo = FakeLedgerRepository(snapshot);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: SingleChildScrollView(
        child: RecordForm(spaceId: snapshot.spaceId),
      ),
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('kind-expense')))
          .selected,
      isTrue,
    );
    expect(find.text('付款账户'), findsOneWidget);
    expect(find.text('用途'), findsOneWidget);
    for (final kind in ['income', 'transfer', 'reallocation', 'expense']) {
      await tester.tap(find.byKey(ValueKey('kind-$kind')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.byKey(ValueKey('kind-$kind'))).selected,
        isTrue,
      );
      if (kind == 'transfer' || kind == 'reallocation') {
        expect(find.text('转出方'), findsOneWidget);
        expect(find.text('转入方'), findsOneWidget);
      }
      if (kind == 'income') {
        expect(find.text('收款账户'), findsOneWidget);
        expect(find.text('用途'), findsNothing);
      }
    }
    await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('请检查必填项、金额和日期'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });
  for (final choice in ['server', 'mine']) {
    testWidgets('conflict_two_versions_choose_$choice', (tester) async {
      final data = c3Snapshot('conflict');
      final repo = FakeLedgerRepository(data);
      addTearDown(repo.changes.close);
      await pumpC3(
        tester,
        repository: repo,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                openConflict(context, data.spaceId, 'record', 'record-a'),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('服务器版本'), findsOneWidget);
      expect(find.text('我的版本'), findsOneWidget);
      final target = find.widgetWithText(
        choice == 'server' ? OutlinedButton : FilledButton,
        choice == 'server' ? '用服务器的' : '用我的',
      );
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(repo.calls, ['resolve:$choice']);
    });
  }
  testWidgets('server_voided_only_offers_acknowledge_and_explicit_restore', (
    tester,
  ) async {
    final data = c3Snapshot('conflict_voided');
    final repo = FakeLedgerRepository(data);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              openConflict(context, data.spaceId, 'record', 'record-a'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('这笔已被撤销'), findsOneWidget);
    expect(find.text('用我的'), findsNothing);
    final restore = find.widgetWithText(FilledButton, '恢复并改成我的版本');
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(repo.calls, ['resolve:restore']);
  });
  testWidgets('failed_operation_stays_visible_on_voided_card', (tester) async {
    final base = c3Snapshot('card_voided');
    final data = LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: base.accounts,
      records: base.records,
      members: base.members,
      pending: [
        LedgerRow({
          'id': 'op',
          'entity_ids': ['record:record-a'],
          'state': 'failed',
        }),
      ],
    );
    final repo = FakeLedgerRepository(data);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: LedgerRecordCard(snapshot: data, row: data.records.first),
    );
    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('上传失败'), findsOneWidget);
    expect(find.text('已撤销 · 余额已恢复'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
  testWidgets('archived_account_balance_has_no_impossible_transfer_action', (
    tester,
  ) async {
    final base = c3Snapshot('overview_accounts');
    final account = LedgerRow({
      ...base.accounts.first.data,
      'archived_at': '2026-10-28',
    });
    await pumpC3(
      tester,
      child: AccountBalanceTile(snapshot: base, account: account, balance: 100),
    );
    expect(find.textContaining('当前服务端暂不支持从归档账户转走余额'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
  testWidgets('archived_account_hides_plan_even_before_plan_pull', (
    tester,
  ) async {
    final base = c3Snapshot('plan_enabled');
    final data = LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: [
        LedgerRow({...base.accounts[2].data, 'archived_at': '2026-10-28'}),
      ],
      plans: base.plans,
    );
    final repo = FakeLedgerRepository(data);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: AccountsPage(snapshot: data),
    );
    expect(find.text('每月拨入计划'), findsNothing);
  });
  testWidgets('manual_tag_creation_is_expanded_only_by_new_chip', (
    tester,
  ) async {
    final data = c3Snapshot('manual_expense');
    final repo = FakeLedgerRepository(data);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: SingleChildScrollView(child: RecordForm(spaceId: data.spaceId)),
    );
    final input = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '新建标签',
    );
    expect(input, findsNothing);
    expect(find.widgetWithText(TextButton, '新建标签'), findsNothing);
    final add = find.widgetWithText(ActionChip, '+ 新建');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
  });
  testWidgets('details_footer_equal_width_actions_and_refund_above', (
    tester,
  ) async {
    await pumpC3(tester, state: 'details');
    final edit = tester.getRect(find.widgetWithText(FilledButton, '编辑'));
    final undo = tester.getRect(find.widgetWithText(OutlinedButton, '撤销'));
    final refund = tester.getRect(find.widgetWithText(TextButton, '退款'));
    expect(edit.width, closeTo(undo.width, 0.1));
    expect(edit.height, 48);
    expect(undo.height, 48);
    expect(edit.top, undo.top);
    expect(refund.bottom, lessThanOrEqualTo(edit.top));
    expect(find.text('编辑'), findsOneWidget);
  });
  for (final hasReserve in [true, false]) {
    testWidgets('negative_balance_prefills_reallocation reserve=$hasReserve', (
      tester,
    ) async {
      final base = c3Snapshot('overview_negative');
      final data = LedgerSnapshot(
        spaceId: base.spaceId,
        space: base.space,
        accounts: base.accounts
            .where((a) => hasReserve || !a.flag('is_reserve'))
            .toList(),
        records: base.records,
        tags: base.tags,
        members: base.members,
      );
      final repo = FakeLedgerRepository(data);
      addTearDown(repo.changes.close);
      await pumpC3(
        tester,
        repository: repo,
        child: AccountBalanceTile(
          snapshot: data,
          account: data.accounts.singleWhere((a) => a.id == 'purpose-a'),
          balance: -1200,
        ),
      );
      expect(find.text('虚构日常 当前为 −¥12.00'), findsOneWidget);
      expect(find.textContaining('余额须先清零'), findsNothing);
      final action = find.widgetWithText(
        FilledButton,
        hasReserve ? '从备用金调拨 ¥12' : '去调拨',
      );
      expect(tester.getSize(action).height, greaterThanOrEqualTo(46));
      await tester.tap(action);
      await tester.pumpAndSettle();
      final form = tester.widget<RecordForm>(find.byType(RecordForm));
      expect(form.initial['kind'], 'reallocation');
      expect(form.initial['to_purpose_id'], 'purpose-a');
      expect(form.initial['purpose_id'], hasReserve ? 'purpose-b' : null);
      expect(form.initial['amount_text'], hasReserve ? '12.00' : null);
    });
  }
  testWidgets('allocation_plan_shows_concise_day_rule_without_iana_zone', (
    tester,
  ) async {
    await pumpC3(tester, state: 'plan_enabled');
    expect(find.textContaining('小月按月末'), findsOneWidget);
    expect(find.textContaining('首次设置从下一个拨入日开始'), findsOneWidget);
    expect(find.textContaining('Asia/Singapore'), findsNothing);
    expect(find.textContaining('每月最多一次'), findsNothing);
  });
  testWidgets('history_amount_is_right_of_title_on_the_same_row', (
    tester,
  ) async {
    final data = c3Snapshot('history_grouped');
    await pumpC3(
      tester,
      child: LedgerHistoryRow(snapshot: data, row: data.records.first),
    );
    final title = tester.getRect(find.text('虚构午餐'));
    final amount = tester.getRect(find.byType(AmountText));
    expect(amount.left, greaterThan(title.right));
    expect(amount.top, closeTo(title.top, 0.1));
    expect(tester.takeException(), isNull);
  });
  for (final kind in ['transfer', 'reallocation']) {
    for (final editing in [false, true]) {
      testWidgets('destination_excludes_source_and_clears_collision'
          '_${kind}_editing=$editing', (tester) async {
        final data = c3Snapshot('manual_expense');
        final repo = FakeLedgerRepository(data);
        addTearDown(repo.changes.close);
        final real = kind == 'transfer';
        final from = real ? 'account_id' : 'purpose_id';
        final to = real ? 'to_account_id' : 'to_purpose_id';
        final a = real ? 'real-a' : 'purpose-a';
        final b = real ? 'real-b' : 'purpose-b';
        final aName = real ? '虚构银行卡A' : '虚构日常';
        final bName = real ? '虚构银行卡B' : '虚构备用金';
        final values = {
          ...data.records.first.data,
          'kind': kind,
          from: a,
          to: b,
        };
        await pumpC3(
          tester,
          repository: repo,
          child: SingleChildScrollView(
            child: RecordForm(
              spaceId: data.spaceId,
              record: editing ? LedgerRow(values) : null,
              initial: editing ? const {} : values,
            ),
          ),
        );
        final sources = find.byKey(ValueKey('account-choices-$from'));
        final destinations = find.byKey(ValueKey('account-choices-$to'));
        Finder option(Finder block, String name) => find.descendant(
          of: block,
          matching: find.widgetWithText(ChoiceChip, name),
        );
        final sourceA = option(sources, aName);
        await tester.ensureVisible(sourceA);
        await tester.tap(sourceA);
        await tester.pumpAndSettle();
        expect(option(destinations, aName), findsNothing);
        expect(
          tester.widget<ChoiceChip>(option(destinations, bName)).selected,
          isTrue,
        );
        final sourceB = option(sources, bName);
        await tester.ensureVisible(sourceB);
        await tester.tap(sourceB);
        await tester.pumpAndSettle();
        expect(option(destinations, bName), findsNothing);
        final destinationA = option(destinations, aName);
        expect(tester.widget<ChoiceChip>(destinationA).selected, isFalse);
        expect(
          find.descendant(
            of: destinations,
            matching: find.byWidgetPredicate(
              (widget) => widget is ChoiceChip && widget.selected,
            ),
          ),
          findsNothing,
        );
      });
    }
  }
  for (final kind in ['expense', 'income', 'transfer', 'reallocation']) {
    for (final editing in [false, true]) {
      testWidgets('tags_visibility_and_submission'
          '_${kind}_editing=$editing', (tester) async {
        final data = c3Snapshot('manual_expense');
        final repo = FakeLedgerRepository(data);
        addTearDown(repo.changes.close);
        final values = {
          ...data.records.first.data,
          'kind': kind,
          'amount_text': '1.00',
          if (kind == 'transfer') 'to_account_id': 'real-b',
          if (kind == 'reallocation') 'to_purpose_id': 'purpose-b',
          'tag_ids': ['tag-a'],
        };
        final originalRow = LedgerRow({...values}..remove('amount_text'));
        if (editing) {
          repo.snapshot = LedgerSnapshot(
            spaceId: data.spaceId,
            space: data.space,
            accounts: data.accounts,
            records: [originalRow],
            tags: data.tags,
            members: data.members,
          );
        }
        await pumpC3(
          tester,
          repository: repo,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => editing
                  ? openEditRecord(context, data.spaceId, originalRow)
                  : openManualEntry(context, data.spaceId, initial: values),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final hasTags = kind == 'expense' || kind == 'income';
        expect(find.text('标签'), hasTags ? findsOneWidget : findsNothing);
        expect(find.byType(FilterChip), hasTags ? findsWidgets : findsNothing);
        expect(
          find.widgetWithText(ActionChip, '+ 新建'),
          hasTags ? findsOneWidget : findsNothing,
        );
        if (editing) {
          final note = find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == '说明',
          );
          await tester.ensureVisible(note);
          await tester.enterText(note, '用户A修改备注');
          await tester.pump();
        }
        final save = find.widgetWithText(FilledButton, '保存');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.recordWrites, hasLength(1));
        final submitted = repo.recordWrites.single;
        if (hasTags && !editing) {
          expect(submitted['tag_ids'], ['tag-a']);
        } else if (editing) {
          expect(submitted.containsKey('tag_ids'), isFalse);
          expect(values['tag_ids'], ['tag-a']);
        } else {
          expect(submitted['tag_ids'], isEmpty);
        }
      });
    }
  }
}
