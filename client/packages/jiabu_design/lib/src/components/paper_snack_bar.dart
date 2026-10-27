import 'package:flutter/material.dart';

import 'package:jiabu_design/src/theme_context.dart';

enum PaperSnackPosition { navigation, chat }

class PaperSnackBar extends StatelessWidget {
  const new({required this.message, this.actionLabel, this.onAction, super.key})
    : assert(
        (actionLabel == null) == (onAction == null),
        'actionLabel and onAction must be given together',
      );

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const visibleDuration = Duration(seconds: 5);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show({
    required BuildContext context,
    required String message,
    PaperSnackPosition position = PaperSnackPosition.navigation,
    String? actionLabel,
    VoidCallback? onAction,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: visibleDuration,
      // The undo action lives in custom content, so Material cannot see it.
      // Keep the bar until the action or a dismissal when a screen reader or
      // switch access is driving navigation.
      persist: onAction != null && MediaQuery.accessibleNavigationOf(context),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        position == PaperSnackPosition.chat ? 150 : 92,
      ),
      padding: EdgeInsets.zero,
      backgroundColor: context.jiabu.colors.snackBg,
      elevation: 0,
      content: PaperSnackBar(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction();
              },
      ),
    ),
    snackBarAnimationStyle: AnimationStyle(
      duration: context.jiabu.motion.snack,
      reverseDuration: context.jiabu.motion.snack,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final messageWidget = Text(
      message,
      style: context.jiabu.type.secondary.copyWith(
        color: context.jiabu.colors.snackInk,
      ),
    );
    final action = actionLabel == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.jiabu.colors.snackAction,
            ),
            onPressed: onAction,
            child: Text(actionLabel!),
          );
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 19.5;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.fromLTRB(
        16,
        action == null || largeText ? 6 : 0,
        8,
        action == null || largeText ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: context.jiabu.colors.snackBg,
        borderRadius: BorderRadius.circular(context.jiabu.decor.snackRadius),
      ),
      child: action == null
          ? Align(
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: messageWidget,
            )
          : largeText
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                messageWidget,
                Align(alignment: Alignment.centerRight, child: action),
              ],
            )
          : Row(
              children: [
                Expanded(child: messageWidget),
                const SizedBox(width: 12),
                action,
              ],
            ),
    );
  }
}
