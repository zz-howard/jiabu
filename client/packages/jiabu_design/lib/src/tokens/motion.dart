import 'package:flutter/material.dart';

@immutable
class JiabuMotion extends ThemeExtension<JiabuMotion> {
  const new({
    this.sheet = const Duration(milliseconds: 260),
    this.scrim = const Duration(milliseconds: 220),
    this.snack = const Duration(milliseconds: 220),
    this.space = const Duration(milliseconds: 250),
    this.send = const Duration(milliseconds: 200),
    this.cardIn = const Duration(milliseconds: 220),
    this.typing = const Duration(milliseconds: 1000),
    this.processing = const Duration(milliseconds: 800),
    this.sheetCurve = const Cubic(.2, .8, .2, 1),
    this.transitionCurve = Curves.easeOut,
  });

  final Duration sheet;
  final Duration scrim;
  final Duration snack;
  final Duration space;
  final Duration send;
  final Duration cardIn;
  final Duration typing;
  final Duration processing;
  final Curve sheetCurve;
  final Curve transitionCurve;

  JiabuMotion get reduced => copyWith(
    sheet: Duration.zero,
    scrim: Duration.zero,
    snack: Duration.zero,
    space: Duration.zero,
    send: Duration.zero,
    cardIn: Duration.zero,
    typing: Duration.zero,
    processing: Duration.zero,
  );

  @override
  JiabuMotion copyWith({
    Duration? sheet,
    Duration? scrim,
    Duration? snack,
    Duration? space,
    Duration? send,
    Duration? cardIn,
    Duration? typing,
    Duration? processing,
    Curve? sheetCurve,
    Curve? transitionCurve,
  }) => JiabuMotion(
    sheet: sheet ?? this.sheet,
    scrim: scrim ?? this.scrim,
    snack: snack ?? this.snack,
    space: space ?? this.space,
    send: send ?? this.send,
    cardIn: cardIn ?? this.cardIn,
    typing: typing ?? this.typing,
    processing: processing ?? this.processing,
    sheetCurve: sheetCurve ?? this.sheetCurve,
    transitionCurve: transitionCurve ?? this.transitionCurve,
  );

  @override
  JiabuMotion lerp(JiabuMotion? other, double t) {
    if (other == null) {
      return this;
    }
    return JiabuMotion(
      sheet: _duration(sheet, other.sheet, t),
      scrim: _duration(scrim, other.scrim, t),
      snack: _duration(snack, other.snack, t),
      space: _duration(space, other.space, t),
      send: _duration(send, other.send, t),
      cardIn: _duration(cardIn, other.cardIn, t),
      typing: _duration(typing, other.typing, t),
      processing: _duration(processing, other.processing, t),
      sheetCurve: t < .5 ? sheetCurve : other.sheetCurve,
      transitionCurve: t < .5 ? transitionCurve : other.transitionCurve,
    );
  }
}

Duration _duration(Duration a, Duration b, double t) => Duration(
  microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
      .round(),
);
