import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/blob_cache_service.dart';
import 'package:jiabu/domain/required_value.dart';

final class MembershipReconciler {
  MembershipReconciler(this.store, this.cache, {this.onRemoved});
  final LocalStore store;
  final BlobCacheService cache;
  final void Function(String spaceId, int lostCount)? onRemoved;

  Future<void> reconcile(SpacesDto response) async {
    final removed = <(String, int)>[];
    await store.transaction(() async {
      final incoming = {for (final space in response.spaces) space.id: space};
      if (incoming.length != response.spaces.length) {
        throw const FormatException('duplicate_space');
      }
      for (final spaceId in await store.spaceIds()) {
        final existing = await store.entity(spaceId, 'space', spaceId);
        final remote = incoming[spaceId];
        if (remote == null ||
            (existing != null &&
                remote.joinEpoch >
                    (requireValue<int>(existing.data['join_epoch'])))) {
          final lost = (await store.outbox(spaceId)).length;
          removed.add((spaceId, lost));
          await store.purgeSpace(spaceId);
          await store.recordRemoval(spaceId, lost);
        } else if (existing != null &&
            remote.joinEpoch < requireValue<int>(existing.data['join_epoch'])) {
          throw const FormatException('membership_epoch_regressed');
        }
      }
      for (final space in response.spaces) {
        final existing = await store.entity(space.id, 'space', space.id);
        var localGeneration = (existing?.data['local_generation'] as int?) ?? 0;
        final oldModules = existing?.data['modules'] as Map<String, Object?>?;
        for (final module in ['ledger', 'documents']) {
          if (existing != null &&
              oldModules?[module] != 'none' &&
              space.modules[module] == 'none') {
            await store.purgeModule(space.id, module);
            localGeneration++;
          }
        }
        await store.putEntity(space.id, 'space', {
          ...?existing?.data,
          ...space.toJson(),
          'local_generation': localGeneration,
        });
        for (final member in space.members) {
          final prior = await store.entity(space.id, 'space_member', member.id);
          await store.putEntity(space.id, 'space_member', {
            ...?prior?.data,
            ...member.toJson(),
          });
        }
        for (final grant in space.modules.entries) {
          await store.putEntity(space.id, 'space_member_grant', {
            'member_id': space.memberId,
            'module': grant.key,
            'level': grant.value,
          });
        }
      }
      await store.setSpaceIds(
        response.spaces.map((space) => space.id).toList(),
      );
    });
    await cache.cleanPending();
    for (final (id, count) in removed) {
      onRemoved?.call(id, count);
    }
  }
}
