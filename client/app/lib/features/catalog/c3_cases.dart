import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/ledger_ui_state.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/main_frame.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Exhaustive C3 visual states with fictional data. No AppRuntime/IO is used.
const c3States = <String>[
  'shell_chat',
  'shell_overview',
  'shell_history',
  'settings',
  'overview_empty',
  'overview_accounts',
  'overview_negative',
  'overview_pending',
  'overview_failure',
  'overview_conflict',
  'overview_busy',
  'history_empty',
  'history_grouped',
  'history_24',
  'history_search',
  'history_filters',
  'card_denied',
  'card_loading',
  'card_recorded',
  'card_pending',
  'card_failed',
  'card_voided',
  'card_conflict',
  'card_changed',
  'card_api_key',
  'card_left',
  'details',
  'details_image',
  'details_audit',
  'edit',
  'conflict',
  'conflict_voided',
  'manual_expense',
  'manual_income',
  'manual_transfer',
  'manual_reallocation',
  'manual_invalid',
  'refund',
  'refund_limit',
  'void_refunds',
  'accounts_empty',
  'accounts',
  'accounts_long_6',
  'account_real',
  'account_purpose',
  'account_rename',
  'archive_positive',
  'archive_negative',
  'plan_new',
  'plan_enabled',
  'plan_disabled',
  'plan_pending',
];
const c3EnglishRepresentatives = <String>[
  'shell_overview',
  'settings',
  'overview_accounts',
  'history_grouped',
  'card_recorded',
  'details_audit',
  'edit',
  'conflict',
  'manual_expense',
  'refund',
  'accounts',
  'account_real',
  'plan_enabled',
];

