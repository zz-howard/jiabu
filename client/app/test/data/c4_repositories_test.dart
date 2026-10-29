import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/repositories/api_keys_repository.dart';
import 'package:jiabu/data/repositories/spaces_repository.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';

import '../support/sync_harness.dart';

void main() {
  late SyncHarness h;
  late LocalSpacesRepository spaces;
  late OnlineApiKeysRepository keys;
  late bool online;
  late String? selected;
  final calls =
      <
        ({
          String path,
          String method,
          Map<String, Object?>? body,
          String? operation,
          int? epoch,
        })
      >[];
  setUp(() async {
    h = await SyncHarness.create();
    online = true;
    selected = null;
    calls.clear();
    h.api.onAccountRequest = (path, method, body, operation, epoch) async {
      calls.add((
        path: path,
        method: method,
        body: body,
        operation: operation,
        epoch: epoch,
      ));
      return {'api_keys': <Object?>[], 'invitations': <Object?>[]};
    };
    spaces = LocalSpacesRepository(
      api: h.api,
      store: h.store,
      online: () => online,
      valid: () => true,
      refresh: () async {},
      selectSpace: (id) async {
        selected = id;
      },
    );
    keys = OnlineApiKeysRepository(h.api, online: () => online);
  });
  tearDown(() => h.close());
  test('offline_management_never_sends_requests', () async {
    online = false;
    expect(await spaces.create({}, 'operation'), isA<Failure<void>>());
    expect(
      await spaces.decide('invitation', 'operation', accept: true),
      isA<Failure<void>>(),
    );
    expect(await keys.list(), isA<Failure<List<Map<String, Object?>>>>());
    expect(
      await keys.create({'name': 'fictional'}, 'operation'),
      isA<Failure<Map<String, Object?>>>(),
    );
    expect(calls, isEmpty);
  });
  test('space_commands_send_epoch_version_and_stable_operation', () async {
    final space = SpaceInfo.fromJson(sampleSpace().toJson());
    await spaces.change(
      space,
      'edit',
      'operation',
      body: {'name': '用户A', 'expected_version': 1},
    );
    expect(calls.single.path, 'v1/spaces/s');
    expect(calls.single.method, 'PATCH');
    expect(calls.single.epoch, 1);
    expect(calls.single.operation, 'operation');
    expect(calls.single.body?['expected_version'], 1);
  });
  test('leave_count_reads_only_requested_space_outbox', () async {
    await h.seed('record-a');
    await h.records.update('s', 'record-a', {'note': 'fictional'});
    expect(await spaces.pendingCount('s'), 1);
    expect(await spaces.pendingCount('other'), 0);
  });
  test('switch_accepts_only_cached_active_memberships', () async {
    expect(await spaces.select('s'), isA<Ok<void>>());
    expect(selected, 's');
    expect(await spaces.select('private-other'), isA<Failure<void>>());
    expect(selected, 's');
  });
  test('key_expiry_omission_and_explicit_null_survive_transport', () async {
    await keys.create({'name': '用户A', 'scope': 'read'}, 'same-operation');
    await keys.create({
      'name': '用户A',
      'scope': 'read',
      'expires_at': null,
    }, 'other-operation');
    expect(calls.first.body?.containsKey('expires_at'), isFalse);
    expect(calls.last.body?.containsKey('expires_at'), isTrue);
    expect(calls.last.body?['expires_at'], isNull);
    expect(await h.store.outbox('s'), isEmpty);
  });
  test('management_errors_preserve_code_without_server_text', () async {
    h.api.onAccountRequest = (_, method, body, operation, epoch) async =>
        throw const ApiError(
          'space_last_owner',
          status: 409,
          requestId: 'fictional-request',
        );
    final result = await spaces.decide('invitation', 'operation', accept: true);
    expect((result as Failure<void>).code, 'space_last_owner');
    expect(result.requestId, 'fictional-request');
  });
}
