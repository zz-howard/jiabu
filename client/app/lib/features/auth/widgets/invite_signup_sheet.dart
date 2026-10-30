import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

// TODO(invite-signup): replace this explanation only after the server exposes
// an invitation-based account creation API. Public registration stays closed.
Future<void> showInviteSignupSheet(BuildContext context) async {
  await JiabuSheet.show<void>(
    context: context,
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext);
      return JiabuStack(
        key: const Key('invite-signup-placeholder'),
        children: [
          JiabuStackItem.content(
            child: Text(
              l.authInviteComingTitle,
              style: sheetContext.jiabu.type.cardTitle,
            ),
          ),
          JiabuStackItem.content(
            child: Text(
              l.authInviteComingBody,
              style: sheetContext.jiabu.type.body,
            ),
          ),
          JiabuStackItem.action(
            child: FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(l.authInviteClose),
            ),
          ),
        ],
      );
    },
  );
}
