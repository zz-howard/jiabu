/// Technical clocks only. UI durations continue to come from JiabuMotion.
abstract final class SyncPolicy {
  static Duration lockTimeout(int minutes) => Duration(minutes: minutes);
  static Duration lockBackoff(int failures) => Duration(
    seconds: (30 * (1 << ((failures ~/ 5) - 1).clamp(0, 4))).clamp(30, 300),
  );
  static const clipboardFeedback = Duration(seconds: 2);
  static const debounce = Duration(seconds: 1);
  static const databasePoll = Duration(seconds: 1);
  static const metaTtl = Duration(hours: 1);
  static const requestTimeout = Duration(seconds: 30);
  static const chatStreamTimeout = Duration(minutes: 6);
  static const chatCheckpoint = Duration(seconds: 1);
  static const blobTimeout = Duration(minutes: 10);
  static const lease = Duration(minutes: 12);
  static const heartbeat = Duration(seconds: 20);
  static const originalRetention = Duration(days: 30);
  static const updateCheckInterval = Duration(hours: 24);
  static const updateDismissInterval = Duration(days: 3);
  static const int maxBatchBytes = 2 * 1024 * 1024;
  static const maxBatchItems = 50;
  static Duration retry(int attempt, {int? retryAfter}) =>
      Duration(seconds: retryAfter ?? (1 << attempt.clamp(0, 8)));
  static Duration seconds(int value) => Duration(seconds: value);
}
