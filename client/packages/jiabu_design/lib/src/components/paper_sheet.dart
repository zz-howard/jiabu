import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/tape.dart';
import 'package:jiabu_design/src/theme_context.dart';

class PaperSheet extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.jiabu.colors.paper,
    barrierColor: context.jiabu.colors.scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: context.jiabu.motion.sheet,
      reverseDuration: context.jiabu.motion.sheet,
    ),
    builder: (sheetContext) => PaperSheet(child: builder(sheetContext)),
  );

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: math.max(
        0,
        MediaQuery.sizeOf(context).height * .88 -
            MediaQuery.viewInsetsOf(context).bottom,
      ),
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
    ),
  );
}
