import 'dart:async';

import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/shared/c4/c4_ui_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'c4_view_model.g.dart';

/// Each route/modal owns an auto-disposed form; no secret is in freezed state,
/// toString, persistence, logs, or a reusable list/detail result.
@riverpod
class C4ViewModel extends _$C4ViewModel {
  String? _secret;
  String? get secret => _secret;
  final String operationId = const Uuid().v7();
  String get _privacyReason => 'api-key:$operationId';
  Map<String, Object?>? _createPayload;
  Timer? _copyTimer;

  @override
  C4UiState build(String formId) {
    final runtime = ref.watch(appRuntimeProvider);
    final subscription = runtime.events.listen((_) {
      if (ref.mounted) {
        state = state.copyWith(online: runtime.managementOnline);
      }
    });
    ref.onDispose(() {
      _secret = null;
      _copyTimer?.cancel();
      unawaited(subscription.cancel());
      if (formId.startsWith('key-create')) {
        unawaited(runtime.privacy.releaseAfterFrame(_privacyReason));
      }
    });
    return C4UiState(online: runtime.managementOnline);
  }

  void patch(String key, Object? value) => state = state.copyWith(
    values: {...state.values, key: value},
    error: null,
  );
  void fail(String error) => state = state.copyWith(error: error, busy: false);
  Future<bool> run<T>(Future<Result<T>> Function() action) async {
    if (state.busy) {
      return false;
    }
    if (!state.online) {
      fail('offline');
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await action();
      if (!ref.mounted) {
        return false;
      }
      if (result is Failure<T> && result.code == 'network') {
        ref.read(appRuntimeProvider).network.failed();
      }
      state = state.copyWith(
        busy: false,
        error: result is Failure<T> ? result.code : null,
      );
      return result is Ok<T>;
    } on Object {
      if (ref.mounted) {
        fail('invalid_response');
      }
      return false;
    }
  }

  Future<bool> runLocal(Future<void> Function() action) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await action();
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
      return true;
    } on Object {
      if (ref.mounted) {
        fail('local_storage_unavailable');
      }
      return false;
    }
  }

  Future<bool> loadInvitations(String? spaceId) => run(() async {
    final result = await ref
        .read(spacesRepositoryProvider)
        .invitations(spaceId);
    if (ref.mounted && result is Ok<List<Map<String, Object?>>>) {
      state = state.copyWith(rows: result.value);
    }
    return result;
  });

  Future<bool> loadKeys() => run(() async {
    final result = await ref.read(apiKeysRepositoryProvider).list();
    if (ref.mounted && result is Ok<List<Map<String, Object?>>>) {
      state = state.copyWith(rows: result.value);
    }
    return result;
  });

  Future<bool> createKey() async {
    final values = state.values;
    final name = (values['name'] as String? ?? '').trim();
    final scope = values['scope'] as String?;
    if (name.isEmpty || !const ['read', 'read_write'].contains(scope)) {
      fail('validation_failed');
      return false;
    }
    final days = values['days'] as int? ?? 90;
    _createPayload ??= {
      'name': name,
      'scope': scope,
      if (days == 0) 'expires_at': null,
      if (days != 0 && days != 90)
        'expires_at': ref
            .read(ledgerClockProvider)()
            .toUtc()
            .add(SyncPolicy.seconds(days * 86400))
            .toIso8601String(),
    };
    state = state.copyWith(values: {...state.values, '_frozen': true});
    final runtime = ref.read(appRuntimeProvider);
    final repository = ref.read(apiKeysRepositoryProvider);
    return await run(() async {
      await runtime.privacy.set(_privacyReason, enabled: true);
      final result = await repository.create(_createPayload ?? {}, operationId);
      if (!ref.mounted) {
        return const Failure<Map<String, Object?>>('stale_response');
      }
      if (result is Ok<Map<String, Object?>>) {
        if (result.value['plaintext_available'] == true &&
            result.value['key'] is String) {
          _secret = requireValue<String>(result.value['key']);
          state = state.copyWith(revision: state.revision + 1);
        } else {
          await runtime.privacy.set(_privacyReason, enabled: false);
          return const Failure<Map<String, Object?>>('plaintext_unavailable');
        }
      } else {
        await runtime.privacy.set(_privacyReason, enabled: false);
      }
      return result;
    });
  }

  Future<void> copyKey() async {
    final key = _secret;
    if (key == null) {
      return;
    }
    try {
      await ref.read(appRuntimeProvider).clipboard.copy(key);
      if (!ref.mounted || _secret != key) {
        return;
      }
      state = state.copyWith(copied: true);
      _copyTimer?.cancel();
      _copyTimer = Timer(SyncPolicy.clipboardFeedback, () {
        if (ref.mounted) {
          state = state.copyWith(copied: false);
        }
      });
    } on Object {
      if (ref.mounted) {
        fail('clipboard_failed');
      }
    }
  }

  Future<void> forgetKey() async {
    _secret = null;
    _copyTimer?.cancel();
    state = state.copyWith(copied: false, revision: state.revision + 1);
    await ref
        .read(appRuntimeProvider)
        .privacy
        .releaseAfterFrame(_privacyReason);
  }
}
