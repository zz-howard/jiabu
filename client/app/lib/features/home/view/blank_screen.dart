import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

class BlankScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox(
        key: Key('blank-accent'),
        width: 96,
        height: 96,
        child: ColoredBox(color: JiabuColors.accent),
      ),
    ),
  );
}
