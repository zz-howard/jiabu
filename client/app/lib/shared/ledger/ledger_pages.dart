import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

class LedgerRoutePage extends ConsumerWidget {
  const LedgerRoutePage({required this.page, super.key});
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(currentLedgerSpaceProvider).asData?.value;
    final l = AppLocalizations.of(context);
    if (space == null) {
      return Center(child: Text(l.ledgerNoSpace));
    }
    final state = ref.watch(ledgerViewModelProvider(space));
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return Center(
        child: Text(
          state.error == null ? l.ledgerLoading : ledgerError(l, state.error!),
        ),
      );
    }
    final allowed = const ['read', 'write', 'manage'].contains(
      (snapshot.space.data['modules'] as Map<String, Object?>?)?['ledger'],
    );
    if (!allowed && page != 'chat' && page != 'settings') {
      return Center(child: Text(l.ledgerDenied));
    }
    return switch (page) {
      'chat' => Center(child: Text(l.ledgerChatPlaceholder)),
      'overview' => OverviewPage(snapshot: snapshot),
      'history' => HistoryPage(snapshot: snapshot),
      'settings' => SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.decor.pageInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HandUnderline(
              child: Text(
                l.ledgerSettings,
                style: context.jiabu.type.pageTitle,
              ),
            ),
            PaperCard(
              child: PaperRow(
                child: ListTile(
                  title: Text(l.ledgerAccounts),
                  trailing: const JiabuIcon(JiabuIcons.uiRight),
                  onTap: () => context.push<void>('/settings/accounts'),
                ),
              ),
            ),
          ],
        ),
      ),
      _ => AccountsPage(snapshot: snapshot),
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
    final recent = filterHistory(snapshot, const HistoryFilter()).take(5);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.jiabu.decor.pageInset,
        context.jiabu.decor.cardGap,
        context.jiabu.decor.pageInset,
        JiabuLedgerMetrics.footerClearance,
      ),
      children: [
        Text(l.ledgerOverview, style: context.jiabu.type.pageTitle),
        if (result is Failure<Map<String, int>>)
          Text(ledgerError(l, result.code)),
        if (snapshot.accounts.isEmpty)
          TextButton(
            onPressed: () => context.push<void>('/settings/accounts'),
            child: Text(l.ledgerNoAccounts),
          ),
        if (result is Ok<Map<String, int>>)
          for (final kind in ['real', 'purpose']) ...[
            Padding(
              padding: EdgeInsets.only(
                top: context.jiabu.decor.sectionTop,
                bottom: context.jiabu.decor.sectionBottom,
              ),
              child: Text(
                kind == 'real' ? l.ledgerReal : l.ledgerPurpose,
                style: context.jiabu.type.sectionTitle,
              ),
            ),
            for (final account in snapshot.accounts.where(
              (a) =>
                  a.text('kind') == kind &&
                  (!a.archived || (balances[a.id] ?? 0) != 0),
            ))
              AccountBalanceTile(
                snapshot: snapshot,
                account: account,
                balance: balances[account.id] ?? 0,
              ),
          ],
        Padding(
          padding: EdgeInsets.only(
            top: context.jiabu.decor.sectionTop,
            bottom: context.jiabu.decor.sectionBottom,
          ),
          child: Text(l.ledgerPending, style: context.jiabu.type.sectionTitle),
        ),
        PendingItems(snapshot: snapshot),
        Padding(
          padding: EdgeInsets.only(
            top: context.jiabu.decor.sectionTop,
            bottom: context.jiabu.decor.sectionBottom,
          ),
          child: Text(l.ledgerRecent, style: context.jiabu.type.sectionTitle),
        ),
        for (final row in recent)
          Align(
            alignment: Alignment.centerLeft,
            child: liveRecordCard(context, ref, snapshot, row),
          ),
        // C6 extension point: family summary. No card in this slice.
      ],
    );
  }
}

