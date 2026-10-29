import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class SwitchPartitionPrompt extends StatelessWidget {
  const SwitchPartitionPrompt({
    required this.count,
    required this.onContinue,
    required this.onCancel,
    super.key,
  });
  final int count;
  final VoidCallback onContinue;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JiabuSheet(
      child: Padding(
        padding: const EdgeInsets.only(top: JiabuSpacing.cardGap),
        child: Column(
          spacing: JiabuSpacing.cardGap,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.authPendingSwitch(count)),
            FilledButton(
              onPressed: onContinue,
              child: Text(l10n.authContinueSwitch),
            ),
            TextButton(onPressed: onCancel, child: Text(l10n.authCancel)),
          ],
        ),
      ),
    );
  }
}
