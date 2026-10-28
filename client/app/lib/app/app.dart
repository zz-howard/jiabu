import 'package:flutter/material.dart';
import 'package:jiabu/features/home/view/blank_screen.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuApp extends StatelessWidget {
  const JiabuApp({this.home, super.key});

  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: JiabuTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home ?? const BlankScreen(),
  );
}
