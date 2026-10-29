import 'package:flutter/material.dart';

@immutable
class JiabuType extends ThemeExtension<JiabuType> {
  const new({
    this.pageTitle = const TextStyle(
      fontFamily: serifFamily,
      fontSize: 25,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
    this.subtitle = const TextStyle(
      fontFamily: handFamily,
      fontSize: 14,
      height: 1.25,
      fontWeight: FontWeight.w500,
    ),
    this.englishSubtitle = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    this.sectionTitle = const TextStyle(
      fontFamily: serifFamily,
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
    this.cardTitle = const TextStyle(
      fontFamily: serifFamily,
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    this.question = const TextStyle(
      fontFamily: serifFamily,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w700,
    ),
    this.body = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 15,
      height: 1.55,
    ),
    this.chat = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 15,
      height: 1.7,
    ),
    this.listTitle = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    this.secondary = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 13,
      height: 1.5,
    ),
    this.caption = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 12,
      height: 1.4,
    ),
    this.badge = const TextStyle(
      fontFamily: systemSansFamily,
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w700,
    ),
    this.heroAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 62,
      height: .95,
      fontWeight: FontWeight.w600,
    ),
    this.detailAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 58,
      height: 1,
      letterSpacing: 1.74,
      fontWeight: FontWeight.w600,
    ),
    this.recordAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 40,
      height: 1,
      letterSpacing: .8,
      fontWeight: FontWeight.w600,
    ),
    this.balanceAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 34,
      height: 1,
      fontWeight: FontWeight.w600,
    ),
    this.listAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 24,
      height: 1,
      fontWeight: FontWeight.w600,
    ),
    this.inlineAmount = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 17,
      height: 1,
      fontWeight: FontWeight.w600,
    ),
    this.date = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    this.tapeDate = const TextStyle(
      fontFamily: numeralsFamily,
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
    this.mono = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.5,
    ),
  });

  TextStyle get pinDigit => body.copyWith(fontSize: 24, height: 1);

  static const numeralsFamily = 'packages/jiabu_design/Caveat';
  static const handFamily = 'packages/jiabu_design/JiabuHand';
  static const serifFamily = 'packages/jiabu_design/NotoSerifSC';
  // Android's system sans alias includes its complete CJK fallback chain.
  // Tests register the fixed complete Sans fixture under this same alias.
  static const systemSansFamily = 'sans-serif';

  final TextStyle pageTitle;
  final TextStyle subtitle;
  final TextStyle englishSubtitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle question;
  final TextStyle body;
  final TextStyle chat;
  final TextStyle listTitle;
  final TextStyle secondary;
  final TextStyle caption;
  final TextStyle badge;
  final TextStyle heroAmount;
  final TextStyle detailAmount;
  final TextStyle recordAmount;
  final TextStyle balanceAmount;
  final TextStyle listAmount;
  final TextStyle inlineAmount;
  final TextStyle date;
  final TextStyle tapeDate;
  final TextStyle mono;

  @override
  JiabuType copyWith({
    TextStyle? pageTitle,
    TextStyle? subtitle,
    TextStyle? englishSubtitle,
    TextStyle? sectionTitle,
    TextStyle? cardTitle,
    TextStyle? question,
    TextStyle? body,
    TextStyle? chat,
    TextStyle? listTitle,
    TextStyle? secondary,
    TextStyle? caption,
    TextStyle? badge,
    TextStyle? heroAmount,
    TextStyle? detailAmount,
    TextStyle? recordAmount,
    TextStyle? balanceAmount,
    TextStyle? listAmount,
    TextStyle? inlineAmount,
    TextStyle? date,
    TextStyle? tapeDate,
    TextStyle? mono,
  }) => JiabuType(
    pageTitle: pageTitle ?? this.pageTitle,
    subtitle: subtitle ?? this.subtitle,
    englishSubtitle: englishSubtitle ?? this.englishSubtitle,
    sectionTitle: sectionTitle ?? this.sectionTitle,
    cardTitle: cardTitle ?? this.cardTitle,
    question: question ?? this.question,
    body: body ?? this.body,
    chat: chat ?? this.chat,
    listTitle: listTitle ?? this.listTitle,
    secondary: secondary ?? this.secondary,
    caption: caption ?? this.caption,
    badge: badge ?? this.badge,
    heroAmount: heroAmount ?? this.heroAmount,
    detailAmount: detailAmount ?? this.detailAmount,
    recordAmount: recordAmount ?? this.recordAmount,
    balanceAmount: balanceAmount ?? this.balanceAmount,
    listAmount: listAmount ?? this.listAmount,
    inlineAmount: inlineAmount ?? this.inlineAmount,
    date: date ?? this.date,
    tapeDate: tapeDate ?? this.tapeDate,
    mono: mono ?? this.mono,
  );

  @override
  JiabuType lerp(JiabuType? other, double t) {
    if (other == null) {
      return this;
    }
    return JiabuType(
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t) ?? pageTitle,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t) ?? subtitle,
      englishSubtitle:
          TextStyle.lerp(englishSubtitle, other.englishSubtitle, t) ??
          englishSubtitle,
      sectionTitle:
          TextStyle.lerp(sectionTitle, other.sectionTitle, t) ?? sectionTitle,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t) ?? cardTitle,
      question: TextStyle.lerp(question, other.question, t) ?? question,
      body: TextStyle.lerp(body, other.body, t) ?? body,
      chat: TextStyle.lerp(chat, other.chat, t) ?? chat,
      listTitle: TextStyle.lerp(listTitle, other.listTitle, t) ?? listTitle,
      secondary: TextStyle.lerp(secondary, other.secondary, t) ?? secondary,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
      badge: TextStyle.lerp(badge, other.badge, t) ?? badge,
      heroAmount: TextStyle.lerp(heroAmount, other.heroAmount, t) ?? heroAmount,
      detailAmount:
          TextStyle.lerp(detailAmount, other.detailAmount, t) ?? detailAmount,
      recordAmount:
          TextStyle.lerp(recordAmount, other.recordAmount, t) ?? recordAmount,
      balanceAmount:
          TextStyle.lerp(balanceAmount, other.balanceAmount, t) ??
          balanceAmount,
      listAmount: TextStyle.lerp(listAmount, other.listAmount, t) ?? listAmount,
      inlineAmount:
          TextStyle.lerp(inlineAmount, other.inlineAmount, t) ?? inlineAmount,
      date: TextStyle.lerp(date, other.date, t) ?? date,
      tapeDate: TextStyle.lerp(tapeDate, other.tapeDate, t) ?? tapeDate,
      mono: TextStyle.lerp(mono, other.mono, t) ?? mono,
    );
  }
}
