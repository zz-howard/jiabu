import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    required this.message,
    required this.actionLabel,
    required this.onOpen,
    required this.mandatory,
    this.onDismiss,
    super.key,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onOpen;
  final bool mandatory;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.jiabu.colors.snackAction,
          ),
          onPressed: onOpen,
          child: Text(actionLabel),
        ),
        if (!mandatory)
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onDismiss,
            icon: JiabuIcon(
              JiabuIcons.uiClose,
              color: context.jiabu.colors.snackInk,
            ),
          ),
      ],
    );
    final text = Text(
      message,
      style: context.jiabu.type.secondary.copyWith(
        color: context.jiabu.colors.snackInk,
      ),
    );
    final large = MediaQuery.textScalerOf(context).scale(13) > 19.5;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: Key(mandatory ? 'update-banner-forced' : 'update-banner'),
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.fromLTRB(
          JiabuSpacing.md,
          0,
          JiabuSpacing.md,
          JiabuSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: JiabuSpacing.md,
          vertical: JiabuSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.jiabu.colors.snackBg,
          borderRadius: BorderRadius.circular(context.jiabu.decor.snackRadius),
        ),
        child: large
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  actions,
                ],
              ),
      ),
    );
  }
}
