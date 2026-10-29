import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/features/settings/api_keys/api_key_labels.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class ApiKeyRow extends ConsumerWidget {
  const ApiKeyRow({required this.row, this.onTap, super.key});
  final Map<String, Object?> row;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
    final status = row['status'] as String?;
    final days = expiry?.difference(ref.watch(ledgerClockProvider)()).inDays;
    final scopeLabel = row['scope'] == 'read' ? l.c4Read : l.c4ReadWrite;
    final String statusLabel;
    if (status == 'active') {
      statusLabel = days == null
          ? l.c4Never
          : l.c4RemainingDays(days < 0 ? 0 : days);
    } else {
      statusLabel = status == 'revoked' ? l.c4Revoked : l.c4Expired;
    }
    final prefix = row['display_prefix'] as String? ?? '';
    final inactive = status != 'active';
    return Opacity(
      opacity: inactive ? .65 : 1,
      child: JiabuListRow(
        leading: const ApiKeySticker(),
        title: row['name'] as String? ?? '',
        subtitle: scopeLabel,
        status: prefix.isEmpty ? null : prefix,
        valueWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (inactive)
              Stamp(label: statusLabel, state: StampState.revoked, degrees: 0)
            else
              Text(
                statusLabel,
                textAlign: TextAlign.end,
                style: context.jiabu.type.caption.copyWith(
                  color: days == null || days <= 7
                      ? context.jiabu.colors.warn
                      : context.jiabu.colors.ink2,
                ),
              ),
            Text(
              keyTime(l, row['last_used_at'], l.c4NeverUsed),
              textAlign: TextAlign.end,
              style: context.jiabu.type.caption,
            ),
          ],
        ),
        showChevron: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
