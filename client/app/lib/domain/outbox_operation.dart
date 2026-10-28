import 'dart:convert';

import 'package:jiabu/domain/required_value.dart';

final class OutboxOperation {
  const OutboxOperation({
    required this.id,
    required this.spaceId,
    required this.joinEpoch,
    required this.kind,
    required this.payload,
    required this.entityIds,
    required this.dependsOn,
    required this.requestId,
    required this.createdAt,
    this.attempts = 0,
    this.state = 'pending',
    this.lastError,
    this.leaseUntil,
  });
  factory OutboxOperation.fromRow(Map<String, Object?> row) => OutboxOperation(
    id: requireValue<String>(row['id']),
    spaceId: requireValue<String>(row['space_id']),
    joinEpoch: requireValue<int>(row['join_epoch']),
    kind: requireValue<String>(row['kind']),
    payload: (jsonDecode(
      requireValue<String>(row['payload_json']),
    ) as Map<String, Object?>).cast<String, Object?>(),
    entityIds: (jsonDecode(
      requireValue<String>(row['entity_ids']),
    ) as List<Object?>).cast<String>().toSet(),
    dependsOn: (jsonDecode(
      requireValue<String>(row['depends_on']),
    ) as List<Object?>).cast<String>().toSet(),
    requestId: requireValue<String>(row['request_id']),
    createdAt: requireValue<int>(row['created_at']),
    attempts: requireValue<int>(row['attempts']),
    state: requireValue<String>(row['state']),
    leaseUntil: row['lease_until'] as int?,
    lastError: row['last_error'] == null
        ? null
        : (jsonDecode(
            requireValue<String>(row['last_error']),
          ) as Map<String, Object?>).cast<String, Object?>(),
  );
  final String id;
  final String spaceId;
  final int joinEpoch;
  final String kind;
  final Map<String, Object?> payload;
  final Set<String> entityIds;
  final Set<String> dependsOn;
  final String requestId;
  final int createdAt;
  final int attempts;
  final String state;
  final Map<String, Object?>? lastError;
  final int? leaseUntil;
  Set<String> get references => {...entityIds, ...dependsOn};
  int get retryAt => (lastError?['retry_at'] as int?) ?? 0;
}

final class LocalEntity {
  const LocalEntity(this.data, this.syncState, this.baseVersion);
  final Map<String, Object?> data;
  final String syncState;
  final int? baseVersion;
}

final class RequestFence {
  const RequestFence({
    required this.generation,
    required this.spaceId,
    required this.joinEpoch,
    required this.localGeneration,
  });
  final int generation;
  final String spaceId;
  final int joinEpoch;
  final int localGeneration;
}
