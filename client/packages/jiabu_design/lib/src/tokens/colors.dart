import 'package:flutter/material.dart';

@immutable
class JiabuColors extends ThemeExtension<JiabuColors> {
  const new({
    this.bg = const Color(0xFFF6EFE2),
    this.paper = const Color(0xFFFFFDF7),
    this.surface2 = const Color(0xFFF4EBDC),
    this.surface3 = const Color(0xFFEADFCC),
    this.line = const Color(0xFFEADFCD),
    this.lineStrong = const Color(0xFFD5C5AD),
    this.rule = const Color.fromRGBO(120, 160, 200, .28),
    this.margin = const Color.fromRGBO(214, 96, 86, .45),
    this.dot = const Color.fromRGBO(150, 112, 76, .24),
    this.ink = const Color(0xFF2B221B),
    this.ink2 = const Color(0xFF5C4F44),
    this.ink3 = const Color(0xFF736457),
    this.primary = const Color(0xFFB4532D),
    this.primaryText = const Color(0xFF9C4423),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.primarySoft = const Color(0xFFF8DCCB),
    this.onPrimarySoft = const Color(0xFF6B2B12),
    this.highlight = const Color.fromRGBO(255, 190, 110, .55),
    this.note = const Color(0xFFFFF0B3),
    this.noteInk = const Color(0xFF3A2E10),
    this.noteEdge = const Color(0xFFF2DC86),
    this.pos = const Color(0xFF36704B),
    this.posSoft = const Color(0xFFDCEBDD),
    this.neg = const Color(0xFFB0392A),
    this.warn = const Color(0xFF875100),
    this.warnSoft = const Color(0xFFF8E6C2),
    this.alert = const Color(0xFFFFE3DA),
    this.alertInk = const Color(0xFF5A3F35),
    this.snackBg = const Color(0xFF2F2620),
    this.snackInk = const Color(0xFFFBF3EA),
    this.snackAction = const Color(0xFFFFC79E),
    this.scrim = const Color.fromRGBO(42, 30, 20, .42),
    this.chartLeft = const Color(0xFFB4532D),
    this.chartRight = const Color(0xFF3E7B8F),
    this.tapeA = const Color.fromRGBO(226, 124, 92, .55),
    this.tapeB = const Color.fromRGBO(250, 214, 190, .72),
    this.tape2 = const Color.fromRGBO(238, 196, 86, .66),
    this.tape3 = const Color.fromRGBO(126, 186, 152, .55),
    this.white = const Color(0xFFFFFFFF),
    this.transparent = const Color(0x00000000),
    this.shadowInk = const Color(0xFF3C2814),
    this.black = const Color(0xFF000000),
    this.spaceAccents = const {
      'terracotta': Color(0xFF9C4423),
      'indigo': Color(0xFF3B5A8C),
      'pine': Color(0xFF36704B),
      'plum': Color(0xFF7A2462),
      'teal': Color(0xFF1C5351),
      'amber': Color(0xFF875100),
      'rouge': Color(0xFF8C2337),
      'wisteria': Color(0xFF4A3570),
    },
    this.stickerBackgrounds = const {
      'food': Color(0xFFFFD9C4),
      'edu': Color(0xFFCFE0F5),
      'health': Color(0xFFF9D0D7),
      'travel': Color(0xFFD3EBCF),
      'home': Color(0xFFFBE6A2),
      'reserve': Color(0xFFE6DBF3),
      'hobby': Color(0xFFF9D6EE),
      'books': Color(0xFFDDE9C8),
      'fit': Color(0xFFCDEBEA),
      'income': Color(0xFFD3EBCF),
      'alloc': Color(0xFFD3EBCF),
      'transfer': Color(0xFFF8DCCB),
      'move': Color(0xFFF8DCCB),
      'doc': Color(0xFFCFE0F5),
      'fund': Color(0xFFFFFFFF),
      'warn': Color(0xFFF8E6C2),
    },
    this.stickerInks = const {
      'food': Color(0xFF8A3A12),
      'edu': Color(0xFF23466F),
      'health': Color(0xFF8C2337),
      'travel': Color(0xFF2B5728),
      'home': Color(0xFF664B00),
      'reserve': Color(0xFF4A3570),
      'hobby': Color(0xFF7A2462),
      'books': Color(0xFF3D541E),
      'fit': Color(0xFF1C5351),
      'income': Color(0xFF2B5728),
      'alloc': Color(0xFF2B5728),
      'transfer': Color(0xFF7A3517),
      'move': Color(0xFF7A3517),
      'doc': Color(0xFF23466F),
      'fund': Color(0xFF9C4423),
      'warn': Color(0xFF875100),
    },
  });

