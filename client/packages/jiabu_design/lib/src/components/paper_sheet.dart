// Compatibility is required for one migration window; production usage is
// rejected by tool/check_rules.dart.
// ignore_for_file: remove_deprecations_in_breaking_versions

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/tape.dart';
import 'package:jiabu_design/src/theme_context.dart';

@Deprecated('Use JiabuSheet')
class PaperSheet extends StatelessWidget {
  @Deprecated('Use JiabuSheet')
  const PaperSheet({required this.child, this.footer, super.key});

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
        final sheet = PaperSheet(
          footer: footerBuilder?.call(sheetContext),
          child: builder(sheetContext),
        );
        return wrapperBuilder?.call(sheetContext, sheet) ?? sheet;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
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
                      padding: const EdgeInsets.only(top: 10, bottom: 12),
                      child: Tape(
                        degrees: 0,
                        width: context.jiabu.decor.handleWidth,
                        height: context.jiabu.decor.handleHeight,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.all(context.jiabu.decor.cardInset),
                child: footer,
              ),
          ],
        ),
      ),
    ),
  );
}
