import 'dart:io';

import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/data/repositories/records_repository.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/tool_dependencies.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/ledger_validation.dart';
import 'package:jiabu/domain/result.dart';

/// The only C3 data entrance. Views and their state carry domain projections.
final class LocalLedgerRepository implements LedgerRepository {
  LocalLedgerRepository(
    this.store,
    this.mutations,
    this.records,
    this.conflicts, {
    this.api,
  });
  final LocalStore store;
  final LocalMutationsRepository mutations;
  final RecordsRepository records;
  final ConflictService conflicts;
  final ApiClient? api;

  Future<LedgerSnapshot> snapshot(String spaceId) =>
      store.transaction(() async {
        Future<List<LedgerRow>> rows(String kind) async => List.unmodifiable([
          for (final row in await store.entities(spaceId, kind))
            LedgerRow(row.data, syncState: row.syncState),
        ]);
        return LedgerSnapshot(
          spaceId: spaceId,
          space: LedgerRow(
            (await store.entity(spaceId, 'space', spaceId))?.data ?? {},
          ),
          accounts: await rows('account'),
          records: await rows('record'),
          tags: await rows('tag'),
          members: await rows('space_member'),
          plans: await rows('allocation_plan'),
          events: await rows('entity_event'),
          pending: List.unmodifiable([
            for (final op in await store.outbox(spaceId))
              LedgerRow({
                'id': op.id,
                'state': op.state,
                'tool': op.payload['tool'],
                'entity_ids': op.entityIds.toList(),
                'error': op.lastError?['code'],
                'created_at': op.createdAt,
              }),
          ]),
          conflicts: List.unmodifiable([
            for (final row in await store.conflicts(spaceId)) LedgerRow(row),
          ]),
        );
      });

  @override
  Stream<LedgerSnapshot> watch(String spaceId) =>
      store.watchLedgerChanges(spaceId).asyncMap((_) => snapshot(spaceId));

  @override
  Future<Result<String>> createRecord(
    String spaceId,
    Map<String, Object?> values,
  ) => store.transaction(() async {
    final data = await snapshot(spaceId);
    final error = validateRecord(data, values);
    if (error != null) {
      return Failure(error);
    }
    return await records.create(spaceId, {'id': mutations.newId(), ...values});
  });

  @override
  Future<Result<String>> editRecord(
    String spaceId,
    String id,
    Map<String, Object?> changes,
  ) => store.transaction(() async {
    final data = await snapshot(spaceId);
    final old = data.find(data.records, id);
    if (old == null) {
      return const Failure('not_found');
    }
    if (!old.active) {
      return const Failure('parent_voided');
    }
    final error = validateRecord(data, {...old.data, ...changes}, editing: id);
    if (error != null) {
      return Failure(error);
    }
    return await records.update(spaceId, id, changes);
  });

