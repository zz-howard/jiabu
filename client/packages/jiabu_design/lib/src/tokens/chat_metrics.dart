/// Design-spec 4.16–4.18. Shared by production, catalog and geometry tests.
abstract final class JiabuChatMetrics {
  static const double width = 332;
  static const double action = 48;
  static const double icon = 16;
  static const double gap = 8;
  static const double rowGap = 4;
  static const double stepIndent = 10;
  static const double stepHeight = 32;
  static const double rail = 1.5;
  static const double chartHeight = 160;
  static const double chartStroke = 2;
  static const double chartAxis = 1;
  static const double tableColumn = 140;
  static const double lineHeight = 44;
  static const double skeletonHeight = 96;
  static const double skeletonLine = 12;
  static const double skeletonShort = 160;
  static const double fieldRadius = 12;
  static const double sendDisc = 40;
  static const double thinkingDot = 4;
  static const double thinkingIndent = 12;
  static const double thinkingGapTop = 8;
  static const double pageHeight = 720;

  /// V5 (design-spec 4.9): the assistant's round seal before its name.
  static const double avatar = 26;
  static const double avatarRing = 2;
  static const double avatarGlyph = 14;
  static const double avatarTilt = -10;

  /// My sticky note keeps this much free paper on its left (4.9).
  static const double noteLead = 56;

  /// Answer pills (4.10): capsule height, side inset, ring widths.
  static const double option = 44;
  static const double optionInset = 18;
  static const double optionRing = 1.5;
  static const double optionSelectedRing = 2.5;

  /// Floating composer (4.17b): round paper buttons with a white sticker
  /// ring, the paper field card and its pencil, the in-field gallery button,
  /// and the send button's tilt once there is something to send.
  static const double roundRing = 2.5;
  static const double fieldHeight = 52;
  static const double pencil = 18;
  static const double fieldButton = 44;

  /// The paperclip (attach) icon in the field: optically matches the pencil.
  static const double attachIcon = 20;
  static const double sendTilt = -8;

  /// Lifts the 48 round buttons so they centre on a one-line field.
  static const double roundLift = (fieldHeight - action) / 2;
}