LedgerSnapshot c3Snapshot(String state, {String accent = 'pine'}) {
  const s = 'fictional-c3';
  final empty = state.endsWith('_empty');
  final accountFixtures = state == 'accounts_long_6'
      ? const [
          ('real-a', 'real', '招商银行信用卡（虚构家庭日常共同支出账户）'),
          ('real-b', 'real', '中国银行长期储蓄账户（虚构）'),
          ('purpose-a', 'purpose', '孩子教育与课外活动专项预算（虚构）'),
          ('purpose-b', 'purpose', '家庭紧急备用金与医疗储备（虚构）'),
          ('purpose-c', 'purpose', '年度旅行和探亲交通预算（虚构）'),
          ('purpose-d', 'purpose', '居家维修及大件家电更新（虚构）'),
        ]
      : const [
          ('real-a', 'real', '虚构银行卡A'),
          ('real-b', 'real', '虚构银行卡B'),
          ('purpose-a', 'purpose', '虚构日常'),
          ('purpose-b', 'purpose', '虚构备用金'),
        ];
  final accounts = <LedgerRow>[
    for (final item in accountFixtures)
      LedgerRow({
        'id': item.$1,
        'space_id': s,
        'name': item.$3,
        'kind': item.$2,
        'opening_balance_minor':
            state == 'overview_negative' && item.$1 == 'purpose-a'
            ? 0
            : state == 'overview_busy'
            ? 2000000
            : 10000,
        'opening_on': '2026-10-01',
        'is_reserve': item.$1 == 'purpose-b',
        'version': 1,
      }),
  ];
  final voided = state == 'card_voided' || state == 'conflict_voided';
  final conflict = state.contains('conflict');
  final pending = state == 'card_pending' || state == 'overview_pending';
  final row = LedgerRow(
    {
      'id': 'record-a',
      'space_id': s,
      'kind': 'expense',
      'amount_minor': 1200,
      'account_id': 'real-a',
      'purpose_id': 'purpose-a',
      'tag_ids': ['tag-a'],
      'attachments': state == 'details_image'
          ? ['fictional-image']
          : <String>[],
      'status': voided ? 'voided' : 'active',
      'void_reason': voided ? 'user' : null,
      'version': 2,
      'note': '虚构午餐',
      'occurred_on': '2026-10-28',
      'created_by_member_id': 'member-a',
    },
    syncState: conflict
        ? 'conflict'
        : pending
        ? 'pending'
        : 'synced',
  );
  return LedgerSnapshot(
    spaceId: s,
    space: LedgerRow({
      'id': s,
      'space_id': s,
      'name': '虚构家庭空间',
      'currency': 'CNY',
      'member_id': 'member-a',
      'join_epoch': 1,
      'timezone': 'Asia/Singapore',
      'accent_color': accent,
      'modules': {'ledger': 'write'},
    }),
    accounts: empty ? [] : accounts,
    records: empty
        ? []
        : state == 'overview_busy'
        ? [
            for (final item in const [
              ('lunch', 'expense', '虚构午餐', 1200, '2026-10-28'),
              (
                'salary',
                'income',
                '虚构工资（十月，含补贴与奖金，名称较长）',
                1280000,
                '2026-10-26',
              ),
              ('market', 'expense', '虚构买菜', 8650, '2026-10-24'),
              ('move', 'transfer', '', 50000, '2026-10-22'),
              ('refund', 'refund', '虚构退款', 2000, '2026-10-21'),
              ('old', 'expense', '虚构九月房租', 450000, '2026-09-30'),
            ])
              LedgerRow({
                ...row.data,
                'id': 'record-${item.$1}',
                'kind': item.$2,
                'note': item.$3,
                'amount_minor': item.$4,
                'occurred_on': item.$5,
                if (item.$2 == 'transfer') 'to_account_id': 'real-b',
                if (item.$2 == 'refund') 'refund_of_id': 'record-lunch',
              }),
          ]
        : state == 'history_24'
        ? [
            for (var index = 0; index < 24; index++)
              LedgerRow({
                ...row.data,
                'id': 'record-$index',
                'note': '虚构记录 ${index + 1}',
                'amount_minor': 100 + index * 25,
                'occurred_on': '2026-10-${28 - index ~/ 8}',
              }),
          ]
        : [row],
    members: [
      LedgerRow({
        'id': 'member-a',
        'space_id': s,
        'display_name': '用户A',
        'status': state == 'card_left' ? 'left' : 'active',
        if (state == 'card_left') 'left_at': '2026-10-27',
      }),
    ],
    tags: [
      LedgerRow({
        'id': 'tag-a',
        'space_id': s,
        'preset_key': 'dining',
        'name': null,
      }),
    ],
    pending: state == 'card_failed' || state == 'overview_failure' || pending
        ? [
            LedgerRow({
              'id': 'operation-a',
              'entity_ids': ['record:record-a'],
              'state': pending ? 'pending' : 'failed',
              'error': pending ? '' : 'refund_exceeds_original',
            }),
          ]
        : [],
    conflicts: conflict
        ? [
            LedgerRow({
              'entity_kind': 'record',
              'entity_id': 'record-a',
              'mine_json': jsonEncode({
                ...row.data,
                'amount_minor': 1500,
                'status': 'active',
              }),
              'server_status': voided ? 'voided' : 'active',
              'server_version': 2,
            }),
          ]
        : [],
    events: state == 'card_api_key' || state == 'details_audit'
        ? [
            LedgerRow({
              'id': 1,
              'entity_kind': 'record',
              'entity_id': 'record-a',
              'kind': 'create',
              'actor_member_id': 'member-a',
              'at': '2026-10-28T12:00:00Z',
              'via_api_key_id': 'fictional-key',
              'via_api_key_name': '虚构记账脚本',
              'after': row.data,
            }),
            if (state == 'details_audit')
              LedgerRow({
                'id': 2,
                'entity_kind': 'record',
                'entity_id': 'record-a',
                'kind': 'update',
                'at': '2026-10-28T13:00:00Z',
                'actor_member_id': 'member-a',
                'before': {...row.data, 'amount_minor': 1000},
                'after': row.data,
              }),
          ]
        : [],
    plans: state.startsWith('plan_') && state != 'plan_new'
        ? [
            LedgerRow({
              'account_id': 'purpose-a',
              'space_id': s,
              'amount_minor': 2000,
              'day_of_month': 31,
              'enabled': state != 'plan_disabled',
              'next_run_on': '2026-10-31',
              'version': 1,
            }, syncState: state == 'plan_pending' ? 'pending' : 'synced'),
          ]
        : [],
  );
}

class _PreviewViewModel extends LedgerViewModel {
  _PreviewViewModel(this.snapshot, this.preview);
  final LedgerSnapshot snapshot;
  final String preview;
  @override
  LedgerUiState build(String spaceId) => LedgerUiState(
    snapshot: snapshot,
    filter: preview == 'history_search'
        ? const HistoryFilter(text: '虚构')
        : preview == 'history_filters'
        ? const HistoryFilter(kind: 'expense', account: 'real-a')
        : const HistoryFilter(),
  );
}

class _PreviewFormViewModel extends LedgerFormViewModel {
  _PreviewFormViewModel(this.values, {this.error});
  final Map<String, Object?> values;
  final String? error;
  @override
  LedgerFormState build(String spaceId, String formId) =>
      LedgerFormState(values: values, error: error);
}

