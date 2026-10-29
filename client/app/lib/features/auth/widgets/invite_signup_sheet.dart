import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

// TODO(invite-signup): replace this explanation only after the server exposes
// an invitation-based account creation API. Public registration stays closed.
Future<void> showInviteSignupSheet(BuildContext context) async {
  await PaperSheet.show<void>(
    context: context,
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext);
      return Column(
        key: const Key('invite-signup-placeholder'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.authInviteComingTitle,
            style: sheetContext.jiabu.type.cardTitle,
          ),
          SizedBox(height: sheetContext.jiabu.decor.cardGap),
          Text(l.authInviteComingBody, style: sheetContext.jiabu.type.body),
          SizedBox(height: sheetContext.jiabu.decor.sectionBottom),
          FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(l.authInviteClose),
          ),
        ],
      );
    },
  );
}
