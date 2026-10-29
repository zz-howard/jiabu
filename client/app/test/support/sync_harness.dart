import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/data/repositories/records_repository.dart';
import 'package:jiabu/data/services/blob_cache_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/membership_reconciler.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/pull_applier.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/domain/required_value.dart';

SpaceDto sampleSpace({
  String id = 's',
  int epoch = 1,
  Map<String, String> modules = const {'ledger': 'write', 'documents': 'write'},
}) => SpaceDto(
  id: id,
  name: 'Fictional space',
  accentColor: 'pine',
  currency: 'CNY',
  timezone: 'Asia/Shanghai',
  isDefault: true,
  version: 1,
  role: 'owner',
  joinEpoch: epoch,
  memberId: 'm',
  modules: modules,
  members: const [],
);

Map<String, Object?> sampleRecord(
  String id, {
  int amount = 100,
  int version = 1,
  String status = 'active',
  String spaceId = 's',
}) => {
  'id': id,
  'space_id': spaceId,
  'kind': 'expense',
  'amount_minor': amount,
  'occurred_on': '2026-01-01',
  'account_id': 'a',
  'purpose_id': 'p',
  'status': status,
  'version': version,
  'attachments': <String>[],
  'tag_ids': <String>[],
};

class FakeApi implements ApiClient {
  Future<Map<String, Object?>> Function(
    String,
    String,
    Map<String, Object?>?,
    String?,
    int?,
  )?
  onAccountRequest;

  @override
  Future<Map<String, Object?>> accountRequest(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? operationId,
    int? joinEpoch,
  }) async =>
      await onAccountRequest?.call(
        path,
        method,
        body,
        operationId,
        joinEpoch,
      ) ??
      <String, Object?>{};

  SpacesDto spaceResponse = SpacesDto(spaces: [sampleSpace()]);
  MetaDto metaResponse = const MetaDto(
    serverVersion: '0.1.0',
    apiVersions: [1],
    minClientBuild: {'stable': 0, 'beta': 0},
    features: [],
  );
  final server = <String, Map<String, Object?>>{};
  final batches = <List<PushOpDto>>[];
  final events = <String>[];
  final pulls = <PullRequestDto>[];
  final logs = <ClientLogsDto>[];
  int metaCalls = 0;
  Future<PushResponseDto> Function(List<PushOpDto>)? onPush;
  Future<PullResponseDto> Function(PullRequestDto)? onPull;
  Future<void> Function()? onBlob;
  Future<SpacesDto> Function()? onSpaces;

  @override
  Future<MetaDto> meta() async {
    metaCalls++;
    return metaResponse;
  }

  @override
  Future<void> health() async {
    events.add('health');
  }

  @override
  Future<SpacesDto> spaces() async {
    events.add('spaces');
    return onSpaces == null ? spaceResponse : await onSpaces!();
  }

  @override
  Future<PushResponseDto> push(List<PushOpDto> ops) async {
    batches.add(ops);
    events.addAll(ops.map((op) => op.tool));
    return onPush == null ? apply(ops) : await onPush!(ops);
  }

  PushResponseDto apply(List<PushOpDto> ops) =>
      PushResponseDto(results: [for (final op in ops) _applyOne(op)]);
  PushResultDto _applyOne(PushOpDto op) {
    final id = requireValue<String>(op.args['id'] ?? op.args['account_id']);
    final previous =
        server[id] ?? sampleRecord(id, version: 0, spaceId: op.spaceId);
    final data = {
      ...previous,
      if (op.tool.startsWith('create_')) ...op.args,
      if (const {
        'update_account',
        'rename_tag',
        'set_allocation_plan',
      }.contains(op.tool))
        for (final entry in op.args.entries)
          if (!const {
            'id',
            'account_id',
            'expected_version',
          }.contains(entry.key))
            entry.key: entry.value,
      if (op.args['changes'] case final Map<String, Object?> changes)
        ...changes,
      if (op.tool == 'void_record') ...{
        'status': 'voided',
        'void_reason': 'user',
      },
      if (op.tool == 'restore_record') ...{
        'status': 'active',
        'void_reason': null,
      },
      if (op.tool == 'delete_tag') 'deleted_at': '2026-01-01T00:00:00Z',
      if (op.tool == 'archive_account') 'archived_at': '2026-01-01T00:00:00Z',
      'version': requireValue<int>(previous['version']) + 1,
    };
    server[id] = data;
    return PushResultDto(opId: op.opId, status: 'ok', result: data);
  }

  @override
  Future<PullResponseDto> pull(PullRequestDto request) async {
    pulls.add(request);
    return onPull == null
        ? PullResponseDto(
            spaces: [
              for (final entry in request.spaces.entries)
                PullPageDto(
                  spaceId: entry.key,
                  cursor: entry.value,
                  hasMore: false,
                  changes: const [],
                ),
            ],
            unavailable: const [],
          )
        : await onPull!(request);
  }

  @override
  Future<void> uploadBlob({
    required String spaceId,
    required int joinEpoch,
    required String module,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  }) async {
    events.add('blob');
    await onBlob?.call();
  }

  @override
  Future<Uint8List> downloadBlob(
    String spaceId,
    String hash,
    String variant,
  ) async => Uint8List(0);
  @override
  Future<void> uploadLogs(ClientLogsDto value) async {
    logs.add(value);
  }

  @override
  Future<LoginResponseDto> login(LoginRequestDto request) async =>
      const LoginResponseDto(
        token: 'fictional-session',
        sessionKind: 'full',
        user: UserDto(id: 'u', username: 'fictional', locale: 'en'),
      );
  @override
  Future<void> logout({String? token}) async {}
  @override
  Future<UserDto> me() async =>
      const UserDto(id: 'u', username: 'fictional', locale: 'en');
  @override
  Future<void> changePassword(ChangePasswordDto request) async {}
}