class _PreviewRepository implements LedgerRepository {
  _PreviewRepository(this.snapshot);
  final LedgerSnapshot snapshot;
  @override
  Stream<LedgerSnapshot> watch(String s) => Stream.value(snapshot);
  @override
  Future<Result<List<int>>> image(
    String s,
    String h, {
    bool download = false,
  }) async => snapshot.records.any((r) => r.strings('attachments').contains(h))
      ? Ok(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
            'AAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
          ),
        )
      : const Failure('image_not_local');
  // Catalog actions are inert; production actions use the real repository.
  @override
  Future<Result<String>> createRecord(String s, Map<String, Object?> v) async =>
      const Failure('catalog');
  @override
  Future<Result<String>> editRecord(
    String s,
    String id,
    Map<String, Object?> v, {
    int? openedVersion,
  }) async => const Failure('catalog');
  @override
  Future<Result<String>> recordStatus(
    String s,
    String id, {
    required bool restore,
  }) async => const Failure('catalog');
  @override
  Future<Result<String>> createAccount(
    String s,
    Map<String, Object?> v,
  ) async => const Failure('catalog');
  @override
  Future<Result<String>> renameAccount(
    String s,
    String id,
    String name,
  ) async => const Failure('catalog');
  @override
  Future<Result<String>> archiveAccount(String s, String id) async =>
      const Failure('catalog');
  @override
  Future<Result<String>> setPlan(
    String s,
    String id,
    Map<String, Object?> v,
  ) async => const Failure('catalog');
  @override
  Future<Result<String>> createTag(String s, String name) async =>
      const Failure('catalog');
  @override
  Future<Result<void>> retry(String s, String id) async =>
      const Failure('catalog');
  @override
  Future<Result<void>> resolve(
    String s,
    String kind,
    String id,
    String choice,
  ) async => const Failure('catalog');
}

