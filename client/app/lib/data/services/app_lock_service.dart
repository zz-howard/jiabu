import 'dart:async';
import 'dart:convert';

import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/biometric_auth_service.dart';
import 'package:jiabu/data/services/lock_credentials_service.dart';
import 'package:jiabu/data/services/window_privacy_service.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/app_lock.dart';

/// Lifecycle state machine. Never treats failure/cancellation as success.
final class AppLockService {
  AppLockService({
    required this.settings,
    required this.credentials,
    required this.biometrics,
    required this.privacy,
    DateTime Function()? clock,
    Timer Function(Duration, void Function())? timer,
  }) : clock = clock ?? DateTime.now,
       timer = timer ?? Timer.new;
  final SettingsStorage settings;
  final LockCredentials credentials;
  final BiometricAuthService biometrics;
  final WindowPrivacyService privacy;
  final DateTime Function() clock;
  final Timer Function(Duration, void Function()) timer;
  Timer? _waitTimer;
  bool _authenticationPaused = false;
  bool _inForeground = true;
  final _events = StreamController<void>.broadcast();
  Stream<void> get events => _events.stream;
  LockPhase phase = LockPhase.loading;
  LockConfiguration configuration = const LockConfiguration();
  String? scope;
  DateTime? _leftAt;
  int _attempt = 0;
  bool _disposed = false;
  bool get waiting => configuration.waitUntil?.isAfter(clock()) ?? false;
  bool get visible => configuration.enabled && phase != LockPhase.unlocked;
  void _notify() {
    if (!_disposed) {
      _events.add(null);
    }
  }

  Future<void> load(String? nextScope) async {
    final attempt = ++_attempt;
    scope = nextScope;
    phase = LockPhase.loading;
    _notify();
    final value = nextScope == null
        ? null
        : await settings.read('lock_config:$nextScope');
    if (attempt != _attempt || _disposed) {
      return;
    }
    configuration = value == null
        ? const LockConfiguration()
        : LockConfiguration.fromJson(jsonDecode(value) as Map<String, Object?>);
    phase = configuration.enabled ? LockPhase.locked : LockPhase.disabled;
    _leftAt = null;
    await privacy.set('app-lock', enabled: configuration.enabled);
    _scheduleWait();
    _notify();
  }

  void _scheduleWait() {
    _waitTimer?.cancel();
    final until = configuration.waitUntil;
    if (until != null && until.isAfter(clock())) {
      _waitTimer = timer(until.difference(clock()), _notify);
    }
  }

  Future<void> _save() async {
    final current = scope;
    if (current != null) {
      await settings.write(
        'lock_config:$current',
        jsonEncode(configuration.toJson()),
      );
    }
  }

  Future<void> configure({
    required String pin,
    required String mode,
    required int timeoutMinutes,
    String? pattern,
  }) async {
    final current = scope;
    if (current == null ||
        !RegExp(r'^\d{4,6}$').hasMatch(pin) ||
        !const ['biometric', 'pin', 'pattern'].contains(mode) ||
        !const [0, 1, 5, 15].contains(timeoutMinutes) ||
        (mode == 'pattern' &&
            (pattern == null ||
                !RegExp(r'^[0-8]{4,9}$').hasMatch(pattern) ||
                pattern.split('').toSet().length != pattern.length))) {
      throw ArgumentError('invalid_lock_configuration');
    }
    final attempt = ++_attempt;
    await credentials.save(current, 'pin', pin);
    if (pattern != null) {
      await credentials.save(current, 'pattern', pattern);
    }
    if (scope != current || attempt != _attempt || _disposed) {
      return;
    }
    configuration = LockConfiguration(
      enabled: true,
      mode: mode,
      timeoutMinutes: timeoutMinutes,
    );
    await _save();
    if (scope != current || attempt != _attempt || _disposed) {
      return;
    }
    try {
      await privacy.set('app-lock', enabled: true);
    } on Object {
      phase = LockPhase.locked;
      _notify();
      rethrow;
    }
    if (scope != current || attempt != _attempt || _disposed) {
      return;
    }
    phase = _inForeground ? LockPhase.unlocked : LockPhase.locked;
    _notify();
  }

