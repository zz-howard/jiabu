import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:jiabu_design/src/tokens/colors.dart';

@immutable
class JiabuDecor extends ThemeExtension<JiabuDecor> {
  const new({
    this.pageInset = 18,
    this.narrowHeaderInset = 14,
    this.compactHeaderInset = 10,
    this.cardInset = 16,
    this.recordActionsInset = 4,
    this.heroInsetY = 24,
    this.heroInsetX = 20,
    this.cardGap = 12,
    this.gridGap = 14,
    this.sectionTop = 30,
    this.sectionBottom = 12,
    this.messageGap = 6,
    this.aiTop = 6,
    this.aiBottom = 12,
    this.rowMinHeight = 66,
    this.rowInset = 14,
    this.valueRowMinHeight = 30,
    this.cardRadius = 3,
    this.photoRadius = 2,
    this.noteRadius = 2,
    this.fieldRadius = 10,
    this.searchRadius = 12,
    this.chipRadius = 8,
    this.sheetRadius = 20,
    this.snackRadius = 4,
    this.tapeWidth = 76,
    this.tapeHeight = 22,
    this.handleWidth = 74,
    this.handleHeight = 20,
    this.stickerSize = 40,
    this.compactStickerSize = 36,
    this.stickerBorder = 2.5,
    this.stickerStroke = 1.9,
    this.stampHeight = 24,
    this.stampBorder = 1.8,
    this.stampRadius = 5,
    this.stampOpacity = 0.92,
    this.photoBorder = 9,
    this.photoBottom = 34,
    this.circleStroke = 2.4,
    this.strikeStroke = 2,
    this.dotStep = 18,
    this.dotRadius = 1.1,
    this.marginX = 30,
    this.tapeTilt = -5,
    this.stickerTilt = -6,
    this.stampTilt = -5,
    this.photoTilt = 2,
    this.strikeTilt = -2.5,
    this.noteAmp = 0.8,
    this.heroTilt = -0.6,
    this.personalTilt = -0.8,
    this.inputNoteTilt = -0.6,
    this.answerOddTilt = -1,
    this.answerEvenTilt = 0.8,
    this.logoTilt = -8,
    this.dateTilt = 1.5,
    this.tapeA = JiabuColors.defaultTapeA,
    this.tapeB = JiabuColors.defaultTapeB,
    this.tape2 = JiabuColors.defaultTape2,
    this.tape3 = JiabuColors.defaultTape3,
    this.stickerShadow = _stickerShadow,
    this.cardShadow = _cardShadow,
    this.heroShadow = _heroShadow,
    this.sheetShadow = _sheetShadow,
  });