class C3Preview extends StatelessWidget {
  const C3Preview({required this.state, this.accent = 'pine', super.key});
  final String state;
  final String accent;
  @override
  Widget build(BuildContext context) {
    final snapshot = c3Snapshot(state, accent: accent);
    const s = snapshotId;
    final kind = state.startsWith('manual_')
        ? state.substring('manual_'.length)
        : 'expense';
    final formValues = <String, Object?>{
      'kind': kind == 'invalid' ? 'expense' : kind,
      'amount_text': state == 'manual_invalid' ? '' : '12.00',
      'occurred_on': '2026-10-28',
      'account_id': 'real-a',
      'purpose_id': 'purpose-a',
      'tag_ids': ['tag-a'],
    };
    return ProviderScope(
      overrides: [
        ledgerClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 28, 12),
        ),
        ledgerPresentationSessionProvider.overrideWithValue((
          partition: 'catalog',
          spaceId: s,
        )),
        ledgerRepositoryProvider.overrideWithValue(
          _PreviewRepository(snapshot),
        ),
        ledgerViewModelProvider(s)
            .overrideWith(() => _PreviewViewModel(snapshot, state)),
        if (state.startsWith('manual_'))
          ledgerFormViewModelProvider(s, 'manual').overrideWith(
            () => _PreviewFormViewModel(
              formValues,
              error: state == 'manual_invalid' ? 'validation_failed' : null,
            ),
          ),
        if (state == 'account_purpose')
          ledgerFormViewModelProvider(s, 'account:new').overrideWith(
            () => _PreviewFormViewModel({
              'kind': 'purpose',
              'name': '虚构用途',
              'opening_text': '100',
              'opening_on': '2026-10-28',
              'is_reserve': false,
            }),
          ),
        if (state == 'refund_limit')
          ledgerFormViewModelProvider(s, 'refund:record-a').overrideWith(
            () => _PreviewFormViewModel({
              ...formValues,
              'kind': 'refund',
              'refund_of_id': 'record-a',
              'amount_text': '99',
            }, error: 'refund_exceeds_original'),
          ),
      ],
      child: Builder(builder: (context) => _body(context, snapshot)),
    );
  }

  static const snapshotId = 'fictional-c3';
  Widget _body(BuildContext context, LedgerSnapshot data) {
    final l = AppLocalizations.of(context);
    final s = data.spaceId;
    if (state.startsWith('shell_')) {
      final tab = switch (state) {
        'shell_chat' => 0,
        'shell_overview' => 1,
        _ => 2,
      };
      return MainFrame(
        title: [l.ledgerChatTitle, l.ledgerOverview, l.ledgerHistory][tab],
        handEnglish: [
          l.handChatEnglish,
          handDateAccent(DateTime(2026, 10, 29)),
          l.handHistoryEnglish,
        ][tab],
        subtitle: [
          l.handChatSubtitleShared,
          l.handSubtitle,
          l.handHistorySubtitle,
        ][tab],
        showMark: tab == 0,
        spaceName: data.space.text('name'),
        accent:
            context.jiabu.colors.spaceAccents[accent] ??
            context.jiabu.colors.primaryText,
        labels: [l.ledgerChat, l.ledgerOverview, l.ledgerHistory],
        selected: state == 'shell_chat'
            ? 0
            : state == 'shell_overview'
            ? 1
            : 2,
        onSelect: (_) {},
        manual: state == 'shell_chat'
            ? null
            : ManualEntryButton(
                label: l.ledgerManual,
                semanticLabel: l.ledgerManualSemantics,
                onPressed: () {},
              ),
        child: switch (state) {
          'shell_overview' => OverviewPage(snapshot: data),
          'shell_history' => HistoryPage(snapshot: data),
          _ => Center(child: Text(l.ledgerChatPlaceholder)),
        },
      );
    }
    if (state.startsWith('overview_')) {
      return OverviewPage(snapshot: data);
    }
    if (state.startsWith('history_')) {
      return HistoryPage(snapshot: data);
    }
    if (state.startsWith('card_')) {
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: LedgerRecordCard(
            snapshot: data,
            row: state == 'card_loading' ? null : data.records.first,
            allowed: state != 'card_denied',
            versionAtReply: state == 'card_changed' ? 1 : null,
            onOpen: () {},
            onEdit: () {},
            onVoid: () {},
            onRestore: () {},
            onRetry: () {},
          ),
        ),
      );
    }
    if (state == 'conflict' || state == 'conflict_voided') {
      return JiabuSheet(
        child: ConflictSheet(
          spaceId: s,
          entityKind: 'record',
          entityId: 'record-a',
        ),
      );
    }
    if (state.startsWith('details')) {
      return JiabuSheet(
        footer: RecordActions(spaceId: s, recordId: 'record-a'),
        child: RecordDetails(spaceId: s, recordId: 'record-a'),
      );
    }
    if (state == 'edit') {
      return JiabuSheet(
        child: RecordForm(spaceId: s, record: data.records.first),
      );
    }
    if (state.startsWith('manual_')) {
      return JiabuSheet(child: RecordForm(spaceId: s));
    }
    if (state.startsWith('refund')) {
      return JiabuSheet(
        child: RecordForm(
          spaceId: s,
          initial: const {
            'kind': 'refund',
            'refund_of_id': 'record-a',
            'occurred_on': '2026-10-28',
          },
        ),
      );
    }
    if (state == 'void_refunds') {
      return JiabuSheet(child: Text(l.ledgerHasRefunds));
    }
    if (state.startsWith('accounts')) {
      return JiabuPageScaffold(
        title: l.ledgerAccounts,
        onBack: () {},
        action: TextButton(onPressed: () {}, child: Text(l.ledgerAddTag)),
        body: AccountsPage(snapshot: data),
      );
    }
    if (state.startsWith('account_')) {
      return JiabuSheet(
        child: AccountForm(
          spaceId: s,
          initialDate: '2026-10-28',
          account: state == 'account_rename' ? data.accounts.first : null,
        ),
      );
    }
    if (state.startsWith('archive_')) {
      return JiabuSheet(
        child: JiabuStack(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            JiabuStackItem.content(child: Text(l.ledgerArchiveGuide)),
            JiabuStackItem.content(
              child: Text(state == 'archive_negative' ? '−¥12.00' : '¥12.00'),
            ),
            JiabuStackItem.action(
              child: FilledButton(
                onPressed: () {},
                child: Text(l.ledgerMoveBalance),
              ),
            ),
          ],
        ),
      );
    }
    if (state.startsWith('plan_')) {
      return JiabuSheet(
        child: AllocationPlanForm(spaceId: s, accountId: 'purpose-a'),
      );
    }
    if (state == 'settings') {
      return SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: JiabuStack(
          children: [
            JiabuStackItem.section(
              child: JiabuSectionHeader(title: l.ledgerSettings),
            ),
            JiabuStackItem.content(
              child: JiabuSettingsGroup(
                children: [
                  JiabuListRow(title: l.ledgerAccounts, showChevron: true),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HandUnderline(
              child: Text(
                l.ledgerSettings,
                style: context.jiabu.type.pageTitle,
              ),
            ),
            Text(l.ledgerAccounts),
          ],
        ),
      ),
    );
  }
}
