/// C5 MUST call this policy when it first adds notification delivery.
/// The caller supplies localized generic text; no amount/title survives a lock.
String notificationText({
  required bool appLockEnabled,
  required String content,
  required String genericMessage,
}) => appLockEnabled ? genericMessage : content;