Widget liveRecordCard(
  BuildContext context,
  WidgetRef ref,
  LedgerSnapshot snapshot,
  LedgerRow row,
) => LedgerRecordCard(
  snapshot: snapshot,
  row: row,
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

class AccountBalanceTile extends StatelessWidget {
  const AccountBalanceTile({
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
    return Padding(
      padding: EdgeInsets.only(bottom: context.jiabu.decor.cardGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaperCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${account.text('name')}'
                    '${account.archived ? ' · ${l.ledgerArchived}' : ''}',
                    style: context.jiabu.type.listTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: context.jiabu.decor.cardGap),
                Expanded(
                  child: ledgerAmount(
                    context,
                    balance,
                    snapshot.currency,
                    role: AmountRole.balance,
                  ),
                ),
              ],
            ),
          ),
          if (account.archived && balance != 0)
            Text(l.ledgerArchiveUnavailable)
          else if (balance < 0) ...[
            SizedBox(height: context.jiabu.decor.cardGap),
            NegativeBalanceNote(
              title: l.ledgerNegativeTitle(
                account.text('name'),
                formatMinor(balance, snapshot.currency, l.localeName),
              ),
              body: purpose
                  ? l.ledgerNegativeBody
                  : l.ledgerNegativeTransferBody,
              action: BalanceNoteButton(
                label: purpose && reserve != null
                    ? l.ledgerReserveCover(
                        formatCompactMinor(
                          -balance,
                          snapshot.currency,
                          l.localeName,
                        ),
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
                                'amount_text': minorInput(
                                  -balance,
                                  snapshot.currency,
                                ),
                              },
                            },
                          ),
                        );
                      },
              ),
            ),
          ],
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.pending.isEmpty && snapshot.conflicts.isEmpty)
          Text(l.ledgerNoPending),
        for (final op in snapshot.pending)
          PaperCard(
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
                        .command((repo) => repo.retry(snapshot.spaceId, op.id)),
                    child: Text(l.ledgerRetry),
                  ),
              ],
            ),
          ),
        for (final conflict in snapshot.conflicts)
          TextButton(
            onPressed: () => openConflict(
              context,
              snapshot.spaceId,
              conflict.text('entity_kind'),
              conflict.text('entity_id'),
            ),
            child: Text(l.ledgerConflict),
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
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.jiabu.type.cardTitle),
            PaperRow(
              child: ListTile(
                title: Text(l.ledgerAll),
                selected: selected == null,
                onTap: () {
                  choose(null);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
            for (final item in options)
              PaperRow(
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
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(context.jiabu.decor.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.ledgerHistory, style: context.jiabu.type.pageTitle),
              HistorySearchField(
                key: ValueKey(snapshot.spaceId),
                value: filter.text,
                label: l.ledgerSearch,
                onChanged: (text) => update(text: text),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
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
                        (id) =>
                            update(kind: id, clear: id == null ? 'kind' : null),
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
              if (filter.isFiltered)
                Wrap(
                  children: [
                    Text(l.ledgerResultCount(rows.length)),
                    TextButton(
                      onPressed: () => ref
                          .read(
                            ledgerViewModelProvider(snapshot.spaceId).notifier,
                          )
                          .filter(const HistoryFilter()),
                      child: Text(l.ledgerClear),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: Center(child: HandText(l.handLedgerEmpty)),
                ),
              for (final group in groups.entries)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.jiabu.decor.pageInset,
                      vertical: context.jiabu.decor.cardGap,
                    ),
                    child: PaperBackground(
                      pattern: PaperPattern.ruled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: context.jiabu.decor.cardGap,
                            children: [
                              DateTapeLabel(
                                text: ledgerDate(group.key, l),
                                pattern:
                                    TapePattern.values[(DateTime.tryParse(
                                              group.key,
                                            )?.day ??
                                            0) %
                                        TapePattern.values.length],
                              ),
                              ledgerAmount(
                                context,
                                dailyExpense(group.value),
                                snapshot.currency,
                                kind: l.ledgerExpense,
                              ),
                            ],
                          ),
                          for (final row in group.value)
                            LedgerHistoryRow(snapshot: snapshot, row: row),
                        ],
                      ),
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
      builder: (context, ref, state, model) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          formField(context, state, model, 'from', l.ledgerFromDate),
          formField(context, state, model, 'through', l.ledgerThroughDate),
          formError(context, state.error),
          FilledButton(
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
    return ListView(
      padding: EdgeInsets.all(context.jiabu.decor.pageInset),
      children: [
        Text(l.ledgerAccounts, style: context.jiabu.type.pageTitle),
        formError(context, state.error),
        if (result is Failure<Map<String, int>>)
          Text(ledgerError(l, result.code)),
        FilledButton(
          onPressed: snapshot.writable
              ? () => openAccountForm(context, snapshot.spaceId)
              : null,
          child: Text(l.ledgerNewAccount),
        ),
        SizedBox(height: context.jiabu.decor.sectionBottom),
        for (final archived in [false, true]) ...[
          if (archived)
            Padding(
              padding: EdgeInsets.only(
                top: context.jiabu.decor.sectionTop,
                bottom: context.jiabu.decor.sectionBottom,
              ),
              child: Text(
                l.ledgerArchivedAccounts,
                style: context.jiabu.type.sectionTitle,
              ),
            ),
          for (final account in snapshot.accounts.where(
            (a) => a.archived == archived,
          ))
            Padding(
              padding: EdgeInsets.only(bottom: context.jiabu.decor.cardGap),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      account.text('name'),
                      style: context.jiabu.type.listTitle,
                    ),
                    Text(
                      account.text('kind') == 'real'
                          ? l.ledgerReal
                          : l.ledgerPurpose,
                    ),
                    if (account.syncState == 'pending')
                      Text(
                        snapshot
                                .operations('account', account.id)
                                .any((op) => op.text('state') == 'failed')
                            ? l.ledgerFailed
                            : l.ledgerUpload,
                      ),
                    if (snapshot
                        .operations('account', account.id)
                        .any(
                          (op) =>
                              op.text('tool') == 'create_account' &&
                              op.text('state') == 'failed',
                        ))
                      Text(
                        l.ledgerAccountCreateRejected,
                        style: context.jiabu.type.secondary,
                      ),
                    if (balances.containsKey(account.id))
                      ledgerAmount(
                        context,
                        balances[account.id] ?? 0,
                        snapshot.currency,
                      ),
                    if (account.archived && (balances[account.id] ?? 0) != 0)
                      Text(l.ledgerArchiveUnavailable),
                    if (!account.archived)
                      Wrap(
                        spacing: context.jiabu.decor.cardGap,
                        children: [
                          TextButton(
                            onPressed: snapshot.writable
                                ? () => openAccountForm(
                                    context,
                                    snapshot.spaceId,
                                    account: account,
                                  )
                                : null,
                            child: Text(l.ledgerRename),
                          ),
                          if (account.text('kind') == 'purpose')
                            TextButton(
                              onPressed: snapshot.writable
                                  ? () => openPlan(
                                      context,
                                      snapshot.spaceId,
                                      account.id,
                                    )
                                  : null,
                              child: Text(l.ledgerPlan),
                            ),
                          TextButton(
                            onPressed:
                                snapshot.writable &&
                                    !state.busy &&
                                    balances.containsKey(account.id)
                                ? () => archiveGuide(
                                    context,
                                    ref,
                                    snapshot,
                                    account,
                                    balances[account.id] ?? 0,
                                  )
                                : null,
                            child: Text(l.ledgerArchive),
                          ),
                        ],
                      ),
                    if (account.syncState == 'conflict')
                      TextButton(
                        onPressed: () => openConflict(
                          context,
                          snapshot.spaceId,
                          'account',
                          account.id,
                        ),
                        child: Text(l.ledgerConflict),
                      ),
                  ],
                ),
              ),
            ),
        ],
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
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(balance == 0 ? l.ledgerArchiveConfirm : l.ledgerArchiveGuide),
        if (balance != 0)
          FilledButton(
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
                    'amount_text': minorInput(balance.abs(), snapshot.currency),
                  },
                ),
              );
            },
            child: Text(l.ledgerMoveBalance),
          )
        else
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(ledgerViewModelProvider(snapshot.spaceId).notifier)
                  .command(
                    (repo) => repo.archiveAccount(snapshot.spaceId, account.id),
                  );
              if (ok && sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
            child: Text(l.ledgerArchive),
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

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
  );
}

