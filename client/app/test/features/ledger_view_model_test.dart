import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';

import '../support/ledger_fake.dart';

void main() {
  test(
    'ledger_view_model_filters_reports_errors_and_serializes_commands',
    () async {
      final fake = FakeLedgerRepository(c3Snapshot('overview_accounts'));
      final container = ProviderContainer(
        overrides: [ledgerRepositoryProvider.overrideWithValue(fake)],
      );
      final subscription = container.listen(
        ledgerViewModelProvider('fictional-c3'),
        (_, next) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await fake.changes.close();
      });
      final model = container.read(
        ledgerViewModelProvider('fictional-c3').notifier,
      )..filter(const HistoryFilter(kind: 'expense'));
      expect(
        container.read(ledgerViewModelProvider('fictional-c3')).filter.kind,
        'expense',
      );
      final gate = Completer<Result<String>>();
      final command = model.command((_) => gate.future);
      expect(
        container.read(ledgerViewModelProvider('fictional-c3')).busy,
        isTrue,
      );
      expect(await model.command((_) async => const Ok('second')), isFalse);
      gate.complete(const Failure('refund_exceeds_original'));
      expect(await command, isFalse);
      expect(
        container.read(ledgerViewModelProvider('fictional-c3')).error,
        'refund_exceeds_original',
      );
    },
  );
  test(
    'form_switch_discards_irrelevant_account_fields_but_keeps_amount_and_date',
    () {
      final container = ProviderContainer();
      final subscription = container.listen(
        ledgerFormViewModelProvider('s', 'manual'),
        (_, next) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      container.read(ledgerFormViewModelProvider('s', 'manual').notifier)
        ..initialize({
          'kind': 'expense',
          'amount_text': '12.00',
          'occurred_on': '2026-10-28',
          'account_id': 'a',
          'purpose_id': 'p',
        })
        ..kind('reallocation');
      final state = container.read(ledgerFormViewModelProvider('s', 'manual'));
      expect(state.values['kind'], 'reallocation');
      expect(state.values['amount_text'], '12.00');
      expect(state.values.containsKey('account_id'), isFalse);
      expect(state.values.containsKey('purpose_id'), isFalse);
    },
  );
  test('separate_space_families_do_not_share_filters', () {
    final fake = FakeLedgerRepository(c3Snapshot('overview_accounts'));
    final container = ProviderContainer(
      overrides: [ledgerRepositoryProvider.overrideWithValue(fake)],
    );
    final a = container.listen(
      ledgerViewModelProvider('a'),
      (_, next) {},
      fireImmediately: true,
    );
    final b = container.listen(
      ledgerViewModelProvider('b'),
      (_, next) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      a.close();
      b.close();
      container.dispose();
      await fake.changes.close();
    });
    container
        .read(ledgerViewModelProvider('a').notifier)
        .filter(const HistoryFilter(text: 'fictional'));
    expect(container.read(ledgerViewModelProvider('b')).filter.text, isEmpty);
  });
}
