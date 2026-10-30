enum JiabuSpacing {
  compact(14),
  regular(18);

  JiabuSpacing(this.page);

  static const double compactWidth = 380;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double gap14 = 14;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double sectionTop = 30;
  static const double sectionBottom = 12;
  static const double cardInset = 16;
  static const double cardGap = 12;
  static const double actionGap = 24;
  static const double captionGap = 8;
  static const double gridGap = 14;
  static const double listRowInset = 14;
  static const double listRowMinHeight = 66;
  static const double minTapTarget = 48;
  static const double messageGap = 6;

  final double page;

  static JiabuSpacing forWidth(double width) =>
      width <= compactWidth ? compact : regular;
}
