import 'package:flutter/material.dart';
import 'package:jiabu/domain/update.dart';
import 'package:jiabu/features/update/view_model/update_ui_state.dart';
import 'package:jiabu/features/update/widgets/update_banner.dart';
import 'package:jiabu/features/update/widgets/update_sheet.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class C7Preview extends StatelessWidget {
  const C7Preview({required this.state, super.key});
  final String state;

  static const release = ReleaseInfo(
    build: 12,
    version: '1.2.0',
    channel: 'stable',
    bytes: 18874368,
    sha256: '0000000000000000000000000000000000000000000000000000000000000000',
    notes: {
      'zh-Hans': '修复同步中断，并改善大字号下的阅读体验。',
      'en': 'Improves interrupted sync and large-text readability.',
    },
    securityForce: false,
    minServerApi: 1,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.startsWith('banner_')) {
      final forced = state == 'banner_forced';
      return UpdateBanner(
        message: forced ? l.c7ForcedBanner('1.2.0') : l.c7Banner('1.2.0'),
        actionLabel: l.c7Update,
        mandatory: forced,
        onOpen: () {},
        onDismiss: () {},
      );
    }
    final phase = switch (state) {
      'sheet_downloading' => UpdatePhase.downloading,
      'sheet_checksum_failed' => UpdatePhase.failed,
      'sheet_permission_required' => UpdatePhase.needsPermission,
      _ => UpdatePhase.available,
    };
    return JiabuSheet(
      child: UpdateSheet(
        state: UpdateUiState(
          release: release,
          phase: phase,
          received: 7340032,
          total: release.bytes,
          failure: state == 'sheet_checksum_failed'
              ? UpdateFailure.checksumMismatch
              : null,
        ),
        locale: Localizations.localeOf(context).languageCode == 'en'
            ? 'en'
            : 'zh-Hans',
        mandatory: false,
        onDownload: () {},
        onCancel: () {},
        onRetry: () {},
        onSettings: () {},
        onInstall: () {},
        onLater: () {},
      ),
    );
  }
}
