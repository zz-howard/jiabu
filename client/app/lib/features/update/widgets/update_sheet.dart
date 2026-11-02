import 'package:flutter/material.dart';
import 'package:jiabu/domain/update.dart';
import 'package:jiabu/features/update/view_model/update_ui_state.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class UpdateSheet extends StatelessWidget {
  const UpdateSheet({
    required this.state,
    required this.locale,
    required this.mandatory,
    required this.onDownload,
    required this.onCancel,
    required this.onRetry,
    required this.onSettings,
    required this.onInstall,
    required this.onLater,
    super.key,
  });
  final UpdateUiState state;
  final String locale;
  final bool mandatory;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onSettings;
  final VoidCallback onInstall;
  final VoidCallback onLater;

  String _size(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final release = state.release;
    if (release == null) return Text(l.c7NoRelease);
    final progress = state.total == 0
        ? 0.0
        : (state.received / state.total).clamp(0.0, 1.0);
    final failure = switch (state.failure) {
      UpdateFailure.checksumMismatch => l.c7Damaged,
      UpdateFailure.signatureMismatch => l.c7Tampered,
      UpdateFailure.installCancelled => l.c7InstallCancelled,
      UpdateFailure.installFailed => l.c7InstallFailed,
      _ => l.c7Interrupted,
    };
    return JiabuStack(
      children: [
        JiabuStackItem.section(
          child: JiabuSectionHeader(title: l.c7SheetTitle),
        ),
        JiabuStackItem.content(
          child: Text(l.c7VersionSize(release.version, _size(release.bytes))),
        ),
        JiabuStackItem.content(child: Text(release.note(locale))),
        if (state.phase == UpdatePhase.downloading) ...[
          JiabuStackItem.content(
            child: Semantics(
              label: l.c7Progress((progress * 100).round()),
              child: Container(
                height: 6,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: context.jiabu.colors.surface2,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: context.jiabu.colors.primary),
                ),
              ),
            ),
          ),
          JiabuStackItem.action(
            child: OutlinedButton(onPressed: onCancel, child: Text(l.c7Cancel)),
          ),
        ] else if (state.phase == UpdatePhase.needsPermission) ...[
          JiabuStackItem.content(
            child: PaperCard(child: Text(l.c7PermissionHelp)),
          ),
          JiabuStackItem.action(
            child: FilledButton(
              onPressed: onSettings,
              child: Text(l.c7GoSettings),
            ),
          ),
          JiabuStackItem.action(
            child: OutlinedButton(
              onPressed: onInstall,
              child: Text(l.c7Install),
            ),
          ),
        ] else if (state.phase == UpdatePhase.failed) ...[
          JiabuStackItem.content(child: PaperCard(child: Text(failure))),
          JiabuStackItem.action(
            child: FilledButton(onPressed: onRetry, child: Text(l.c7Retry)),
          ),
        ] else if (state.phase == UpdatePhase.installing) ...[
          JiabuStackItem.content(child: Text(l.c7Installing)),
          JiabuStackItem.action(
            child: OutlinedButton(
              onPressed: onInstall,
              child: Text(l.c7Reinstall),
            ),
          ),
        ] else ...[
          JiabuStackItem.action(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDownload,
                child: Text(l.c7DownloadInstall),
              ),
            ),
          ),
          if (!mandatory)
            JiabuStackItem.action(
              child: TextButton(onPressed: onLater, child: Text(l.c7Later)),
            ),
        ],
      ],
    );
  }
}
