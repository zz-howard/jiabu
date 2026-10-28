import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';

import '../support/ledger_fixture.dart';

void main() {
  test('history_never_returns_other_space_records_or_options', () {
    final a = ledgerFixture();
    final b = ledgerFixture(spaceId: 'fictional-space-b');
    final data = LedgerSnapshot(
      spaceId: a.spaceId,
      space: a.space,
      accounts: a.accounts,
      records: [...a.records, ...b.records],
    );
    expect(filterHistory(data, const HistoryFilter()).length, a.records.length);
    expect(
      filterHistory(
        data,
        const HistoryFilter(account: 'real-b'),
      ).every((r) => r.text('space_id') == a.spaceId),
      isTrue,
    );
  });
  test('history_all_filters_and_combination', () {
    final base = ledgerFixture();
    final data = LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: base.accounts,
      members: base.members,
      tags: [
        LedgerRow({'id': 'tag-a', 'name': '虚构标签', 'space_id': base.spaceId}),
      ],
      records: [
        for (final r in base.records)
          LedgerRow({
            ...r.data,
            if (r.id == 'expense-a') 'tag_ids': ['tag-a'],
          }),
      ],
    );
    expect(
      filterHistory(data, const HistoryFilter(member: 'member-a')).length,
      6,
    );
    expect(
      filterHistory(
        data,
        const HistoryFilter(account: 'real-b'),
      ).map((r) => r.id),
      contains('transfer-a'),
    );
    expect(
      filterHistory(data, const HistoryFilter(tag: 'tag-a')).single.id,
      'expense-a',
    );
    expect(
      filterHistory(data, const HistoryFilter(kind: 'income')).single.id,
      'income-a',
    );
    expect(
      filterHistory(
        data,
        const HistoryFilter(from: '2026-10-02', through: '2026-10-02'),
      ).single.id,
      'expense-a',
    );
    expect(
      filterHistory(
        data,
        const HistoryFilter(
          text: '午餐',
          member: 'member-a',
          account: 'real-a',
          tag: 'tag-a',
          kind: 'expense',
          from: '2026-10-02',
          through: '2026-10-02',
        ),
      ).single.id,
      'expense-a',
    );
    for (final query in ['账户A', '虚构标签', '支出']) {
      expect(
        filterHistory(
          data,
          HistoryFilter(text: query, labels: const {'expense': '支出'}),
        ).map((r) => r.id),
        contains('expense-a'),
      );
    }
    expect(
      filterHistory(data, const HistoryFilter(text: 'no matches')),
      isEmpty,
    );
  });
}
