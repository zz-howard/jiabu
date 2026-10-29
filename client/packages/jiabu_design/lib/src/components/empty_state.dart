import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_mascot.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuEmptyState extends StatelessWidget {
  const JiabuEmptyState({
    required this.message,
    this.illustration,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final Widget message;
  final Widget? illustration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(JiabuSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration ?? const JiabuMascot(pose: JiabuMascotPose.idle, size: 80),
        const SizedBox(height: JiabuSpacing.md),
        message,
        if (actionLabel != null) ...[
          const SizedBox(height: JiabuSpacing.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
