import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/tape.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuSheet extends StatelessWidget {
  const JiabuSheet({required this.child, this.footer, super.key});
  final Widget child;
  final Widget? footer;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    WidgetBuilder? footerBuilder,
    bool dismissible = true,
    Widget Function(BuildContext, Widget)? wrapperBuilder,
  }) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: context.jiabu.colors.paper,
      barrierColor: context.jiabu.colors.scrim,
      sheetAnimationStyle: AnimationStyle(
        duration: context.jiabu.motion.sheet,
        reverseDuration: context.jiabu.motion.sheet,
        curve: context.jiabu.motion.sheetCurve,
        reverseCurve: context.jiabu.motion.sheetCurve.flipped,
      ),
      builder: (sheetContext) {
        final sheet = JiabuSheet(
          footer: footerBuilder?.call(sheetContext),
          child: builder(sheetContext),
        );
        return wrapperBuilder?.call(sheetContext, sheet) ?? sheet;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('jiabu-sheet'),
    constraints: BoxConstraints(
      maxHeight: math.max(0, MediaQuery.sizeOf(context).height * .88),
    ),
    decoration: BoxDecoration(
      color: context.jiabu.colors.paper,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.jiabu.decor.sheetRadius),
      ),
      boxShadow: context.jiabu.decor.sheetShadow,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: JiabuSpacing.sm,
                        bottom: JiabuSpacing.md,
                      ),
                      child: Tape(
                        degrees: 0,
                        width: context.jiabu.decor.handleWidth,
                        height: context.jiabu.decor.handleHeight,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.jiabu.spacing.page,
                        0,
                        context.jiabu.spacing.page,
                        JiabuSpacing.xl,
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.all(JiabuSpacing.lg),
                child: footer,
              ),
          ],
        ),
      ),
    ),
  );
}