  static const stickerShadowNear = Color.fromRGBO(60, 40, 20, .22);
  static const stickerShadowFar = Color.fromRGBO(60, 40, 20, .35);
  static const cardShadowNear = Color.fromRGBO(60, 40, 20, .08);
  static const cardShadowFar = Color.fromRGBO(60, 40, 20, .42);
  static const tileShadowFar = Color.fromRGBO(60, 40, 20, .45);
  static const heroShadowFar = Color.fromRGBO(60, 40, 20, .5);
  static const sheetShadowColor = Color.fromRGBO(0, 0, 0, .12);

  static const defaultTapeA = Color.fromRGBO(226, 124, 92, .55);
  static const defaultTapeB = Color.fromRGBO(250, 214, 190, .72);
  static const defaultTape2 = Color.fromRGBO(238, 196, 86, .66);
  static const defaultTape3 = Color.fromRGBO(126, 186, 152, .55);

  final Color bg;
  final Color paper;
  final Color surface2;
  final Color surface3;
  final Color line;
  final Color lineStrong;
  final Color rule;
  final Color margin;
  final Color dot;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color primary;
  final Color primaryText;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color highlight;
  final Color note;
  final Color noteInk;
  final Color noteEdge;
  final Color pos;
  final Color posSoft;
  final Color neg;
  final Color warn;
  final Color warnSoft;
  final Color alert;
  final Color alertInk;
  final Color snackBg;
  final Color snackInk;
  final Color snackAction;
  final Color scrim;
  final Color chartLeft;
  final Color chartRight;
  final Color tapeA;
  final Color tapeB;
  final Color tape2;
  final Color tape3;
  final Color white;
  final Color transparent;
  final Color shadowInk;
  final Color black;
  final Map<String, Color> spaceAccents;
  final Map<String, Color> stickerBackgrounds;
  final Map<String, Color> stickerInks;

  @override
  JiabuColors copyWith({
    Color? bg,
    Color? paper,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? lineStrong,
    Color? rule,
    Color? margin,
    Color? dot,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? primary,
    Color? primaryText,
    Color? onPrimary,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? highlight,
    Color? note,
    Color? noteInk,
    Color? noteEdge,
    Color? pos,
    Color? posSoft,
    Color? neg,
    Color? warn,
    Color? warnSoft,
    Color? alert,
    Color? alertInk,
    Color? snackBg,
    Color? snackInk,
    Color? snackAction,
    Color? scrim,
    Color? chartLeft,
    Color? chartRight,
    Color? tapeA,
    Color? tapeB,
    Color? tape2,
    Color? tape3,
    Color? white,
    Color? transparent,
    Color? shadowInk,
    Color? black,
    Map<String, Color>? spaceAccents,
    Map<String, Color>? stickerBackgrounds,
    Map<String, Color>? stickerInks,
  }) => JiabuColors(
    bg: bg ?? this.bg,
    paper: paper ?? this.paper,
    surface2: surface2 ?? this.surface2,
    surface3: surface3 ?? this.surface3,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    rule: rule ?? this.rule,
    margin: margin ?? this.margin,
    dot: dot ?? this.dot,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    primary: primary ?? this.primary,
    primaryText: primaryText ?? this.primaryText,
    onPrimary: onPrimary ?? this.onPrimary,
    primarySoft: primarySoft ?? this.primarySoft,
    onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
    highlight: highlight ?? this.highlight,
    note: note ?? this.note,
    noteInk: noteInk ?? this.noteInk,
    noteEdge: noteEdge ?? this.noteEdge,
    pos: pos ?? this.pos,
    posSoft: posSoft ?? this.posSoft,
    neg: neg ?? this.neg,
    warn: warn ?? this.warn,
    warnSoft: warnSoft ?? this.warnSoft,
    alert: alert ?? this.alert,
    alertInk: alertInk ?? this.alertInk,
    snackBg: snackBg ?? this.snackBg,
    snackInk: snackInk ?? this.snackInk,
    snackAction: snackAction ?? this.snackAction,
    scrim: scrim ?? this.scrim,
    chartLeft: chartLeft ?? this.chartLeft,
    chartRight: chartRight ?? this.chartRight,
    tapeA: tapeA ?? this.tapeA,
    tapeB: tapeB ?? this.tapeB,
    tape2: tape2 ?? this.tape2,
    tape3: tape3 ?? this.tape3,
    white: white ?? this.white,
    transparent: transparent ?? this.transparent,
    shadowInk: shadowInk ?? this.shadowInk,
    black: black ?? this.black,
    spaceAccents: spaceAccents ?? this.spaceAccents,
    stickerBackgrounds: stickerBackgrounds ?? this.stickerBackgrounds,
    stickerInks: stickerInks ?? this.stickerInks,
  );

