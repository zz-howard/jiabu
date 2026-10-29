import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuChatWeaveTheme extends StatelessWidget {
  const JiabuChatWeaveTheme({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    final type = context.jiabu.type;
    final l = AppLocalizations.of(context);
    return ChatWeaveLocalizations(
      locale: Localizations.localeOf(context).languageCode,
      resolve: (key, fallback) => jiabuChatLabel(l, key, fallback),
      child: ChatWeaveTheme(
        data: ChatWeaveThemeData(
          brightness: Brightness.light,
          surface: colors.paper,
          onSurface: colors.ink,
          muted: colors.ink2,
          outline: colors.lineStrong,
          accent: colors.primaryText,
          onAccent: colors.onPrimary,
          warning: colors.warn,
          critical: colors.neg,
          chartPalette: [colors.primary, colors.chartRight],
          body: type.chat.copyWith(color: colors.ink),
          caption: type.caption.copyWith(color: colors.ink2),
          title: type.question.copyWith(color: colors.ink),
          numeric: type.recordAmount.copyWith(color: colors.ink),
          spacing: context.jiabu.decor.cardGap,
          radius: context.jiabu.decor.cardRadius,
        ),
        child: child,
      ),
    );
  }
}
