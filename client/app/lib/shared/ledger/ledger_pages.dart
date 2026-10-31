import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/ledger_validation.dart';
import 'package:jiabu/domain/money.dart';
import 'package:jiabu/domain/record_presentation.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/ledger_sheet.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/overview_widgets.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu/shared/navigation.dart';
import 'package:jiabu_design/jiabu_design.dart';

class LedgerRoutePage extends ConsumerWidget {
  const LedgerRoutePage({required this.page, super.key});
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(currentLedgerSpaceProvider).asData?.value;
    final l = AppLocalizations.of(context);
    Widget accountsScaffold(Widget body, {LedgerSnapshot? snapshot}) =>
        JiabuPageScaffold(
          title: l.ledgerAccounts,
          onBack: () => popOrGo(context, '/settings'),
          action: snapshot == null
              ? null
              : TextButton(
                  onPressed: snapshot.writable
                      ? () => openAccountForm(context, snapshot.spaceId)
                      : null,
                  child: Text(l.ledgerAddTag),
                ),
          body: body,
        );

    if (space == null) {
      final body = Center(child: Text(l.ledgerNoSpace));
      return page == 'accounts' ? accountsScaffold(body) : body;
    }
    final state = ref.watch(ledgerViewModelProvider(space));
    final snapshot = state.snapshot;
    if (snapshot == null) {
      final body = Center(
        child: Text(
          state.error == null ? l.ledgerLoading : ledgerError(l, state.error!),
        ),
      );
      return page == 'accounts' ? accountsScaffold(body) : body;
    }
    final allowed = const ['read', 'write', 'manage'].contains(
      (snapshot.space.data['modules'] as Map<String, Object?>?)?['ledger'],
    );
    if (!allowed && page != 'chat' && page != 'settings') {
      final body = Center(child: Text(l.ledgerDenied));
      return page == 'accounts' ? accountsScaffold(body) : body;
    }
    return switch (page) {
      'chat' => Center(child: Text(l.ledgerChatPlaceholder)),
      'overview' => OverviewPage(snapshot: snapshot),
      'history' => HistoryPage(snapshot: snapshot),
      'settings' => SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: JiabuStack(
          children: [
            JiabuStackItem.section(
              child: JiabuSectionHeader(title: l.ledgerSettings),
            ),
            JiabuStackItem.content(
              child: JiabuSettingsGroup(
                children: [
                  JiabuListRow(
                    title: l.ledgerAccounts,
                    showChevron: true,
                    onTap: () => context.push<void>('/settings/accounts'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _ => accountsScaffold(
        AccountsPage(snapshot: snapshot),
        snapshot: snapshot,
      ),
    };
  }
}

class OverviewPage extends ConsumerWidget {
  const OverviewPage({required this.snapshot, super.key});
  final LedgerSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final result = ledgerBalances(snapshot);
    final balances = result is Ok<Map<String, int>>
        ? result.value
        : <String, int>{};
    final ok = result is Ok<Map<String, int>>;
    bool has(String kind) =>
        snapshot.accounts.any((a) => a.text('kind') == kind);
    final realTotal = ok ? realAccountsTotal(snapshot, balances) : null;
    final purposeTotal = ok ? purposeAccountsTotal(snapshot, balances) : null;
    // The hero needs its big number: the purpose total when the space has
    // purpose accounts, otherwise the real-money total.
    final heroReady =
        ok &&
        snapshot.accounts.isNotEmpty &&
        (has('purpose') ? purposeTotal != null : realTotal != null);
    final today = ref.watch(ledgerClockProvider)();
    final month = DateFormat('yyyy-MM').format(today);
    final recent = filterHistory(snapshot, const HistoryFilter()).take(5);
    List<LedgerRow> visible(String kind) => [
      for (final a in snapshot.accounts)
        if (a.text('kind') == kind &&
            (!a.archived || (balances[a.id] ?? 0) != 0))
          a,
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.jiabu.spacing.page,
        JiabuSpacing.cardGap,
        context.jiabu.spacing.page,
        JiabuLedgerMetrics.footerClearance,
      ),
      children: [
        JiabuStack(
          children: [
            if (result is Failure<Map<String, int>>)
              JiabuStackItem.captionAfter(
                child: Text(ledgerError(l, result.code)),
              ),
            if (heroReady)
              JiabuStackItem.content(
                child: OverviewSummary(
                  currency: snapshot.currency,
                  purposeTotal: has('purpose') ? purposeTotal : null,
                  realTotal: has('real') ? realTotal : null,
                  monthSpent: monthExpense(snapshot, month),
                ),
              ),
            if (snapshot.accounts.isEmpty)
              JiabuStackItem.content(
                child: JiabuEmptyState(
                  message: HandText(
                    l.handNothingHere,
                    textAlign: TextAlign.center,
                  ),
                  actionLabel: l.ledgerNewAccount,
                  onAction: () => context.push<void>('/settings/accounts'),
                ),
              ),
            if (ok)
              for (final kind in ['purpose', 'real'])
                if (visible(kind).isNotEmpty) ...[
                  JiabuStackItem.section(
                    child: JiabuSectionHeader(
                      title: kind == 'real' ? l.ledgerReal : l.ledgerPurpose,
                      highlighted: true,
                    ),
                  ),
                  if (kind == 'purpose') ...[
                    JiabuStackItem.captionBefore(
                      child: Text(
                        l.ledgerPurposeHint,
                        key: const Key('overview-purpose-hint'),
                        style: context.jiabu.type.secondary.copyWith(
                          color: context.jiabu.colors.ink2,
                        ),
                      ),
                    ),
                    JiabuStackItem.content(
                      child: OverviewPurposeGrid(
                        snapshot: snapshot,
                        accounts: visible(kind),
                        balances: balances,
                      ),
                    ),
                  ] else
                    JiabuStackItem.content(
                      child: JiabuSettingsGroup(
                        children: [
                          for (final account in visible(kind))
                            OverviewAccountRow(
                              snapshot: snapshot,
                              account: account,
                              balance: balances[account.id] ?? 0,
                            ),
                        ],
                      ),
                    ),
                  for (final account in visible(kind))
                    if (account.archived || (balances[account.id] ?? 0) < 0)
                      JiabuStackItem.content(
                        child: AccountBalanceNote(
                          snapshot: snapshot,
                          account: account,
                          balance: balances[account.id] ?? 0,
                        ),
                      ),
                ],
            JiabuStackItem.section(
              child: JiabuSectionHeader(
                title: l.ledgerPending,
                highlighted: true,
              ),
            ),
            JiabuStackItem.content(child: PendingItems(snapshot: snapshot)),
            if (recent.isNotEmpty) ...[
              JiabuStackItem.section(
                child: JiabuSectionHeader(
                  title: l.ledgerRecent,
                  highlighted: true,
                ),
              ),
              JiabuStackItem.content(
                child: JiabuSettingsGroup(
                  children: [
                    for (final row in recent)
                      OverviewRecentRow(snapshot: snapshot, row: row),
                  ],
                ),
              ),
            ],
            // C6 extension point: family summary. No card in this slice.
          ],
        ),
      ],
    );
  }
}

Widget liveRecordCard(
  BuildContext context,
  WidgetRef ref,
  LedgerSnapshot snapshot,
  LedgerRow row, {
  int? versionAtReply,
}) => LedgerRecordCard(
  snapshot: snapshot,
  row: row,
  versionAtReply: versionAtReply,
  onOpen: () => row.syncState == 'conflict'
      ? openConflict(context, snapshot.spaceId, 'record', row.id)
      : openRecordDetails(context, snapshot.spaceId, row.id),
  onEdit: snapshot.writable
      ? () => openEditRecord(context, snapshot.spaceId, row)
      : null,
  onVoid: snapshot.writable
      ? () => changeRecordStatus(
          context,
          ref,
          snapshot.spaceId,
          row,
          restore: false,
        )
      : null,
  onRestore: snapshot.writable
      ? () => changeRecordStatus(
          context,
          ref,
          snapshot.spaceId,
          row,
          restore: true,
        )
      : null,
  onRetry: () {
    unawaited(
      ref
          .read(ledgerViewModelProvider(snapshot.spaceId).notifier)
          .command<void>((repo) async {
            for (final op
                in snapshot
                    .operations('record', row.id)
                    .where((op) => op.text('state') == 'failed')) {
              final result = await repo.retry(snapshot.spaceId, op.id);
              if (result is Failure<void>) {
                return result;
              }
            }
            return const Ok<void>(null);
          }),
    );
  },
);

/// What sits under an account balance row: the archived-account notice or the
/// negative-balance reminder with its fix-it action. Empty for healthy rows.
class AccountBalanceNote extends StatelessWidget {
  const AccountBalanceNote({
    required this.snapshot,
    required this.account,
    required this.balance,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow account;
  final int balance;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final purpose = account.text('kind') == 'purpose';
    final reserve = snapshot.accounts
        .where(
          (a) =>
              a.text('kind') == 'purpose' &&
              a.flag('is_reserve') &&
              !a.archived &&
              a.id != account.id,
        )
        .firstOrNull;
    if (account.archived && balance != 0) {
      return Text('${account.text('name')} · ${l.ledgerArchiveUnavailable}');
    }
    if (balance >= 0) {
      return const SizedBox.shrink();
    }
    return NegativeBalanceNote(
      title: l.ledgerNegativeTitle(
        account.text('name'),
        formatMinor(balance, snapshot.currency, l.localeName),
      ),
      body: purpose ? l.ledgerNegativeBody : l.ledgerNegativeTransferBody,
      action: BalanceNoteButton(
        label: purpose && reserve != null
            ? l.ledgerReserveCover(
                formatCompactMinor(-balance, snapshot.currency, l.localeName),
              )
            : purpose
            ? l.ledgerGoReallocate
            : l.ledgerTransfer,
        onPressed: !snapshot.writable
            ? null
            : () {
                unawaited(
                  openManualEntry(
                    context,
                    snapshot.spaceId,
                    initial: {
                      'kind': purpose ? 'reallocation' : 'transfer',
                      if (purpose)
                        'to_purpose_id': account.id
                      else
                        'to_account_id': account.id,
                      if (purpose && reserve != null) ...{
                        'purpose_id': reserve.id,
                        'amount_text': minorInput(-balance, snapshot.currency),
                      },
                    },
                  ),
                );
              },
      ),
    );
  }
}

class PendingItems extends ConsumerWidget {
  const PendingItems({required this.snapshot, super.key});
  final LedgerSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return JiabuStack(
      children: [
        if (snapshot.pending.isEmpty && snapshot.conflicts.isEmpty)
          JiabuStackItem.content(child: Text(l.ledgerNoPending)),
        for (final op in snapshot.pending)
          JiabuStackItem.content(
            child: PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    operationTitle(snapshot, op, l),
                    style: context.jiabu.type.listTitle,
                  ),
                  Text(
                    op.text('state') == 'failed'
                        ? l.ledgerFailed
                        : op.text('state') == 'blocked'
                        ? l.ledgerPendingBlocked
                        : l.ledgerUpload,
                  ),
                  if (op.text('error').isNotEmpty)
                    Text(ledgerError(l, op.text('error'))),
                  for (final entity in op.strings('entity_ids'))
                    if (entity.startsWith('record:'))
                      TextButton(
                        onPressed: () => openRecordDetails(
                          context,
                          snapshot.spaceId,
                          entity.substring('record:'.length),
                        ),
                        child: Text(l.ledgerDetails),
                      ),
                  if (op.text('state') == 'failed')
                    TextButton(
                      onPressed: () => ref
                          .read(
                            ledgerViewModelProvider(snapshot.spaceId).notifier,
                          )
                          .command(
                            (repo) => repo.retry(snapshot.spaceId, op.id),
                          ),
                      child: Text(l.ledgerRetry),
                    ),
                ],
              ),
            ),
          ),
        for (final conflict in snapshot.conflicts)
          JiabuStackItem.content(
            child: TextButton(
              onPressed: () => openConflict(
                context,
                snapshot.spaceId,
                conflict.text('entity_kind'),
                conflict.text('entity_id'),
              ),
              child: Text(l.ledgerConflict),
            ),
          ),
      ],
    );
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({required this.snapshot, super.key});
  final LedgerSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(ledgerViewModelProvider(snapshot.spaceId));
    final filter = state.filter;
    final rows = filterHistory(snapshot, filter);
    final gutter = context.jiabu.spacing.page;
    final now = ref.watch(ledgerClockProvider)();
    final groups = <String, List<LedgerRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.text('occurred_on'), () => []).add(row);
    }
    void update({
      String? text,
      String? member,
      String? account,
      String? tag,
      String? kind,
      String? from,
      String? through,
      String? clear,
    }) {
      ref
          .read(ledgerViewModelProvider(snapshot.spaceId).notifier)
          .filter(
            HistoryFilter(
              text: text ?? filter.text,
              member: clear == 'member' ? null : member ?? filter.member,
              account: clear == 'account' ? null : account ?? filter.account,
              accountLabel: clear == 'account'
                  ? null
                  : account != null
                  ? snapshot.account(account)?.text('name')
                  : filter.accountLabel,
              tag: clear == 'tag' ? null : tag ?? filter.tag,
              kind: clear == 'kind' ? null : kind ?? filter.kind,
              from: from ?? filter.from,
              through: through ?? filter.through,
              labels: ledgerLabels(l),
            ),
          );
    }

    Future<void> select(
      String label,
      List<(String, String)> options,
      String? selected,
      void Function(String?) choose,
    ) async {
      await LedgerSheet.show<void>(
        context: context,
        spaceId: snapshot.spaceId,
        builder: (sheetContext) => JiabuStack(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            JiabuStackItem.content(
              child: Text(label, style: context.jiabu.type.cardTitle),
            ),
            JiabuStackItem.content(
              child: PaperRow(
                child: ListTile(
                  title: Text(l.ledgerAll),
                  selected: selected == null,
                  onTap: () {
                    choose(null);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ),
            for (final item in options)
              JiabuStackItem.content(
                child: PaperRow(
                  child: ListTile(
                    title: Text(item.$2),
                    selected: item.$1 == selected,
                    selectedTileColor: context.jiabu.colors.primarySoft,
                    trailing: item.$1 == selected
                        ? const JiabuIcon(JiabuIcons.uiCheck)
                        : null,
                    onTap: () {
                      choose(item.$1);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: gutter),
          child: JiabuStack(
            children: [
              JiabuStackItem.content(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: HistorySearchField(
                    key: ValueKey(snapshot.spaceId),
                    value: filter.text,
                    label: l.ledgerSearch,
                    onChanged: (text) => update(text: text),
                  ),
                ),
              ),
              // The chip row runs edge to edge: the gutter is its leading and
              // trailing padding, so the last chip ends one gutter before the
              // screen edge and is fully visible once scrolled to the end.
              JiabuStackItem.content(
                child: PaperChipScroller(
                  key: const Key('history-chip-row'),
                  gutter: gutter,
                  child: JiabuChipGroup(
                    children: [
                      PaperFilterChip(
                        label: l.ledgerMembers,
                        selected: filter.member != null,
                        onPressed: () => select(
                          l.ledgerMembers,
                          [
                            for (final member in snapshot.members)
                              (member.id, memberName(member, l)),
                          ],
                          filter.member,
                          (id) => update(
                            member: id,
                            clear: id == null ? 'member' : null,
                          ),
                        ),
                      ),
                      PaperFilterChip(
                        label: l.ledgerAccounts,
                        selected: filter.account != null,
                        onPressed: () => select(
                          l.ledgerAccounts,
                          [
                            for (final a in snapshot.accounts)
                              if (a.text('space_id') == snapshot.spaceId)
                                (a.id, a.text('name')),
                          ],
                          filter.account,
                          (id) => update(
                            account: id,
                            clear: id == null ? 'account' : null,
                          ),
                        ),
                      ),
                      PaperFilterChip(
                        label: l.ledgerTags,
                        selected: filter.tag != null,
                        onPressed: () => select(
                          l.ledgerTags,
                          [
                            for (final tag in snapshot.tags)
                              (tag.id, tagName(tag, ledgerLabels(l))),
                          ],
                          filter.tag,
                          (id) =>
                              update(tag: id, clear: id == null ? 'tag' : null),
                        ),
                      ),
                      PaperFilterChip(
                        label: l.ledgerTypes,
                        selected: filter.kind != null,
                        onPressed: () => select(
                          l.ledgerTypes,
                          [
                            for (final kind in [
                              'expense',
                              'income',
                              'transfer',
                              'reallocation',
                              'refund',
                              'allocation',
                            ])
                              (kind, ledgerLabels(l)[kind] ?? ''),
                          ],
                          filter.kind,
                          (id) => update(
                            kind: id,
                            clear: id == null ? 'kind' : null,
                          ),
                        ),
                      ),
                      PaperFilterChip(
                        label: l.ledgerPeriod,
                        selected: filter.from != null || filter.through != null,
                        onPressed: () => LedgerSheet.show<void>(
                          context: context,
                          spaceId: snapshot.spaceId,
                          builder: (sheetContext) =>
                              DateFilterForm(spaceId: snapshot.spaceId),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filter.isFiltered)
                JiabuStackItem.content(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: Wrap(
                      spacing: filter.account == null ? 0 : JiabuSpacing.sm,
                      runSpacing: filter.account == null ? 0 : JiabuSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (filter.account != null)
                          PaperFilterChip(
                            key: const Key('history-account-filter'),
                            label: l.ledgerOnlyAccount(
                              snapshot.account(filter.account!)?.text('name') ??
                                  filter.accountLabel ??
                                  l.ledgerAccounts,
                            ),
                            selected: true,
                            maxWidth:
                                MediaQuery.sizeOf(context).width - gutter * 2,
                            onPressed: () => update(clear: 'account'),
                          ),
                        Text(l.ledgerResultCount(rows.length)),
                        TextButton(
                          onPressed: () => ref
                              .read(
                                ledgerViewModelProvider(snapshot.spaceId)
                                    .notifier,
                              )
                              .filter(const HistoryFilter()),
                          child: Text(l.ledgerClear),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: JiabuEmptyState(
                    illustration: ExcludeSemantics(
                      child: JiabuIcon(
                        JiabuIcons.uiSearch,
                        size: JiabuSpacing.xxl,
                        color: context.jiabu.colors.ink3,
                      ),
                    ),
                    message: HandText(
                      l.handLedgerEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (final (index, group) in groups.entries.indexed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      index == 0 ? JiabuSpacing.xs : JiabuSpacing.xl,
                      gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The day: a date tape and, on the right, what the
                        // day spent (original `.hs-day h3`).
                        Wrap(
                          key: const Key('history-day-header'),
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: JiabuSpacing.sm,
                          children: [
                            DateTapeLabel(
                              text: ledgerDayLabel(group.key, now, l),
                              pattern:
                                  TapePattern.values[(DateTime.tryParse(
                                            group.key,
                                          )?.day ??
                                          0) %
                                      TapePattern.values.length],
                            ),
                            // A day refunded more than it spent: no total.
                            if (dailyExpense(group.value) > 0)
                              Row(
                                key: const Key('history-day-total'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Text(
                                      l.ledgerExpense,
                                      style: context.jiabu.type.secondary
                                          .copyWith(
                                            color: context.jiabu.colors.ink3,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: JiabuSpacing.xs),
                                  ledgerAmount(
                                    context,
                                    dailyExpense(group.value),
                                    snapshot.currency,
                                    role: AmountRole.inline,
                                    kind: l.ledgerExpense,
                                    tone: AmountTone.plain,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: JiabuSpacing.md),
                        PaperTimelineCard(
                          key: const Key('history-day-card'),
                          lineKey: const Key('history-margin-line'),
                          children: [
                            for (final row in group.value)
                              LedgerHistoryRow(snapshot: snapshot, row: row),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: JiabuLedgerMetrics.footerClearance),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DateFilterForm extends ConsumerWidget {
  const DateFilterForm({required this.spaceId, super.key});
  final String spaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(ledgerViewModelProvider(spaceId)).filter;
    return FormScope(
      spaceId: spaceId,
      formId: 'date-filter',
      initial: {'from': filter.from ?? '', 'through': filter.through ?? ''},
      builder: (context, ref, state, model) => JiabuStack(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...formFieldItems(context, state, model, 'from', l.ledgerFromDate),
          ...formFieldItems(
            context,
            state,
            model,
            'through',
            l.ledgerThroughDate,
          ),
          if (state.error != null)
            JiabuStackItem.captionAfter(child: formError(context, state.error)),
          JiabuStackItem.action(
            child: FilledButton(
              onPressed: () {
                final from = state.values['from']?.toString() ?? '';
                final through = state.values['through']?.toString() ?? '';
                if (!validLedgerDate(from) ||
                    !validLedgerDate(through) ||
                    from.compareTo(through) > 0) {
                  model.fail('validation_failed');
                  return;
                }
                ref
                    .read(ledgerViewModelProvider(spaceId).notifier)
                    .filter(
                      HistoryFilter(
                        text: filter.text,
                        member: filter.member,
                        account: filter.account,
                        accountLabel: filter.accountLabel,
                        tag: filter.tag,
                        kind: filter.kind,
                        from: from,
                        through: through,
                        labels: ledgerLabels(l),
                      ),
                    );
                Navigator.of(context).pop();
              },
              child: Text(l.ledgerSave),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({required this.snapshot, super.key});
  final LedgerSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final result = ledgerBalances(snapshot);
    final balances = result is Ok<Map<String, int>>
        ? result.value
        : <String, int>{};
    final state = ref.watch(ledgerViewModelProvider(snapshot.spaceId));
    bool accountOperationFailed(LedgerRow account) => snapshot
        .operations('account', account.id)
        .any((op) => op.text('state') == 'failed');
    bool accountCreateFailed(LedgerRow account) => snapshot
        .operations('account', account.id)
        .any(
          (op) =>
              op.text('tool') == 'create_account' &&
              op.text('state') == 'failed',
        );

    return ListView(
      padding: EdgeInsets.all(context.jiabu.spacing.page),
      children: [
        JiabuStack(
          children: [
            if (state.error != null)
              JiabuStackItem.captionAfter(
                child: formError(context, state.error),
              ),
            if (result is Failure<Map<String, int>>)
              JiabuStackItem.captionAfter(
                child: Text(ledgerError(l, result.code)),
              ),
            for (final archived in [false, true]) ...[
              if (archived)
                JiabuStackItem.section(
                  child: JiabuSectionHeader(title: l.ledgerArchivedAccounts),
                ),
              for (final account in snapshot.accounts.where(
                (a) => a.archived == archived,
              ))
                JiabuStackItem.content(
                  child: JiabuSettingsGroup(
                    children: [
                      JiabuListRow(
                        title: account.text('name'),
                        subtitle: account.text('kind') == 'real'
                            ? l.ledgerReal
                            : l.ledgerPurpose,
                        status: accountOperationFailed(account)
                            ? l.ledgerFailed
                            : account.syncState == 'pending'
                            ? l.ledgerUpload
                            : null,
                        valueWidget: balances.containsKey(account.id)
                            ? ledgerAmount(
                                context,
                                balances[account.id] ?? 0,
                                snapshot.currency,
                              )
                            : null,
                        supporting:
                            accountCreateFailed(account) ||
                                (account.archived &&
                                    (balances[account.id] ?? 0) != 0)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (accountCreateFailed(account))
                                    Text(
                                      l.ledgerAccountCreateRejected,
                                      key: const Key(
                                        'account-create-rejected-explanation',
                                      ),
                                      style: context.jiabu.type.secondary
                                          .copyWith(
                                            color: context.jiabu.colors.neg,
                                          ),
                                    ),
                                  if (account.archived &&
                                      (balances[account.id] ?? 0) != 0)
                                    Text(
                                      l.ledgerArchiveUnavailable,
                                      key: const Key(
                                        'archived-account-balance-explanation',
                                      ),
                                      style: context.jiabu.type.secondary
                                          .copyWith(
                                            color: context.jiabu.colors.warn,
                                          ),
                                    ),
                                ],
                              )
                            : null,
                        trailing:
                            (!account.archived && snapshot.writable) ||
                                account.syncState == 'conflict'
                            ? PopupMenuButton<String>(
                                icon: JiabuIcon(
                                  JiabuIcons.uiMore,
                                  color:
                                      account.syncState == 'conflict' ||
                                          !state.busy
                                      ? null
                                      : context.jiabu.colors.ink.withValues(
                                          alpha: .38,
                                        ),
                                ),
                                enabled:
                                    account.syncState == 'conflict' ||
                                    !state.busy,
                                onSelected: (value) {
                                  if (value == 'rename') {
                                    unawaited(
                                      openAccountForm(
                                        context,
                                        snapshot.spaceId,
                                        account: account,
                                      ),
                                    );
                                  } else if (value == 'plan') {
                                    unawaited(
                                      openPlan(
                                        context,
                                        snapshot.spaceId,
                                        account.id,
                                      ),
                                    );
                                  } else if (value == 'archive') {
                                    unawaited(
                                      archiveGuide(
                                        context,
                                        ref,
                                        snapshot,
                                        account,
                                        balances[account.id] ?? 0,
                                      ),
                                    );
                                  } else if (value == 'conflict') {
                                    unawaited(
                                      openConflict(
                                        context,
                                        snapshot.spaceId,
                                        'account',
                                        account.id,
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!account.archived &&
                                      snapshot.writable) ...[
                                    PopupMenuItem(
                                      value: 'rename',
                                      enabled: !state.busy,
                                      child: Text(l.ledgerRename),
                                    ),
                                    if (account.text('kind') == 'purpose')
                                      PopupMenuItem(
                                        value: 'plan',
                                        enabled: !state.busy,
                                        child: Text(l.ledgerPlan),
                                      ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      enabled:
                                          !state.busy &&
                                          balances.containsKey(account.id),
                                      child: Text(l.ledgerArchive),
                                    ),
                                  ],
                                  if (account.syncState == 'conflict')
                                    PopupMenuItem(
                                      value: 'conflict',
                                      child: Text(l.ledgerConflict),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

Future<void> archiveGuide(
  BuildContext context,
  WidgetRef ref,
  LedgerSnapshot snapshot,
  LedgerRow account,
  int balance,
) async {
  final l = AppLocalizations.of(context);
  await LedgerSheet.show<void>(
    context: context,
    spaceId: snapshot.spaceId,
    builder: (sheetContext) => JiabuStack(
      children: [
        JiabuStackItem.content(
          child: Text(
            balance == 0 ? l.ledgerArchiveConfirm : l.ledgerArchiveGuide,
          ),
        ),
        if (balance != 0)
          JiabuStackItem.action(
            child: FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                final real = account.text('kind') == 'real';
                unawaited(
                  openManualEntry(
                    context,
                    snapshot.spaceId,
                    initial: {
                      'kind': real ? 'transfer' : 'reallocation',
                      balance > 0
                              ? (real ? 'account_id' : 'purpose_id')
                              : (real ? 'to_account_id' : 'to_purpose_id'):
                          account.id,
                      'amount_text': minorInput(
                        balance.abs(),
                        snapshot.currency,
                      ),
                    },
                  ),
                );
              },
              child: Text(l.ledgerMoveBalance),
            ),
          )
        else
          JiabuStackItem.action(
            child: FilledButton(
              onPressed: () async {
                final ok = await ref
                    .read(ledgerViewModelProvider(snapshot.spaceId).notifier)
                    .command(
                      (repo) =>
                          repo.archiveAccount(snapshot.spaceId, account.id),
                    );
                if (ok && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
              child: Text(l.ledgerArchive),
            ),
          ),
      ],
    ),
  );
}

/// Controller state is presentation-only; filter values live in the ViewModel.
class HistorySearchField extends StatefulWidget {
  const HistorySearchField({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });
  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  @override
  State<HistorySearchField> createState() => _HistorySearchFieldState();
}

class _HistorySearchFieldState extends State<HistorySearchField> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant HistorySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// The rounded search card with a magnifier (design-spec 4.12); the field
  /// itself is borderless and shows the label as its placeholder.
  @override
  Widget build(BuildContext context) => PaperSearchCard(
    child: TextField(
      controller: controller,
      decoration: InputDecoration.collapsed(
        hintText: widget.label,
        hintStyle: context.jiabu.type.body.copyWith(
          color: context.jiabu.colors.ink3,
        ),
      ),
      style: context.jiabu.type.body,
      onChanged: widget.onChanged,
    ),
  );
}

/// One history row on the day's timeline card (design-spec 4.12, original
/// `.li`): a round sticker sitting on the red timeline, the title over
/// 「账户 · 类别」, and on the right the signed Caveat amount over the small
/// entry time.
class LedgerHistoryRow extends StatelessWidget {
  const LedgerHistoryRow({
    required this.snapshot,
    required this.row,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow row;

  /// The widest share of the row (right of the sticker) the amount may take.
  static const double amountShare = .7;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.jiabu.colors;
    final type = context.jiabu.type;
    final failed = snapshot
        .operations('record', row.id)
        .any((op) => op.text('state') == 'failed');
    final display = recordDisplay(allowed: true, row: row, failed: failed);
    final keyName =
        creationEvent(snapshot, row.id)?.text('via_api_key_name') ?? '';
    final accountLine = recordAccountLine(snapshot, row, l);
    final time = recordEntryTime(row, l);
    return PaperRow(
      child: InkWell(
        onTap: () => row.syncState == 'conflict'
            ? openConflict(context, snapshot.spaceId, 'record', row.id)
            : openRecordDetails(context, snapshot.spaceId, row.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: JiabuSpacing.listRowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              JiabuLedgerMetrics.timelineStart,
              JiabuSpacing.md,
              JiabuSpacing.listRowInset,
              JiabuSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Sticker(
                  key: const Key('history-row-sticker'),
                  category: recordStickerCategory(row, snapshot: snapshot),
                ),
                const SizedBox(width: JiabuSpacing.md),
                Expanded(
                  child: LayoutBuilder(
                    // The amount keeps its own width (a signed amount must
                    // not wrap), capped so the title always keeps a share.
                    builder: (context, box) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            key: const Key('history-row-content'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                recordTitle(snapshot, row, l),
                                style: type.listTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (accountLine.isNotEmpty)
                                Text(
                                  accountLine,
                                  key: const Key('history-row-account'),
                                  style: type.caption.copyWith(color: c.ink2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (display != RecordDisplay.recorded)
                                Text(
                                  displayLabel(l, display),
                                  style: type.caption,
                                ),
                              if (failed && display != RecordDisplay.failed)
                                Text(l.ledgerFailed, style: type.caption),
                              if (keyName.isNotEmpty)
                                Semantics(
                                  label: l.ledgerApiKey(keyName),
                                  child: const ExcludeSemantics(
                                    child: JiabuIcon(
                                      JiabuIcons.uiKey,
                                      size: JiabuLedgerMetrics.keyIcon,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: JiabuSpacing.sm),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: box.maxWidth * amountShare,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              recordAmount(context, row, snapshot.currency),
                              if (time.isNotEmpty) ...[
                                const SizedBox(height: JiabuSpacing.xs),
                                Text(
                                  time,
                                  key: const Key('history-row-time'),
                                  style: type.date.copyWith(color: c.ink3),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