class LedgerHistoryRow extends StatelessWidget {
  const LedgerHistoryRow({
    required this.snapshot,
    required this.row,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow row;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failed = snapshot
        .operations('record', row.id)
        .any((op) => op.text('state') == 'failed');
    final display = recordDisplay(allowed: true, row: row, failed: failed);
    final keyName =
        creationEvent(snapshot, row.id)?.text('via_api_key_name') ?? '';
    return PaperRow(
      child: InkWell(
        onTap: () => row.syncState == 'conflict'
            ? openConflict(context, snapshot.spaceId, 'record', row.id)
            : openRecordDetails(context, snapshot.spaceId, row.id),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: context.jiabu.decor.rowMinHeight,
          ),
          child: Padding(
            padding: EdgeInsets.all(context.jiabu.decor.rowInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Sticker(category: recordStickerCategory(row), compact: true),
                SizedBox(width: context.jiabu.decor.cardGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              recordTitle(snapshot, row, l),
                              style: context.jiabu.type.listTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: context.jiabu.decor.messageGap),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ledgerAmount(
                                  context,
                                  row.number('amount_minor'),
                                  snapshot.currency,
                                ),
                                Text(
                                  ledgerHistoryTime(row, l),
                                  textAlign: TextAlign.right,
                                  style: context.jiabu.type.date,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(memberLabel(snapshot, row, l)),
                      if (display != RecordDisplay.recorded)
                        Text(displayLabel(l, display)),
                      if (failed && display != RecordDisplay.failed)
                        Text(l.ledgerFailed),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
