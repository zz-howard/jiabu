import 'dart:async';

import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';

class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository(this.snapshot);
  LedgerSnapshot snapshot;
  final changes = StreamController<LedgerSnapshot>.broadcast();
  final calls = <String>[];
  final recordWrites = <Map<String, Object?>>[];
  Result<String> writeResult = const Ok('fictional-op');
  void emit(LedgerSnapshot value) {
    snapshot = value;
    changes.add(value);
  }

  @override
  Stream<LedgerSnapshot> watch(String spaceId) async* {
    yield snapshot;
    yield* changes.stream;
  }

  @override
  Future<Result<String>> createRecord(String s, Map<String, Object?> v) async {
    calls.add('create:${v['kind']}');
    recordWrites.add(Map.of(v));
    return writeResult;
  }

  @override
  Future<Result<String>> editRecord(
    String s,
    String id,
    Map<String, Object?> v,
  ) async {
    calls.add('edit:$id');
    recordWrites.add(Map.of(v));
    return writeResult;
  }

  @override
  Future<Result<String>> recordStatus(
    String s,
    String id, {
    required bool restore,
  }) async {
    calls.add(restore ? 'restore:$id' : 'void:$id');
    return writeResult;
  }

  @override
  Future<Result<String>> createAccount(String s, Map<String, Object?> v) async {
    calls.add('account:${v['kind']}');
    return writeResult;
  }

  @override
  Future<Result<String>> renameAccount(String s, String id, String name) async {
    calls.add('rename:$id');
    return writeResult;
  }

  @override
  Future<Result<String>> archiveAccount(String s, String id) async {
    calls.add('archive:$id');
    return writeResult;
  }

  @override
  Future<Result<String>> setPlan(
    String s,
    String id,
    Map<String, Object?> v,
  ) async {
    calls.add('plan:$id');
    return writeResult;
  }

  @override
  Future<Result<String>> createTag(String s, String name) async {
    calls.add('tag:$name');
    return writeResult;
  }

  @override
  Future<Result<void>> retry(String s, String op) async {
    calls.add('retry:$op');
    return const Ok(null);
  }

  @override
  Future<Result<void>> resolve(
    String s,
    String kind,
    String id,
    String choice,
  ) async {
    calls.add('resolve:$choice');
    return const Ok(null);
  }

  @override
  Future<Result<List<int>>> image(
    String s,
    String hash, {
    bool download = false,
  }) async => const Failure('image_not_local');
}