  @override
  Future<Result<String>> recordStatus(
    String spaceId,
    String id, {
    required bool restore,
  }) => store.transaction(() async {
    final data = await snapshot(spaceId);
    final old = data.find(data.records, id);
    if (old == null) {
      return const Failure('not_found');
    }
    if (!restore &&
        old.text('kind') == 'expense' &&
        refundedMinor(data, id) > 0) {
      return const Failure('has_refunds');
    }
    if (restore) {
      final error = validateRecord(data, old.data, editing: id);
      if (error != null) {
        return Failure(error);
      }
    }
    // The parent void must wait for all local refund voids, including refunds
    // already optimistically voided. toolDependencies records this reference.
    final refundIds = !restore && old.text('kind') == 'expense'
        ? data.records
              .where((row) => row.text('refund_of_id') == id)
              .map((row) => row.id)
              .toList()
        : <String>[];
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: restore ? 'restore_record' : 'void_record',
      args: {'id': id},
      entityKind: 'record',
      entityId: id,
      optimistic: {
        ...old.data,
        'status': restore ? 'active' : 'voided',
        'void_reason': restore ? null : 'user',
        'updated_at': mutations.now().toUtc().toIso8601String(),
      },
      dependsOn: refundVoidDependencies(refundIds),
    );
  });

  @override
  Future<Result<String>> createAccount(
    String spaceId,
    Map<String, Object?> values,
  ) => store.transaction(() async {
    final name = values['name']?.toString().trim() ?? '';
    final opening = values['opening_balance_minor'];
    if (!validLedgerDate(values['opening_on']?.toString() ?? '') ||
        opening is! int ||
        opening.abs() > 1000000000000 ||
        name.isEmpty ||
        name.runes.length > 30 ||
        !const ['real', 'purpose'].contains(values['kind']) ||
        (values['is_reserve'] == true && values['kind'] != 'purpose')) {
      return const Failure('validation_failed');
    }
    final id = mutations.newId();
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: 'create_account',
      args: {'id': id, ...values, 'name': name},
      entityKind: 'account',
      entityId: id,
      optimistic: {
        'id': id,
        'space_id': spaceId,
        'module': 'ledger',
        'is_reserve': false,
        'archived_at': null,
        'sort_key': 0,
        'created_at': mutations.now().toUtc().toIso8601String(),
        ...values,
        'name': name,
        'version': 0,
      },
    );
  });

  @override
  Future<Result<String>> renameAccount(
    String spaceId,
    String id,
    String name,
  ) => store.transaction(() async {
    if (name.trim().isEmpty || name.runes.length > 30) {
      return const Failure('validation_failed');
    }
    final old = await store.entity(spaceId, 'account', id);
    if (old == null) {
      return const Failure('not_found');
    }
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: 'update_account',
      args: {'id': id, 'name': name.trim()},
      entityKind: 'account',
      entityId: id,
      optimistic: {...old.data, 'name': name.trim()},
    );
  });

  @override
  Future<Result<String>> archiveAccount(String spaceId, String id) =>
      store.transaction(() async {
        final data = await snapshot(spaceId);
        final balances = ledgerBalances(data);
        if (balances case Failure<Map<String, int>>(:final code)) {
          return Failure(code);
        }
        if ((balances as Ok<Map<String, int>>).value[id] != 0) {
          return const Failure('balance_not_zero');
        }
        final old = data.find(data.accounts, id);
        if (old == null) {
          return const Failure('not_found');
        }
        return await mutations.enqueueTool(
          spaceId: spaceId,
          tool: 'archive_account',
          args: {'id': id},
          entityKind: 'account',
          entityId: id,
          optimistic: {
            ...old.data,
            'archived_at': mutations.now().toUtc().toIso8601String(),
          },
          dependsOn: {
            for (final r in data.records)
              if ([
                'account_id',
                'to_account_id',
                'purpose_id',
                'to_purpose_id',
              ].any((key) => r.text(key) == id))
                'record:${r.id}',
            if (data.find(data.plans, id) != null) 'allocation_plan:$id',
          },
        );
      });

  @override
  Future<Result<String>> setPlan(
    String spaceId,
    String id,
    Map<String, Object?> values,
  ) => store.transaction(() async {
    final account = await store.entity(spaceId, 'account', id);
    if (account == null ||
        account.data['kind'] != 'purpose' ||
        account.data['archived_at'] != null) {
      return const Failure('account_archived');
    }
    final amount = values['amount_minor'];
    final day = values['day_of_month'];
    if (amount is! int ||
        amount <= 0 ||
        amount > 1000000000000 ||
        day is! int ||
        day < 1 ||
        day > 31 ||
        values['enabled'] is! bool) {
      return const Failure('validation_failed');
    }
    final old = await store.entity(spaceId, 'allocation_plan', id);
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: 'set_allocation_plan',
      args: {'account_id': id, ...values},
      entityKind: 'allocation_plan',
      entityId: id,
      optimistic: {
        ...?old?.data,
        'account_id': id,
        'space_id': spaceId,
        ...values,
        'version': old?.data['version'] ?? 0,
      },
    );
  });

  @override
  Future<Result<String>> createTag(String spaceId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.runes.length > 30) {
      return const Failure('validation_failed');
    }
    final id = mutations.newId();
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: 'create_tag',
      args: {'id': id, 'name': clean},
      entityKind: 'tag',
      entityId: id,
      optimistic: {
        'id': id,
        'space_id': spaceId,
        'module': 'ledger',
        'name': clean,
        'preset_key': null,
        'deleted_at': null,
        'version': 0,
      },
    );
  }

  @override
  Future<Result<void>> retry(String spaceId, String opId) =>
      mutations.retryFailed(spaceId, opId);

  @override
  Future<Result<void>> resolve(
    String spaceId,
    String kind,
    String id,
    String choice,
  ) => switch (choice) {
    'server' => conflicts.resolveWithServer(spaceId, kind, id),
    'acknowledge' => conflicts.acknowledgeVoided(spaceId, kind, id),
    'mine' => conflicts.resolveWithMine(spaceId, kind, id),
    'restore' when kind == 'record' => conflicts.restoreAndApplyMine(
      spaceId,
      id,
    ),
    _ => Future.value(const Failure('unsupported_conflict_resolution')),
  };

  @override
  Future<Result<List<int>>> image(
    String spaceId,
    String hash, {
    bool download = false,
  }) async {
    final fence = await store.fence(spaceId);
    if (fence == null) {
      return const Failure('unauthenticated');
    }
    // Attachment existence is checked independently of globally shared paths.
    final referenced = (await store.entities(spaceId, 'record')).any(
      (row) => (row.data['attachments'] as List<Object?>? ?? const []).contains(
        hash,
      ),
    );
    if (!referenced) {
      return const Failure('not_found');
    }
    try {
      for (final blob in await store.blobs(spaceId)) {
        if (blob['sha256'] == hash && blob['module'] == 'ledger') {
          final path = blob['path'];
          if (path is! String) {
            continue;
          }
          final file = File(path);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            if (!await store.accepts(fence)) {
              return const Failure('not_found');
            }
            return Ok(bytes);
          }
        }
      }
      final client = api;
      if (!download || client == null) {
        return const Failure('image_not_local');
      }
      final bytes = await client.downloadBlob(spaceId, hash, 'original');
      if (!await store.accepts(fence)) {
        return const Failure('not_found');
      }
      return Ok(bytes);
    } on ApiError catch (error) {
      return Failure(error.code);
    } on FileSystemException {
      return const Failure('image_not_local');
    }
  }
}