  @override
  JiabuColors lerp(JiabuColors? other, double t) {
    if (other == null) {
      return this;
    }
    return JiabuColors(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      paper: Color.lerp(paper, other.paper, t) ?? paper,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      surface3: Color.lerp(surface3, other.surface3, t) ?? surface3,
      line: Color.lerp(line, other.line, t) ?? line,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t) ?? lineStrong,
      rule: Color.lerp(rule, other.rule, t) ?? rule,
      margin: Color.lerp(margin, other.margin, t) ?? margin,
      dot: Color.lerp(dot, other.dot, t) ?? dot,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      ink2: Color.lerp(ink2, other.ink2, t) ?? ink2,
      ink3: Color.lerp(ink3, other.ink3, t) ?? ink3,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryText: Color.lerp(primaryText, other.primaryText, t) ?? primaryText,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      onPrimarySoft:
          Color.lerp(onPrimarySoft, other.onPrimarySoft, t) ?? onPrimarySoft,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      note: Color.lerp(note, other.note, t) ?? note,
      noteInk: Color.lerp(noteInk, other.noteInk, t) ?? noteInk,
      noteEdge: Color.lerp(noteEdge, other.noteEdge, t) ?? noteEdge,
      pos: Color.lerp(pos, other.pos, t) ?? pos,
      posSoft: Color.lerp(posSoft, other.posSoft, t) ?? posSoft,
      neg: Color.lerp(neg, other.neg, t) ?? neg,
      warn: Color.lerp(warn, other.warn, t) ?? warn,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t) ?? warnSoft,
      alert: Color.lerp(alert, other.alert, t) ?? alert,
      alertInk: Color.lerp(alertInk, other.alertInk, t) ?? alertInk,
      snackBg: Color.lerp(snackBg, other.snackBg, t) ?? snackBg,
      snackInk: Color.lerp(snackInk, other.snackInk, t) ?? snackInk,
      snackAction: Color.lerp(snackAction, other.snackAction, t) ?? snackAction,
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      chartLeft: Color.lerp(chartLeft, other.chartLeft, t) ?? chartLeft,
      chartRight: Color.lerp(chartRight, other.chartRight, t) ?? chartRight,
      tapeA: Color.lerp(tapeA, other.tapeA, t) ?? tapeA,
      tapeB: Color.lerp(tapeB, other.tapeB, t) ?? tapeB,
      tape2: Color.lerp(tape2, other.tape2, t) ?? tape2,
      tape3: Color.lerp(tape3, other.tape3, t) ?? tape3,
      white: Color.lerp(white, other.white, t) ?? white,
      transparent: Color.lerp(transparent, other.transparent, t) ?? transparent,
      shadowInk: Color.lerp(shadowInk, other.shadowInk, t) ?? shadowInk,
      black: Color.lerp(black, other.black, t) ?? black,
      spaceAccents: _lerpMap(spaceAccents, other.spaceAccents, t),
      stickerBackgrounds: _lerpMap(
        stickerBackgrounds,
        other.stickerBackgrounds,
        t,
      ),
      stickerInks: _lerpMap(stickerInks, other.stickerInks, t),
    );
  }
}

Map<String, Color> _lerpMap(
  Map<String, Color> a,
  Map<String, Color> b,
  double t,
) => Map.unmodifiable({
  for (final key in {...a.keys, ...b.keys})
    key: Color.lerp(a[key], b[key], t) ?? a[key] ?? b[key]!,
});
