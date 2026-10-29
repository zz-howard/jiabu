import 'dart:convert';

import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/required_value.dart';

final class PullApplier {
  PullApplier(this.store);
  final LocalStore store;

  Future<void> applyPage(
    PullPageDto page, {
    required int requestedCursor,
  }) async {
    final spaceId = page.spaceId;
    if (page.cursor < requestedCursor ||
        (page.changes.isEmpty && page.cursor != requestedCursor) ||
        (page.hasMore && page.cursor <= requestedCursor)) {
      throw const FormatException('invalid_cursor');
    }
    for (final change in page.changes) {
      final id = store.keyOf(change.entity, change.data);
      final local = await store.entity(spaceId, change.entity, id);
      if (change.entity != 'chat_entry' && local?.syncState == 'pending') {
        continue;
      }
      final data = change.entity == 'space' && local != null
          ? {...local.data, ...change.data}
          : change.data;
      await store.putEntity(
        spaceId,
        change.entity,
        data,
        state: local?.syncState == 'conflict' ? 'conflict' : 'synced',
      );
      if (local?.syncState == 'conflict') {
        final conflict = await store.conflict(
          spaceId,
          change.entity,
          id.toString(),
        );
        if (conflict != null) {
          // Preserve mine, advance only the visible server version/status.
          await store.putConflict(
            spaceId,
            change.entity,
            id.toString(),
            (jsonDecode(
              requireValue<String>(conflict['mine_json']),
            ) as Map<String, Object?>).cast<String, Object?>(),
            requireValue<int>(change.data['version']),
            change.data['status'] as String?,
            requireValue<int>(conflict['detected_at']),
          );
        }
      }
    }
    await store.setCursor(spaceId, page.cursor);
  }
}
