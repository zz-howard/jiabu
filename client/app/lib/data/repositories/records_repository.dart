import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

/// C3 supplies forms; C2 exposes an offline write entrance for them and tests.
final class RecordsRepository {
  RecordsRepository(this.store, this.mutations);
  final LocalStore store;
  final LocalMutationsRepository mutations;

  Future<Result<String>> create(String spaceId, Map<String, Object?> record) =>
      store.transaction(() async {
        final amount = record['amount_minor'];
        if (amount is! int || amount <= 0) {
          return const Failure('validation_failed');
        }
        final id = requireValue<String>(record['id']);
        const module = 'ledger';
        final space = await store.entity(spaceId, 'space', spaceId);
        final member = space?.data['member_id'];
        final timestamp = mutations.now().toUtc().toIso8601String();
        final args = {...record}..remove('space_id');
        return await mutations.enqueueTool(
          spaceId: spaceId,
          tool: 'create_record',
          args: args,
          entityKind: 'record',
          entityId: id,
          optimistic: {
            'module': module,
            'visibility': null,
            'account_id': null,
            'to_account_id': null,
            'purpose_id': null,
            'to_purpose_id': null,
            'refund_of_id': null,
            'tag_ids': <String>[],
            'attachments': <String>[],
            'note': null,
            'void_reason': null,
            'origin': 'manual',
            'run_id': null,
            'created_by_member_id': member,
            'updated_by_member_id': member,
            'created_at': timestamp,
            'updated_at': timestamp,
            'change_seq': 0,
            ...record,
            'space_id': spaceId,
            'status': 'active',
            'version': 0,
          },
        );
      });

  Future<Result<String>> update(
    String spaceId,
    String id,
    Map<String, Object?> changes,
  ) => store.transaction(() async {
    final amount = changes['amount_minor'];
    if (changes.containsKey('amount_minor') &&
        (amount is! int || amount <= 0)) {
      return const Failure('validation_failed');
    }
    final row = await store.entity(spaceId, 'record', id);
    if (row == null) {
      return const Failure('not_found');
    }
    return await mutations.enqueueTool(
      spaceId: spaceId,
      tool: 'update_record',
      args: {'id': id, 'changes': changes},
      entityKind: 'record',
      entityId: id,
      optimistic: {
        ...row.data,
        ...changes,
        'updated_at': mutations.now().toUtc().toIso8601String(),
        'updated_by_member_id': (await store.entity(
          spaceId,
          'space',
          spaceId,
        ))?.data['member_id'],
      },
    );
  });
}