class SyncHarness {
  SyncHarness._(this.db, this.directory, this.api, String Function()? newId) {
    store = LocalStore(db);
    cache = BlobCacheService(store, directory);
    conflicts = ConflictService(store, now: () => clock);
    memberships = MembershipReconciler(store, cache);
    processor = OutboxProcessor(store, api, conflicts, now: () => clock);
    pull = PullApplier(store);
    mutations = LocalMutationsRepository(
      store,
      now: () => clock,
      newId: newId ?? (() => 'op-${(++serial).toString().padLeft(6, '0')}'),
    );
    records = RecordsRepository(store, mutations);
    engine = SyncEngine(
      store: store,
      api: api,
      handshake: VersionHandshakeService(api, now: () => clock),
      memberships: memberships,
      outbox: processor,
      pull: pull,
      now: () => clock,
      currentSpace: () => 's',
    );
  }
  final JiabuDatabase db;
  final Directory directory;
  final FakeApi api;
  DateTime clock = DateTime.utc(2026);
  int serial = 0;
  late final LocalStore store;
  late final BlobCacheService cache;
  late final ConflictService conflicts;
  late final MembershipReconciler memberships;
  late final OutboxProcessor processor;
  late final PullApplier pull;
  late final LocalMutationsRepository mutations;
  late final RecordsRepository records;
  late final SyncEngine engine;

  static Future<SyncHarness> create({
    JiabuDatabase? database,
    Directory? directory,
    FakeApi? api,
    String Function()? newId,
  }) async {
    final h = SyncHarness._(
      database ?? JiabuDatabase(NativeDatabase.memory()),
      directory ?? await Directory.systemTemp.createTemp('jiabu-sync-'),
      api ?? FakeApi(),
      newId,
    );
    await h.store.activate(authenticated: true);
    await h.memberships.reconcile(h.api.spaceResponse);
    return h;
  }

  Future<void> seed(String id, {int amount = 100, int version = 1}) async {
    final row = sampleRecord(id, amount: amount, version: version);
    await store.putEntity('s', 'record', row);
    api.server[id] = row;
  }

  Future<void> close() async {
    await db.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
