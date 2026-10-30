/// C3 geometry from design-spec 4.1, 4.7, 4.12a, 4.19 and 4.21.
abstract final class JiabuLedgerMetrics {
  static const double actionExtent = 48;
  static const double recordActionHeight = 44;
  static const double noteActionHeight = 46;
  static const double noteClipSize = 24;
  static const double noteClipTilt = -12;
  static const double narrowWidth = 380;
  static const double navigationHeight = 78;

  /// Width of one half-circle of the bottom bar's torn edge; the scallops
  /// rise half of it above the bar (design-spec 4.7).
  static const double navigationScallop = 14;
  static const double manualHeight = 52;
  static const double manualInset = 16;
  static const double manualBorder = 2;
  static const double manualIcon = 20;
  static const double meDiameter = 32;
  static const double meIcon = 18;
  static const double spaceDot = 8;
  static const double cardDot = 6;
  static const double recordWidth = 332;
  static const double keyIcon = 12;
  static const double navigationIcon = 22;
  static const double footerClearance = 88;
  static const double minimumFieldWidth = 240;

  /// Overview hero (design-spec 4.12a): tapes overlap the top edge by 10,
  /// sit 14 in from each side; the start tape uses the decor tape tilt, the
  /// end (dotted) tape leans the other way.
  static const double heroTapeTop = -10;
  static const double heroTapeInset = 14;
  static const double heroTapeEndTilt = 4;

  /// Purpose-account tiles go two per row only while each tile is at least
  /// this wide times the text scale; otherwise one per row.
  static const double purposeTileMinWidth = 150;

  /// History page (design-spec 4.12, V4): the rounded search card is 52 high
  /// with a 20 magnifier; filter chips are 44 high with a 16 dropdown arrow.
  static const double searchHeight = 52;
  static const double searchIcon = 20;
  static const double chipHeight = 44;
  static const double chipArrow = 16;

  /// The chip row's edge fades (only shown while more chips are hidden on
  /// that side).
  static const double chipFade = 24;

  /// Timeline rows: the sticker sits this far in from the card's left edge,
  /// and the red timeline runs through the sticker centres.
  static const double timelineStart = 12;
  static const double timelineStroke = 1.5;
}
