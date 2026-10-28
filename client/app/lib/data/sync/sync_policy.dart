/// Technical clocks only. UI durations continue to come from JiabuMotion.
abstract final class SyncPolicy {
  static const debounce = Duration(seconds: 1);
  static const databasePoll = Duration(seconds: 1);
  static const metaTtl = Duration(hours: 1);
  static const requestTimeout = Duration(seconds: 30);
  static const blobTimeout = Duration(minutes: 10);
  static const lease = Duration(minutes: 12);
  static const heartbeat = Duration(seconds: 20);
  static const originalRetention = Duration(days: 30);
  static const int maxBatchBytes = 2 * 1024 * 1024;
  static const maxBatchItems = 50;
  static Duration retry(int attempt, {int? retryAfter}) =>
      Duration(seconds: retryAfter ?? (1 << attempt.clamp(0, 8)));
  static Duration seconds(int value) => Duration(seconds: value);
}
