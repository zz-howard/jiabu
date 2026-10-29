import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu_design/jiabu_design.dart';

class RecordCardBlock extends ConsumerWidget {
  const RecordCardBlock({
    required this.spaceId,
    required this.recordId,
    required this.versionAtReply,
    super.key,
  });
  final String spaceId;
  final String recordId;
  final int versionAtReply;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    if (snapshot == null) {
      return PaperCard(
        child: Text(AppLocalizations.of(context).chatRecordSyncing),
      );
    }
    final row = snapshot.find(snapshot.records, recordId);
    final allowed = const {'read', 'write', 'manage'}.contains(
      (snapshot.space.data['modules'] as Map<String, Object?>?)?['ledger'],
    );
    if (!allowed) {
      return LedgerRecordCard(
        snapshot: snapshot,
        row: row,
        allowed: false,
        versionAtReply: versionAtReply,
      );
    }
    if (row != null) {
      return liveRecordCard(
        context,
        ref,
        snapshot,
        row,
        versionAtReply: versionAtReply,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).chatRecordSyncing),
        const JiabuBlockSkeleton(type: 'x-jiabu.record_card'),
      ],
    );
  }
}
