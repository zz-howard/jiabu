enum LockPhase { loading, disabled, locked, authenticating, unlocked, covered }

final class LockConfiguration {
  const LockConfiguration({
    this.enabled = false,
    this.mode = 'biometric',
    this.timeoutMinutes = 1,
    this.failures = 0,
    this.waitUntil,
  });
  factory LockConfiguration.fromJson(Map<String, Object?> json) =>
      LockConfiguration(
        enabled: json['enabled'] as bool? ?? false,
        mode: json['mode'] as String? ?? 'biometric',
        timeoutMinutes: json['timeout_minutes'] as int? ?? 1,
        failures: json['failures'] as int? ?? 0,
        waitUntil: DateTime.tryParse(json['wait_until'] as String? ?? ''),
      );
  final bool enabled;
  final String mode;
  final int timeoutMinutes;
  final int failures;
  final DateTime? waitUntil;
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'mode': mode,
    'timeout_minutes': timeoutMinutes,
    'failures': failures,
    'wait_until': waitUntil?.toUtc().toIso8601String(),
  };
}
