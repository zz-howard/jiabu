import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class SessionStatusScreen extends StatelessWidget {
  const SessionStatusScreen({
    required this.state,
    required this.onPassword,
    required this.onSwitch,
    required this.onLogout,
    this.onDismissNotice,
    super.key,
  });
  final AuthUiState state;
  final VoidCallback onPassword;
  final VoidCallback onSwitch;
  final VoidCallback onLogout;
  final VoidCallback? onDismissNotice;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthFrame(
      title: l10n.authSignedIn,
      children: [
        if (state.adminResetAt case final DateTime date)
          JiabuStackItem.content(
            child: Text(
              l10n.authAdminReset(
                DateFormat.yMd(l10n.localeName).add_Hm().format(date.toLocal()),
              ),
            ),
          ),
        if (state.syncStatus == SyncStatus.clientTooOld)
          JiabuStackItem.content(child: Text(l10n.authClientTooOld)),
        if (state.syncStatus == SyncStatus.serverTooOld)
          JiabuStackItem.content(child: Text(l10n.authServerTooOld)),
        if (state.syncStatus == SyncStatus.offline)
          JiabuStackItem.captionBefore(child: Text(l10n.authOffline)),
        if (state.spaceCleared)
          JiabuStackItem.content(
            child: Text(l10n.authSpaceCleared(state.clearedCount)),
          ),
        if (state.spaceCleared)
          JiabuStackItem.action(
            child: TextButton(
              onPressed: onDismissNotice,
              child: Text(l10n.authDismissNotice),
            ),
          ),
        JiabuStackItem.action(
          child: TextButton(
            onPressed: onPassword,
            child: Text(l10n.authChangePassword),
          ),
        ),
        JiabuStackItem.action(
          child: TextButton(
            onPressed: onSwitch,
            child: Text(l10n.authChangeServer),
          ),
        ),
        JiabuStackItem.action(
          child: TextButton(onPressed: onLogout, child: Text(l10n.authLogout)),
        ),
      ],
    );
  }
}