  Future<void> disable() async {
    if (phase != LockPhase.unlocked) {
      return;
    }
    final current = scope;
    final attempt = ++_attempt;
    _waitTimer?.cancel();
    configuration = const LockConfiguration();
    await _save();
    if (_disposed || scope != current || attempt != _attempt) {
      return;
    }
    await privacy.set('app-lock', enabled: false);
    if (_disposed || scope != current || attempt != _attempt) {
      return;
    }
    phase = LockPhase.disabled;
    _notify();
  }

  void background({bool paused = false}) {
    if (paused) {
      _inForeground = false;
    }
    if (phase == LockPhase.authenticating && paused) {
      _authenticationPaused = true;
      _leftAt ??= clock();
    }
    if (!configuration.enabled || phase == LockPhase.authenticating) {
      return;
    }
    _leftAt ??= clock();
    if (phase == LockPhase.unlocked) {
      phase = LockPhase.covered;
    }
    _notify();
  }

  void foreground() {
    _inForeground = true;
    if (!configuration.enabled || phase == LockPhase.authenticating) {
      return;
    }
    final left = _leftAt;
    _leftAt = null;
    if (phase == LockPhase.covered && left != null) {
      final elapsed = clock().difference(left);
      phase = elapsed >= SyncPolicy.lockTimeout(configuration.timeoutMinutes)
          ? LockPhase.locked
          : LockPhase.unlocked;
    }
    _notify();
  }

  Future<bool> authenticate({
    String? value,
    String kind = 'pin',
    String? reason,
  }) async {
    if (waiting || phase != LockPhase.locked || scope == null) {
      return false;
    }
    final current = scope;
    final attempt = ++_attempt;
    _authenticationPaused = false;
    phase = LockPhase.authenticating;
    _notify();
    var accepted = false;
    try {
      accepted = reason != null
          ? await biometrics.authenticate(reason)
          : await credentials.verify(current ?? '', kind, value ?? '');
    } on Object {
      accepted = false;
    }
    if (_disposed || attempt != _attempt || scope != current) {
      return false;
    }
    if (accepted) {
      try {
        await privacy.set('app-lock', enabled: true);
      } on Object {
        phase = LockPhase.locked;
        _notify();
        return false;
      }
      if (_disposed || attempt != _attempt || scope != current) {
        return false;
      }
    }
    if (accepted) {
      configuration = LockConfiguration(
        enabled: true,
        mode: configuration.mode,
        timeoutMinutes: configuration.timeoutMinutes,
      );
      phase = _authenticationPaused && !_inForeground
          ? LockPhase.covered
          : LockPhase.unlocked;
    } else {
      final failures = configuration.failures + (reason == null ? 1 : 0);
      configuration = LockConfiguration(
        enabled: true,
        mode: configuration.mode,
        timeoutMinutes: configuration.timeoutMinutes,
        failures: failures,
        waitUntil: failures > 0 && failures % 5 == 0
            ? clock().add(SyncPolicy.lockBackoff(failures))
            : configuration.waitUntil,
      );
      phase = LockPhase.locked;
    }
    await _save();
    if (_disposed || scope != current || attempt != _attempt) {
      return false;
    }
    _scheduleWait();
    _notify();
    return accepted;
  }

  /// Call only after the existing password login successfully authenticates the
  /// SAME server/account. A route change or a failed login cannot reset a PIN.
  Future<void> resetAfterPasswordLogin() async {
    final current = scope;
    final attempt = ++_attempt;
    _waitTimer?.cancel();
    configuration = const LockConfiguration();
    await _save();
    if (_disposed || scope != current || attempt != _attempt) {
      return;
    }
    await privacy.set('app-lock', enabled: false);
    if (_disposed || scope != current || attempt != _attempt) {
      return;
    }
    phase = LockPhase.disabled;
    _notify();
  }

  Future<void> dispose() async {
    _disposed = true;
    _waitTimer?.cancel();
    ++_attempt;
    await _events.close();
  }
}