  factory paper(JiabuColors colors) => JiabuDecor(
    tapeA: colors.tapeA,
    tapeB: colors.tapeB,
    tape2: colors.tape2,
    tape3: colors.tape3,
    stickerShadow: [
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .22),
        offset: const Offset(0, 1),
        blurRadius: 1.5,
      ),
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .35),
        offset: const Offset(0, 4),
        blurRadius: 8,
        spreadRadius: -4,
      ),
    ],
    cardShadow: [
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .08),
        offset: const Offset(0, 1),
        blurRadius: 1,
      ),
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .42),
        offset: const Offset(0, 12),
        blurRadius: 20,
        spreadRadius: -12,
      ),
    ],
    heroShadow: [
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .08),
        offset: const Offset(0, 1),
        blurRadius: 1,
      ),
      BoxShadow(
        color: colors.shadowInk.withValues(alpha: .5),
        offset: const Offset(0, 16),
        blurRadius: 26,
        spreadRadius: -16,
      ),
    ],
    sheetShadow: [
      BoxShadow(
        color: colors.black.withValues(alpha: .12),
        offset: const Offset(0, -8),
        blurRadius: 30,
      ),
    ],
  );

  final double pageInset;
  final double narrowHeaderInset;
  final double compactHeaderInset;
  final double cardInset;
  final double recordActionsInset;
  final double heroInsetY;
  final double heroInsetX;
  final double cardGap;
  final double gridGap;
  final double sectionTop;
  final double sectionBottom;
  final double messageGap;
  final double aiTop;
  final double aiBottom;
  final double rowMinHeight;
  final double rowInset;
  final double valueRowMinHeight;
  final double cardRadius;
  final double photoRadius;
  final double noteRadius;
  final double fieldRadius;
  final double searchRadius;
  final double chipRadius;
  final double sheetRadius;
  final double snackRadius;
  final double tapeWidth;
  final double tapeHeight;
  final double handleWidth;
  final double handleHeight;
  final double stickerSize;
  final double compactStickerSize;
  final double stickerBorder;
  final double stickerStroke;
  final double stampHeight;
  final double stampBorder;
  final double stampRadius;
  final double stampOpacity;
  final double photoBorder;
  final double photoBottom;
  final double circleStroke;
  final double strikeStroke;
  final double dotStep;
  final double dotRadius;
  final double marginX;
  final double tapeTilt;
  final double stickerTilt;
  final double stampTilt;
  final double photoTilt;
  final double strikeTilt;
  final double noteAmp;
  final double heroTilt;
  final double personalTilt;
  final double inputNoteTilt;
  final double answerOddTilt;
  final double answerEvenTilt;
  final double logoTilt;
  final double dateTilt;
  final Color tapeA;
  final Color tapeB;
  final Color tape2;
  final Color tape3;
  final List<BoxShadow> stickerShadow;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> heroShadow;
  final List<BoxShadow> sheetShadow;

  @override
  JiabuDecor copyWith({
    double? pageInset,
    double? narrowHeaderInset,
    double? compactHeaderInset,
    double? cardInset,
    double? recordActionsInset,
    double? heroInsetY,
    double? heroInsetX,
    double? cardGap,
    double? gridGap,
    double? sectionTop,
    double? sectionBottom,
    double? messageGap,
    double? aiTop,
    double? aiBottom,
    double? rowMinHeight,
    double? rowInset,
    double? valueRowMinHeight,
    double? cardRadius,
    double? photoRadius,
    double? noteRadius,
    double? fieldRadius,
    double? searchRadius,
    double? chipRadius,
    double? sheetRadius,
    double? snackRadius,
    double? tapeWidth,
    double? tapeHeight,
    double? handleWidth,
    double? handleHeight,
    double? stickerSize,
    double? compactStickerSize,
    double? stickerBorder,
    double? stickerStroke,
    double? stampHeight,
    double? stampBorder,
    double? stampRadius,
    double? stampOpacity,
    double? photoBorder,
    double? photoBottom,
    double? circleStroke,
    double? strikeStroke,
    double? dotStep,
    double? dotRadius,
    double? marginX,
    double? tapeTilt,
    double? stickerTilt,
    double? stampTilt,
    double? photoTilt,
    double? strikeTilt,
    double? noteAmp,
    double? heroTilt,
    double? personalTilt,
    double? inputNoteTilt,
    double? answerOddTilt,
    double? answerEvenTilt,
    double? logoTilt,
    double? dateTilt,
    Color? tapeA,
    Color? tapeB,
    Color? tape2,
    Color? tape3,
    List<BoxShadow>? stickerShadow,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? heroShadow,
    List<BoxShadow>? sheetShadow,
  }) => JiabuDecor(
    pageInset: pageInset ?? this.pageInset,
    narrowHeaderInset: narrowHeaderInset ?? this.narrowHeaderInset,
    compactHeaderInset: compactHeaderInset ?? this.compactHeaderInset,
    cardInset: cardInset ?? this.cardInset,
    recordActionsInset: recordActionsInset ?? this.recordActionsInset,
    heroInsetY: heroInsetY ?? this.heroInsetY,
    heroInsetX: heroInsetX ?? this.heroInsetX,
    cardGap: cardGap ?? this.cardGap,
    gridGap: gridGap ?? this.gridGap,
    sectionTop: sectionTop ?? this.sectionTop,
    sectionBottom: sectionBottom ?? this.sectionBottom,
    messageGap: messageGap ?? this.messageGap,
    aiTop: aiTop ?? this.aiTop,
    aiBottom: aiBottom ?? this.aiBottom,
    rowMinHeight: rowMinHeight ?? this.rowMinHeight,
    rowInset: rowInset ?? this.rowInset,
    valueRowMinHeight: valueRowMinHeight ?? this.valueRowMinHeight,
    cardRadius: cardRadius ?? this.cardRadius,
    photoRadius: photoRadius ?? this.photoRadius,
    noteRadius: noteRadius ?? this.noteRadius,
    fieldRadius: fieldRadius ?? this.fieldRadius,
    searchRadius: searchRadius ?? this.searchRadius,
    chipRadius: chipRadius ?? this.chipRadius,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    snackRadius: snackRadius ?? this.snackRadius,
    tapeWidth: tapeWidth ?? this.tapeWidth,
    tapeHeight: tapeHeight ?? this.tapeHeight,
    handleWidth: handleWidth ?? this.handleWidth,
    handleHeight: handleHeight ?? this.handleHeight,
    stickerSize: stickerSize ?? this.stickerSize,
    compactStickerSize: compactStickerSize ?? this.compactStickerSize,
    stickerBorder: stickerBorder ?? this.stickerBorder,
    stickerStroke: stickerStroke ?? this.stickerStroke,
    stampHeight: stampHeight ?? this.stampHeight,
    stampBorder: stampBorder ?? this.stampBorder,
    stampRadius: stampRadius ?? this.stampRadius,
    stampOpacity: stampOpacity ?? this.stampOpacity,
    photoBorder: photoBorder ?? this.photoBorder,
    photoBottom: photoBottom ?? this.photoBottom,
    circleStroke: circleStroke ?? this.circleStroke,
    strikeStroke: strikeStroke ?? this.strikeStroke,
    dotStep: dotStep ?? this.dotStep,
    dotRadius: dotRadius ?? this.dotRadius,
    marginX: marginX ?? this.marginX,
    tapeTilt: tapeTilt ?? this.tapeTilt,
    stickerTilt: stickerTilt ?? this.stickerTilt,
    stampTilt: stampTilt ?? this.stampTilt,
    photoTilt: photoTilt ?? this.photoTilt,
    strikeTilt: strikeTilt ?? this.strikeTilt,
    noteAmp: noteAmp ?? this.noteAmp,
    heroTilt: heroTilt ?? this.heroTilt,
    personalTilt: personalTilt ?? this.personalTilt,
    inputNoteTilt: inputNoteTilt ?? this.inputNoteTilt,
    answerOddTilt: answerOddTilt ?? this.answerOddTilt,
    answerEvenTilt: answerEvenTilt ?? this.answerEvenTilt,
    logoTilt: logoTilt ?? this.logoTilt,
    dateTilt: dateTilt ?? this.dateTilt,
    tapeA: tapeA ?? this.tapeA,
    tapeB: tapeB ?? this.tapeB,
    tape2: tape2 ?? this.tape2,
    tape3: tape3 ?? this.tape3,
    stickerShadow: stickerShadow ?? this.stickerShadow,
    cardShadow: cardShadow ?? this.cardShadow,
    heroShadow: heroShadow ?? this.heroShadow,
    sheetShadow: sheetShadow ?? this.sheetShadow,
  );

  @override
  JiabuDecor lerp(JiabuDecor? other, double t) {
    if (other == null) {
      return this;
    }
    return JiabuDecor(
      pageInset: ui.lerpDouble(pageInset, other.pageInset, t) ?? pageInset,
      narrowHeaderInset:
          ui.lerpDouble(narrowHeaderInset, other.narrowHeaderInset, t) ??
          narrowHeaderInset,
      compactHeaderInset:
          ui.lerpDouble(compactHeaderInset, other.compactHeaderInset, t) ??
          compactHeaderInset,
      cardInset: ui.lerpDouble(cardInset, other.cardInset, t) ?? cardInset,
      recordActionsInset:
          ui.lerpDouble(recordActionsInset, other.recordActionsInset, t) ??
          recordActionsInset,
      heroInsetY: ui.lerpDouble(heroInsetY, other.heroInsetY, t) ?? heroInsetY,
      heroInsetX: ui.lerpDouble(heroInsetX, other.heroInsetX, t) ?? heroInsetX,
      cardGap: ui.lerpDouble(cardGap, other.cardGap, t) ?? cardGap,
      gridGap: ui.lerpDouble(gridGap, other.gridGap, t) ?? gridGap,
      sectionTop: ui.lerpDouble(sectionTop, other.sectionTop, t) ?? sectionTop,
      sectionBottom:
          ui.lerpDouble(sectionBottom, other.sectionBottom, t) ?? sectionBottom,
      messageGap: ui.lerpDouble(messageGap, other.messageGap, t) ?? messageGap,
      aiTop: ui.lerpDouble(aiTop, other.aiTop, t) ?? aiTop,
      aiBottom: ui.lerpDouble(aiBottom, other.aiBottom, t) ?? aiBottom,
      rowMinHeight:
          ui.lerpDouble(rowMinHeight, other.rowMinHeight, t) ?? rowMinHeight,
      rowInset: ui.lerpDouble(rowInset, other.rowInset, t) ?? rowInset,
      valueRowMinHeight:
          ui.lerpDouble(valueRowMinHeight, other.valueRowMinHeight, t) ??
          valueRowMinHeight,
      cardRadius: ui.lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      photoRadius:
          ui.lerpDouble(photoRadius, other.photoRadius, t) ?? photoRadius,
      noteRadius: ui.lerpDouble(noteRadius, other.noteRadius, t) ?? noteRadius,
      fieldRadius:
          ui.lerpDouble(fieldRadius, other.fieldRadius, t) ?? fieldRadius,
      searchRadius:
          ui.lerpDouble(searchRadius, other.searchRadius, t) ?? searchRadius,
      chipRadius: ui.lerpDouble(chipRadius, other.chipRadius, t) ?? chipRadius,
      sheetRadius:
          ui.lerpDouble(sheetRadius, other.sheetRadius, t) ?? sheetRadius,
      snackRadius:
          ui.lerpDouble(snackRadius, other.snackRadius, t) ?? snackRadius,
      tapeWidth: ui.lerpDouble(tapeWidth, other.tapeWidth, t) ?? tapeWidth,
      tapeHeight: ui.lerpDouble(tapeHeight, other.tapeHeight, t) ?? tapeHeight,
      handleWidth:
          ui.lerpDouble(handleWidth, other.handleWidth, t) ?? handleWidth,
      handleHeight:
          ui.lerpDouble(handleHeight, other.handleHeight, t) ?? handleHeight,
      stickerSize:
          ui.lerpDouble(stickerSize, other.stickerSize, t) ?? stickerSize,
      compactStickerSize:
          ui.lerpDouble(compactStickerSize, other.compactStickerSize, t) ??
          compactStickerSize,
      stickerBorder:
          ui.lerpDouble(stickerBorder, other.stickerBorder, t) ?? stickerBorder,
      stickerStroke:
          ui.lerpDouble(stickerStroke, other.stickerStroke, t) ?? stickerStroke,
      stampHeight:
          ui.lerpDouble(stampHeight, other.stampHeight, t) ?? stampHeight,
      stampBorder:
          ui.lerpDouble(stampBorder, other.stampBorder, t) ?? stampBorder,
      stampRadius:
          ui.lerpDouble(stampRadius, other.stampRadius, t) ?? stampRadius,
      stampOpacity:
          ui.lerpDouble(stampOpacity, other.stampOpacity, t) ?? stampOpacity,
      photoBorder:
          ui.lerpDouble(photoBorder, other.photoBorder, t) ?? photoBorder,
      photoBottom:
          ui.lerpDouble(photoBottom, other.photoBottom, t) ?? photoBottom,
      circleStroke:
          ui.lerpDouble(circleStroke, other.circleStroke, t) ?? circleStroke,
      strikeStroke:
          ui.lerpDouble(strikeStroke, other.strikeStroke, t) ?? strikeStroke,
      dotStep: ui.lerpDouble(dotStep, other.dotStep, t) ?? dotStep,
      dotRadius: ui.lerpDouble(dotRadius, other.dotRadius, t) ?? dotRadius,
      marginX: ui.lerpDouble(marginX, other.marginX, t) ?? marginX,
      tapeTilt: ui.lerpDouble(tapeTilt, other.tapeTilt, t) ?? tapeTilt,
      stickerTilt:
          ui.lerpDouble(stickerTilt, other.stickerTilt, t) ?? stickerTilt,
      stampTilt: ui.lerpDouble(stampTilt, other.stampTilt, t) ?? stampTilt,
      photoTilt: ui.lerpDouble(photoTilt, other.photoTilt, t) ?? photoTilt,
      strikeTilt: ui.lerpDouble(strikeTilt, other.strikeTilt, t) ?? strikeTilt,
      noteAmp: ui.lerpDouble(noteAmp, other.noteAmp, t) ?? noteAmp,
      heroTilt: ui.lerpDouble(heroTilt, other.heroTilt, t) ?? heroTilt,
      personalTilt:
          ui.lerpDouble(personalTilt, other.personalTilt, t) ?? personalTilt,
      inputNoteTilt:
          ui.lerpDouble(inputNoteTilt, other.inputNoteTilt, t) ?? inputNoteTilt,
      answerOddTilt:
          ui.lerpDouble(answerOddTilt, other.answerOddTilt, t) ?? answerOddTilt,
      answerEvenTilt:
          ui.lerpDouble(answerEvenTilt, other.answerEvenTilt, t) ??
          answerEvenTilt,
      logoTilt: ui.lerpDouble(logoTilt, other.logoTilt, t) ?? logoTilt,
      dateTilt: ui.lerpDouble(dateTilt, other.dateTilt, t) ?? dateTilt,
      tapeA: Color.lerp(tapeA, other.tapeA, t) ?? tapeA,
      tapeB: Color.lerp(tapeB, other.tapeB, t) ?? tapeB,
      tape2: Color.lerp(tape2, other.tape2, t) ?? tape2,
      tape3: Color.lerp(tape3, other.tape3, t) ?? tape3,
      stickerShadow:
          BoxShadow.lerpList(stickerShadow, other.stickerShadow, t) ??
          stickerShadow,
      cardShadow:
          BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
      heroShadow:
          BoxShadow.lerpList(heroShadow, other.heroShadow, t) ?? heroShadow,
      sheetShadow:
          BoxShadow.lerpList(sheetShadow, other.sheetShadow, t) ?? sheetShadow,
    );
  }
}

const _stickerShadow = [
  BoxShadow(
    color: JiabuColors.stickerShadowNear,
    offset: Offset(0, 1),
    blurRadius: 1.5,
  ),
  BoxShadow(
    color: JiabuColors.stickerShadowFar,
    offset: Offset(0, 4),
    blurRadius: 8,
    spreadRadius: -4,
  ),
];
const _cardShadow = [
  BoxShadow(
    color: JiabuColors.cardShadowNear,
    offset: Offset(0, 1),
    blurRadius: 1,
  ),
  BoxShadow(
    color: JiabuColors.cardShadowFar,
    offset: Offset(0, 12),
    blurRadius: 20,
    spreadRadius: -12,
  ),
];
const _heroShadow = [
  BoxShadow(
    color: JiabuColors.cardShadowNear,
    offset: Offset(0, 1),
    blurRadius: 1,
  ),
  BoxShadow(
    color: JiabuColors.heroShadowFar,
    offset: Offset(0, 16),
    blurRadius: 26,
    spreadRadius: -16,
  ),
];
const _sheetShadow = [
  BoxShadow(
    color: JiabuColors.sheetShadowColor,
    offset: Offset(0, -8),
    blurRadius: 30,
  ),
];
