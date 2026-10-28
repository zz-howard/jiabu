import 'dart:convert';

import 'package:jiabu/domain/result.dart';

/// A space-scoped immutable projection. Conflict rows contain SERVER data.
final class LedgerRow {
  LedgerRow(Map<String, Object?> data, {this.syncState = 'synced'})
    : data = Map.unmodifiable(data);
  final Map<String, Object?> data;
  final String syncState;
  String text(String key) => data[key]?.toString() ?? '';
  int number(String key) => (data[key] as int?) ?? 0;
  bool flag(String key) => data[key] == true || data[key] == 1;
  List<String> strings(String key) =>
      (data[key] as List<Object?>? ?? const []).cast<String>();
  String get id => text('id').isEmpty ? text('account_id') : text('id');
  bool get active => text('status') == 'active';
  bool get archived => data['archived_at'] != null;
}

final class LedgerSnapshot {
  LedgerSnapshot({
    required this.spaceId,
    required this.space,
    List<LedgerRow> accounts = const [],
    List<LedgerRow> records = const [],
    List<LedgerRow> tags = const [],
    List<LedgerRow> members = const [],
    List<LedgerRow> plans = const [],
    List<LedgerRow> events = const [],
    List<LedgerRow> pending = const [],
    List<LedgerRow> conflicts = const [],
  }) : accounts = List.unmodifiable(accounts),
       records = List.unmodifiable(records),
       tags = List.unmodifiable(tags),
       members = List.unmodifiable(members),
       plans = List.unmodifiable(plans),
       events = List.unmodifiable(events),
       pending = List.unmodifiable(pending),
       conflicts = List.unmodifiable(conflicts);

  final String spaceId;
  final LedgerRow space;
  final List<LedgerRow> accounts;
  final List<LedgerRow> records;
  final List<LedgerRow> tags;
  final List<LedgerRow> members;
  final List<LedgerRow> plans;
  final List<LedgerRow> events;
  final List<LedgerRow> pending;
  final List<LedgerRow> conflicts;
  String get currency =>
      space.text('currency').isEmpty ? 'CNY' : space.text('currency');
  bool get writable => const [
    'write',
    'manage',
  ].contains((space.data['modules'] as Map<String, Object?>?)?['ledger']);
  LedgerRow? find(List<LedgerRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  LedgerRow? conflict(String kind, String id) {
    for (final row in conflicts) {
      if (row.text('entity_kind') == kind && row.text('entity_id') == id) {
        return row;
      }
    }
    return null;
  }

  LedgerRow? mine(String kind, String id) {
    final row = conflict(kind, id);
    return row == null
        ? null
        : LedgerRow(jsonDecode(row.text('mine_json')) as Map<String, Object?>);
  }

  List<LedgerRow> operations(String kind, String id) => pending
      .where((row) => row.strings('entity_ids').contains('$kind:$id'))
      .toList();
}

abstract interface class LedgerRepository {
  Stream<LedgerSnapshot> watch(String spaceId);
  Future<Result<String>> createRecord(
    String spaceId,
    Map<String, Object?> values,
  );
  Future<Result<String>> editRecord(
    String spaceId,
    String id,
    Map<String, Object?> changes,
  );
  Future<Result<String>> recordStatus(
    String spaceId,
    String id, {
    required bool restore,
  });
  Future<Result<String>> createAccount(
    String spaceId,
    Map<String, Object?> values,
  );
  Future<Result<String>> renameAccount(String spaceId, String id, String name);
  Future<Result<String>> archiveAccount(String spaceId, String id);
  Future<Result<String>> setPlan(
    String spaceId,
    String id,
    Map<String, Object?> values,
  );
  Future<Result<String>> createTag(String spaceId, String name);
  Future<Result<void>> retry(String spaceId, String opId);
  Future<Result<void>> resolve(
    String spaceId,
    String kind,
    String id,
    String choice,
  );
  Future<Result<List<int>>> image(
    String spaceId,
    String hash, {
    bool download = false,
  });
}
