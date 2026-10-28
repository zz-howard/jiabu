import 'dart:convert';
import 'dart:io';

import 'package:jiabu/domain/ledger.dart';

Map<String, Object?> readLedgerFixture() =>
    jsonDecode(File('test/fixtures/ledger/c3_ledger.json').readAsStringSync())
        as Map<String, Object?>;

LedgerSnapshot ledgerFixture({
  bool allocation = true,
  String spaceId = 'fictional-space',
}) {
  final json = readLedgerFixture();
  List<LedgerRow> rows(String key) => (json[key]! as List<Object?>)
      .map(
        (value) => LedgerRow(
          {'space_id': spaceId, ...(value! as Map<String, Object?>)},
          syncState:
              (value as Map<String, Object?>)['sync_state'] as String? ??
              'synced',
        ),
      )
      .toList();
  return LedgerSnapshot(
    spaceId: spaceId,
    space: LedgerRow({
      'id': spaceId,
      'space_id': spaceId,
      'name': '虚构空间A',
      'currency': 'CNY',
      'timezone': 'Asia/Singapore',
      'accent_color': 'pine',
      'modules': {'ledger': 'write'},
    }),
    accounts: rows('accounts'),
    records: [
      for (final row in rows('operations'))
        LedgerRow({
          'status': 'active',
          'tag_ids': <String>[],
          'attachments': <String>[],
          'version': 1,
          'created_by_member_id': 'member-a',
          ...row.data,
        }),
      if (allocation)
        LedgerRow({
          'id': 'allocation-a',
          'space_id': spaceId,
          'kind': 'allocation',
          'status': 'active',
          'amount_minor': 4000,
          'purpose_id': 'purpose-a',
          'occurred_on': '2026-10-05',
          'tag_ids': <String>[],
          'attachments': <String>[],
        }),
    ],
    members: [
      LedgerRow({
        'id': 'member-a',
        'space_id': spaceId,
        'display_name': '用户A',
        'status': 'active',
      }),
    ],
  );
}
