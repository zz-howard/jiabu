import 'package:flutter/material.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/record_presentation.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu_design/jiabu_design.dart';

String displayLabel(AppLocalizations l, RecordDisplay state) => switch (state) {
  RecordDisplay.denied => l.ledgerDenied,
  RecordDisplay.loading => l.ledgerLoading,
  RecordDisplay.conflict => l.ledgerConflict,
  RecordDisplay.voided => l.ledgerVoided,
  RecordDisplay.failed => l.ledgerFailed,
  RecordDisplay.pending => l.ledgerUpload,
  RecordDisplay.changed => l.ledgerChanged,
  RecordDisplay.recorded => l.ledgerRecorded,
};

class LedgerRecordCard extends StatelessWidget {
  const LedgerRecordCard({
    required this.snapshot,
    required this.row,
    this.allowed = true,
    this.versionAtReply,
    this.onOpen,
    this.onEdit,
    this.onVoid,
    this.onRestore,
    this.onRetry,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow? row;
  final bool allowed;
  final int? versionAtReply;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onVoid;
  final VoidCallback? onRestore;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = row;
    final failed =
        value != null &&
        snapshot
            .operations('record', value.id)
            .any((op) => op.text('state') == 'failed');
    final state = recordDisplay(
      allowed: allowed,
      row: value,
      failed: failed,
      versionAtReply: versionAtReply,
    );
    final label = displayLabel(l, state);
    if (state == RecordDisplay.denied || state == RecordDisplay.loading) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: JiabuLedgerMetrics.recordWidth,
        ),
        child: PaperCard(
          child: Semantics(liveRegion: true, child: Text(label)),
        ),
      );
    }
    if (value == null) {
      return const SizedBox.shrink();
    }
    final editable =
        snapshot.writable &&
        !snapshot
            .operations('record', value.id)
            .any((op) => op.text('state') == 'sending');
    final keyEvent = creationEvent(snapshot, value.id);
    final keyName = keyEvent?.text('via_api_key_name') ?? '';
    final accent =
        context.jiabu.colors.spaceAccents[snapshot.space.text(
          'accent_color',
        )] ??
        context.jiabu.colors.primaryText;
    final title = recordTitle(snapshot, value, l);
    final balanceResult = ledgerBalances(snapshot);
    final balances = balanceResult is Ok<Map<String, int>>
        ? balanceResult.value
        : <String, int>{};
    final amount = ledgerAmount(
      context,
      value.number('amount_minor'),
      snapshot.currency,
      role: AmountRole.record,
      kind: ledgerLabels(l)[value.text('kind')],
    );
    final titleStyle = value.text('note').isEmpty
        ? context.jiabu.type.cardTitle
        : context.jiabu.type.listTitle;
    final titleWidget = Text(
      title,
      key: const Key('record-card-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final balanceTitle = LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        final amountPainter = TextPainter(
          text: TextSpan(
            text: formatMinor(
              value.number('amount_minor'),
              snapshot.currency,
              l.localeName,
            ),
            style: context.jiabu.type.recordAmount,
          ),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        final stacked =
            titlePainter.width + JiabuSpacing.md + amountPainter.width >
            constraints.maxWidth;
        final displayedTitle = value.active
            ? titleWidget
            : PencilStrike(child: titleWidget);
        final displayedAmount = KeyedSubtree(
          key: const Key('record-card-amount'),
          child: value.active ? amount : PencilStrike(child: amount),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              displayedTitle,
              const SizedBox(height: JiabuSpacing.xs),
              Align(alignment: Alignment.centerRight, child: displayedAmount),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: displayedTitle),
            const SizedBox(width: JiabuSpacing.md),
            displayedAmount,
          ],
        );
      },
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: JiabuLedgerMetrics.recordWidth,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: JiabuSpacing.cardGap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PaperCard(
              revoked: !value.active,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Sticker(category: recordStickerCategory(value)),
                      const SizedBox(width: JiabuSpacing.cardGap),
                      Expanded(
                        child: Wrap(
                          spacing: JiabuSpacing.messageGap,
                          runSpacing: JiabuSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ledgerLabels(l)[value.text('kind')] ?? '',
                              style: context.jiabu.type.badge,
                            ),
                            Text(
                              '· ${ledgerDate(value.text('occurred_on'), l)}',
                            ),
                            Text(memberLabel(snapshot, value, l)),
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
                      ExcludeSemantics(
                        child: Container(
                          width: JiabuLedgerMetrics.cardDot,
                          height: JiabuLedgerMetrics.cardDot,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: JiabuSpacing.cardGap,
                      ),
                      child: balanceTitle,
                    ),
                  ),
                  if (value.text('kind') == 'reallocation')
                    Text(l.ledgerReallocationHint),
                  DottedValueRow(
                    label: l.ledgerRealField,
                    value: [
                      for (final field in ['account_id', 'to_account_id'])
                        if (value.text(field).isNotEmpty)
                          snapshot
                                  .find(snapshot.accounts, value.text(field))
                                  ?.text('name') ??
                              '',
                    ].join(' → '),
                  ),
                  if (value.text('purpose_id').isEmpty &&
                      value.text('to_purpose_id').isEmpty)
                    DottedValueRow(label: l.ledgerPurposeBalance, value: '')
                  else
                    for (final field in ['purpose_id', 'to_purpose_id'])
                      if (value.text(field).isNotEmpty)
                        DottedValueRow(
                          label:
                              snapshot
                                  .find(snapshot.accounts, value.text(field))
                                  ?.text('name') ??
                              l.ledgerPurposeBalance,
                          value: formatMinor(
                            balances[value.text(field)] ?? 0,
                            snapshot.currency,
                            l.localeName,
                          ),
                          negative: (balances[value.text(field)] ?? 0) < 0,
                        ),
                  DottedValueRow(
                    label: l.ledgerTags,
                    value: value
                        .strings('tag_ids')
                        .map((id) {
                          final name = tagName(
                            snapshot.find(snapshot.tags, id),
                            ledgerLabels(l),
                          );
                          return '#$name';
                        })
                        .join(' '),
                    primary: true,
                  ),
                  Divider(color: context.jiabu.colors.line),
                  TextButtonTheme(
                    data: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: context.jiabu.colors.primaryText,
                        minimumSize: const Size(
                          JiabuLedgerMetrics.recordActionHeight,
                          JiabuLedgerMetrics.recordActionHeight,
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: JiabuSpacing.cardGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (state == RecordDisplay.recorded ||
                            state == RecordDisplay.voided)
                          Stamp(
                            label: label,
                            state: value.active
                                ? StampState.recorded
                                : StampState.revoked,
                          )
                        else
                          Text(label, style: context.jiabu.type.badge),
                        if (failed && state != RecordDisplay.failed)
                          Text(l.ledgerFailed),
                        if (failed)
                          TextButton(
                            onPressed: onRetry,
                            child: Text(l.ledgerRetry),
                          ),
                        if (state == RecordDisplay.conflict)
                          TextButton(
                            onPressed: onOpen,
                            child: Text(l.ledgerResolve),
                          )
                        else if (!value.active)
                          TextButton(
                            onPressed: editable ? onRestore : null,
                            child: Text(l.ledgerRestore),
                          )
                        else ...[
                          TextButton(
                            onPressed: editable ? onEdit : null,
                            child: Text(l.ledgerEdit),
                          ),
                          TextButton(
                            onPressed: editable ? onVoid : null,
                            child: Text(l.ledgerVoid),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: JiabuSpacing.cardGap,
              top: -context.jiabu.decor.compactHeaderInset,
              child: const ExcludeSemantics(child: Tape()),
            ),
          ],
        ),
      ),
    );
  }
}
