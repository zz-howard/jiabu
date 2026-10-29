import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

class BlankScreen extends StatelessWidget {
  const BlankScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        key: const Key('blank-accent'),
        width: 96, // rules:allow-literal B0 visual baseline square
        height: 96, // rules:allow-literal B0 visual baseline square
        child: ColoredBox(color: context.jiabu.colors.primary),
      ),
    ),
  );
}
