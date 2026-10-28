import 'dart:async';

import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/money.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/shared/ledger/ledger_ui_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_view_model.g.dart';

@riverpod
class LedgerViewModel extends _$LedgerViewModel {
  @override
  LedgerUiState build(String spaceId) {
    final repository = ref.watch(ledgerRepositoryProvider);
    final subscription = repository
        .watch(spaceId)
        .listen(
          (snapshot) {
            if (ref.mounted) {
              state = state.copyWith(snapshot: snapshot, error: null);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (ref.mounted) {
              state = state.copyWith(error: 'local_read_failed');
            }
          },
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return const LedgerUiState();
  }

  void filter(HistoryFilter filter) => state = state.copyWith(filter: filter);
  Future<bool> command<T>(
    Future<Result<T>> Function(LedgerRepository) action,
  ) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await action(ref.read(ledgerRepositoryProvider));
      if (!ref.mounted) {
        return false;
      }
      state = state.copyWith(
        busy: false,
        error: result is Failure<T> ? result.code : null,
      );
      return result is Ok<T>;
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: 'local_write_failed');
      }
      return false;
    }
  }
}

@riverpod
class LedgerFormViewModel extends _$LedgerFormViewModel {
  @override
  LedgerFormState build(String spaceId, String formId) =>
      const LedgerFormState();
  void initialize(Map<String, Object?> values) {
    if (state.values.isEmpty) {
      state = state.copyWith(values: values);
    }
  }

  void refreshRecord(LedgerRow row, String currency) {
    state = state.copyWith(
      values: {
        ...row.data,
        'amount_text': minorInput(row.number('amount_minor'), currency),
        '_opened_record': row.data,
        '_opened_version': row.number('version'),
        '_refresh': ((state.values['_refresh'] as int?) ?? 0) + 1,
      },
      error: 'record_changed_elsewhere',
      busy: false,
    );
  }

  void patch(String key, Object? value) {
    final values = {...state.values, key: value};
    final destination = switch ((state.values['kind'], key)) {
      ('transfer', 'account_id') => 'to_account_id',
      ('reallocation', 'purpose_id') => 'to_purpose_id',
      _ => null,
    };
    if (destination != null && values[destination] == value) {
      values.remove(destination);
    }
    state = state.copyWith(values: values, error: null);
  }

  void kind(String kind) => state = state.copyWith(
    values: {
      'kind': kind,
      'amount_text': state.values['amount_text'] ?? '',
      'occurred_on': state.values['occurred_on'],
      'note': state.values['note'],
      'tag_ids': <String>[],
    },
    error: null,
  );
  void fail(String code) => state = state.copyWith(error: code, busy: false);
  Future<bool> submit<T>(
    Future<Result<T>> Function(LedgerRepository, Map<String, Object?>) action,
  ) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await action(
        ref.read(ledgerRepositoryProvider),
        state.values,
      );
      if (!ref.mounted) {
        return false;
      }
      state = state.copyWith(
        busy: false,
        error: result is Failure<T> ? result.code : null,
      );
      return result is Ok<T>;
    } on Object {
      if (ref.mounted) {
        fail('local_write_failed');
      }
      return false;
    }
  }
}
