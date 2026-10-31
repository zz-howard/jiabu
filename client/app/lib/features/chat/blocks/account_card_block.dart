import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/account_activity.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AccountCardBlock extends ConsumerWidget {
  const AccountCardBlock({
    required this.spaceId,
    required this.accountId,
    required this.versionAtReply,
    required this.nameSnapshot,
    super.key,
  });

  final String spaceId;
  final String accountId;
  final int versionAtReply;
  final String nameSnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(ledgerViewModelProvider(spaceId));
    final snapshot = state.snapshot;
    if (snapshot == null) {
      if (state.error != null) {
        return PaperCard(child: Text(ledgerError(l, state.error!)));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.chatAccountSyncing),
          const JiabuBlockSkeleton(type: 'x-jiabu.account_card'),
        ],
      );
    }
    final allowed = const {'read', 'write', 'manage'}.contains(
      (snapshot.space.data['modules'] as Map<String, Object?>?)?['ledger'],
    );
    if (!allowed) {
      return PaperCard(child: Text(l.ledgerDenied));
    }
    final account = snapshot.find(snapshot.accounts, accountId);
    if (account == null) {
      return PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(nameSnapshot, style: context.jiabu.type.cardTitle),
            const SizedBox(height: JiabuSpacing.sm),
            Text(l.chatAccountUnavailable),
            const SizedBox(height: JiabuSpacing.md),
            _HistoryButton(
              spaceId: spaceId,
              accountId: accountId,
              accountName: nameSnapshot,
            ),
          ],
        ),
      );
    }
    final localVersion = account.number('version');
    if (localVersion < versionAtReply) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.chatAccountSyncing),
          const JiabuBlockSkeleton(type: 'x-jiabu.account_card'),
        ],
      );
    }
    final balance = ledgerAccountBalance(snapshot, account);
    final month = DateFormat('yyyy-MM')
        .format(ref.watch(ledgerClockProvider)());
    final flows = accountMonthFlows(snapshot, account, month);
    if (balance is Failure<int> || flows is Failure<AccountMonthFlows>) {
      return PaperCard(child: Text(l.ledgerAggregateRange));
    }
    final currentBalance = (balance as Ok<int>).value;
    final monthFlows = (flows as Ok<AccountMonthFlows>).value;
    final recent = accountRecentRecords(snapshot, accountId);
    final name = account.text('name').isEmpty
        ? nameSnapshot
        : account.text('name');
    final changed = localVersion > versionAtReply;
    final status = [
      if (account.archived) l.chatAccountArchived,
      if (changed) l.chatAccountChanged,
    ].join(' · ');
    return Semantics(
      container: true,
      child: PaperCard(
        revoked: account.archived,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: context.jiabu.type.cardTitle),
                ),
                Text(
                  account.text('kind') == 'purpose'
                      ? l.ledgerPurpose
                      : l.ledgerReal,
                  style: context.jiabu.type.badge,
                ),
              ],
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: JiabuSpacing.xs),
              Text(status, style: context.jiabu.type.caption),
            ],
            const SizedBox(height: JiabuSpacing.md),
            Text(l.chatAccountBalance, style: context.jiabu.type.caption),
            ledgerAmount(
              context,
              currentBalance,
              snapshot.currency,
              role: AmountRole.balance,
            ),
            const SizedBox(height: JiabuSpacing.md),
            Wrap(
              spacing: JiabuSpacing.xl,
              runSpacing: JiabuSpacing.sm,
              children: [
                _FlowAmount(
                  label: l.chatAccountMonthIn,
                  value: monthFlows.incoming,
                  currency: snapshot.currency,
                  incoming: true,
                ),
                _FlowAmount(
                  label: l.chatAccountMonthOut,
                  value: monthFlows.outgoing,
                  currency: snapshot.currency,
                  incoming: false,
                ),
              ],
            ),
            const SizedBox(height: JiabuSpacing.md),
            Text(l.ledgerRecent, style: context.jiabu.type.listTitle),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: JiabuSpacing.xs),
                child: Text(l.chatAccountNoRecent),
              )
            else
              for (final row in recent)
                Builder(
                  builder: (context) {
                    final signed =
                        accountMovement(account, row)?.signedMinor ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: JiabuSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              recordTitle(snapshot, row, l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: JiabuSpacing.sm),
                          ledgerAmount(
                            context,
                            signed,
                            snapshot.currency,
                            tone: signed > 0
                                ? AmountTone.positive
                                : AmountTone.plain,
                            showPlus: signed > 0,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            const SizedBox(height: JiabuSpacing.lg),
            _HistoryButton(
              spaceId: spaceId,
              accountId: accountId,
              accountName: name,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowAmount extends StatelessWidget {
  const _FlowAmount({
    required this.label,
    required this.value,
    required this.currency,
    required this.incoming,
  });

  final String label;
  final int value;
  final String currency;
  final bool incoming;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.jiabu.type.caption),
      ledgerAmount(
        context,
        incoming ? value : -value,
        currency,
        role: AmountRole.detail,
        tone: incoming ? AmountTone.positive : AmountTone.plain,
        showPlus: incoming,
      ),
    ],
  );
}

class _HistoryButton extends ConsumerWidget {
  const _HistoryButton({
    required this.spaceId,
    required this.accountId,
    required this.accountName,
  });

  final String spaceId;
  final String accountId;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    key: const Key('account-card-history'),
    onPressed: () {
      final l = AppLocalizations.of(context);
      ref
          .read(ledgerViewModelProvider(spaceId).notifier)
          .filter(
            HistoryFilter(
              account: accountId,
              accountLabel: accountName,
              labels: ledgerLabels(l),
            ),
          );
      context.go('/history');
    },
    child: Text(AppLocalizations.of(context).chatAccountViewHistory),
  );
}
