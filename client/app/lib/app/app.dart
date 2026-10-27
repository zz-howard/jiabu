import 'package:flutter/material.dart';
import 'package:jiabu/features/home/view/blank_screen.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: JiabuTheme.light(),
    home: const BlankScreen(),
  );
}
