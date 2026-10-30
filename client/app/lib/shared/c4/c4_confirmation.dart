import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class C4Confirmation extends StatelessWidget {
  const C4Confirmation({
    required this.message,
    required this.onConfirm,
    super.key,
  });

  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => JiabuStack(
    children: [
      JiabuStackItem.content(
        child: Text(message, style: context.jiabu.type.body),
      ),
      JiabuStackItem.action(
        child: FilledButton(
          onPressed: onConfirm,
          child: Text(AppLocalizations.of(context).c4Confirm),
        ),
      ),
    ],
  );
}
