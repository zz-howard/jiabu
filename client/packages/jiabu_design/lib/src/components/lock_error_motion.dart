import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/theme_context.dart';

class LockErrorMotion extends StatelessWidget {
  const LockErrorMotion({required this.error, required this.child, super.key});

  final bool error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!error || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.jiabu.motion.cardIn,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(
          math.sin(progress * math.pi * 6) * 3 * (1 - progress),
          0,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
