import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/repositories/ledger_repository.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/record_details.dart';

import '../support/c3_harness.dart';
import '../support/sync_harness.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, '保存');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpDatabaseFrames(tester);
}

void main() {
  late SyncHarness h;
  late LocalLedgerRepository repo;
  // setUp runs outside testWidgets' fake clock: temporary-directory creation
  // and SQLite initialization must be allowed to finish in real time.
  setUp(() async {
    h = await SyncHarness.create();
    repo = LocalLedgerRepository(h.store, h.mutations, h.records, h.conflicts);
  });
  tearDown(() => h.close());
  testWidgets('zero_setup_creates_accounts_plan_and_four_manual_record_kinds', (
    tester,
  ) async {
    try {
      await pumpC3(
        tester,
        repository: repo,
        settle: false,
        child: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => openAccountForm(context, 's'),
                child: const Text('accounts'),
              ),
              TextButton(
                onPressed: () => openManualEntry(context, 's'),
                child: const Text('manual'),
              ),
            ],
          ),
        ),
      );
      for (final spec in [
        ('用户A银行卡', 'real', '100.00'),
        ('用户B银行卡', 'real', '0'),
        ('虚构日常', 'purpose', '50.00'),
        ('虚构备用', 'purpose', '20.00'),
      ]) {
        await tester.tap(find.text('accounts'));
        await pumpDatabaseFrames(tester);
        if (spec.$2 == 'purpose') {
          await tester.tap(find.widgetWithText(ChoiceChip, '用途账户'));
          await pumpDatabaseFrames(tester);
        }
        await fill(tester, '名称', spec.$1);
        await fill(tester, '起始余额', spec.$3);
        await save(tester);
        expect(tester.takeException(), isNull);
      }
      var snapshot = (await tester.runAsync(() => repo.snapshot('s')))!;
      final p = snapshot.accounts.singleWhere((a) => a.text('name') == '虚构日常');
      await pumpC3(
        tester,
        repository: repo,
        settle: false,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => openPlan(context, 's', p.id),
            child: const Text('plan'),
          ),
        ),
      );
      await tester.tap(find.text('plan'));
      await pumpDatabaseFrames(tester);
      await fill(tester, '金额', '10');
      await save(tester);
      snapshot = (await tester.runAsync(() => repo.snapshot('s')))!;
      expect(snapshot.plans.single.number('day_of_month'), 1);
      for (final kind in ['expense', 'income', 'transfer', 'reallocation']) {
        await pumpC3(
          tester,
          repository: repo,
          settle: false,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => openManualEntry(context, 's'),
              child: const Text('manual'),
            ),
          ),
        );
        await tester.tap(find.text('manual'));
        await pumpDatabaseFrames(tester);
        await tester.tap(find.byKey(ValueKey('kind-$kind')));
        await pumpDatabaseFrames(tester);
        await fill(tester, '金额', kind == 'income' ? '5' : '1');
        final names = kind == 'reallocation'
            ? ['虚构备用', '虚构日常']
            : kind == 'transfer'
            ? ['用户A银行卡', '用户B银行卡']
            : ['用户A银行卡'];
        // Both account-choice blocks contain the same names.
        // The first block selects the source; the second the destination.
        for (var i = 0; i < names.length; i++) {
          final chips = find.widgetWithText(ChoiceChip, names[i]);
          await tester.ensureVisible(chips.at(i == 0 ? 0 : 1));
          await tester.tap(chips.at(i == 0 ? 0 : 1));
          await tester.pump();
        }
        if (kind == 'expense') {
          final chip = find.widgetWithText(ChoiceChip, '虚构日常');
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pump();
        }
        await save(tester);
      }
      snapshot = (await tester.runAsync(() => repo.snapshot('s')))!;
      expect(snapshot.records.map((r) => r.text('kind')).toSet(), {
        'expense',
        'income',
        'transfer',
        'reallocation',
      });
      final balances = (ledgerBalances(snapshot) as Ok<Map<String, int>>).value;
      expect(
        balances[snapshot.accounts
            .singleWhere((a) => a.text('name') == '用户A银行卡')
            .id],
        10300,
      );
      expect(balances[p.id], 5000);
      final queued = (await tester.runAsync(() => h.store.outbox('s')))!;
      expect(queued.length, 9);
      await pumpC3(
        tester,
        repository: repo,
        settle: false,
        child: OverviewPage(snapshot: snapshot),
      );
      expect(find.text('待处理'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDatabaseFrames(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  testWidgets('refund_form_rejects_excess_and_expense_void_explains_refunds', (
    tester,
  ) async {
    try {
      await tester.runAsync(() async {
        for (final pair in [('a', 'real'), ('p', 'purpose')]) {
          await h.store.putEntity('s', 'account', {
            'id': pair.$1,
            'space_id': 's',
            'kind': pair.$2,
            'name': pair.$1 == 'a' ? '虚构银行卡' : '虚构用途',
            'opening_balance_minor': 1000,
            'version': 1,
          });
        }
        await h.seed('parent');
        await h.store.putEntity('s', 'record', {
          ...sampleRecord('refund', amount: 30),
          'kind': 'refund',
          'refund_of_id': 'parent',
        });
      });
      await pumpC3(
        tester,
        repository: repo,
        settle: false,
        child: const SingleChildScrollView(
          child: RecordForm(
            spaceId: 's',
            initial: {
              'kind': 'refund',
              'refund_of_id': 'parent',
              'account_id': 'a',
              'purpose_id': 'p',
              'occurred_on': '2026-10-28',
            },
          ),
        ),
      );
      await fill(tester, '金额', '0.71');
      await save(tester);
      expect(find.text('退款金额超过可退余额'), findsOneWidget);
      expect(await tester.runAsync(() => h.store.outbox('s')), isEmpty);
      await pumpC3(
        tester,
        repository: repo,
        settle: false,
        child: const RecordActions(spaceId: 's', recordId: 'parent'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, '撤销'));
      await pumpDatabaseFrames(tester);
      await tester.tap(find.widgetWithText(FilledButton, '撤销'));
      await pumpDatabaseFrames(tester);
      expect(find.textContaining('请先逐笔撤销退款'), findsOneWidget);
      expect(await tester.runAsync(() => h.store.outbox('s')), isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDatabaseFrames(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
