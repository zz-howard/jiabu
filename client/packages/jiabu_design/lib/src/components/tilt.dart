import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class Tilt extends StatelessWidget {
  const new({required this.degrees, required this.child, super.key});

  final double degrees;
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: degrees * math.pi / 180,
    transformHitTests: false,
    child: child,
  );
}
