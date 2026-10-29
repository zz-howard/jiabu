import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AuthProgress extends StatelessWidget {
  const AuthProgress({required this.step, this.total = 3, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    return Semantics(
      label: AppLocalizations.of(context).handAuthStep(step, total),
      child: ExcludeSemantics(
        child: Row(
          key: const Key('auth-progress'),
          children: [
            for (var index = 1; index <= total; index++) ...[
              AnimatedContainer(
                duration: context.jiabu.motion.cardIn,
                width: index == step ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == step
                      ? Theme.of(context).colorScheme.primary
                      : colors.lineStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: JiabuSpacing.sm),
            ],
            HandText(AppLocalizations.of(context).handAuthStep(step, total)),
          ],
        ),
      ),
    );
  }
}
