import 'package:flutter/foundation.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

@immutable
final class SpaceInfo {
  const SpaceInfo({
    required this.id,
    required this.name,
    required this.accent,
    required this.currency,
    required this.timezone,
    required this.isDefault,
    required this.role,
    required this.memberId,
    required this.joinEpoch,
    required this.version,
    required this.members,
  });
  factory SpaceInfo.fromJson(Map<String, Object?> json) => SpaceInfo(
    id: requireValue<String>(json['id']),
    name: requireValue<String>(json['name']),
    accent: requireValue<String>(json['accent_color']),
    currency: requireValue<String>(json['currency']),
    timezone: requireValue<String>(json['timezone']),
    isDefault: requireValue<bool>(json['is_default']),
    role: requireValue<String>(json['role']),
    memberId: requireValue<String>(json['member_id']),
    joinEpoch: requireValue<int>(json['join_epoch']),
    version: requireValue<int>(json['version']),
    members: List.unmodifiable(
      requireValue<List<Object?>>(json['members']).map(
        (row) =>
            SpaceMemberInfo.fromJson(requireValue<Map<String, Object?>>(row)),
      ),
    ),
  );
  final String id;
  final String name;
  final String accent;
  final String currency;
  final String timezone;
  final bool isDefault;
  final String role;
  final String memberId;
  final int joinEpoch;
  final int version;
  final List<SpaceMemberInfo> members;
  bool get owner => role == 'owner';
  List<SpaceMemberInfo> get activeMembers =>
      members.where((member) => member.active).toList();
  bool get canDelete => owner && !isDefault && activeMembers.length == 1;
  bool get lastOwner =>
      owner &&
      activeMembers.where((member) => member.role == 'owner').length == 1;
  // P71: only the owner invites; the owner may withdraw any pending
  // invitation and a former owner keeps withdrawing what it sent before a
  // transfer.
  bool get canInvite => owner && !isDefault;
  bool canCancel(String inviter) => owner || memberId == inviter;
}

@immutable
final class SpaceMemberInfo {
  const SpaceMemberInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.version,
  });
  factory SpaceMemberInfo.fromJson(Map<String, Object?> json) =>
      SpaceMemberInfo(
        id: requireValue<String>(json['id']),
        name: requireValue<String>(json['display_name']),
        role: requireValue<String>(json['role']),
        status: requireValue<String>(json['status']),
        version: requireValue<int>(json['version']),
      );
  final String id;
  final String name;
  final String role;
  final String status;
  final int version;
  bool get active => status == 'active';
}

abstract interface class SpacesRepository {
  Stream<List<SpaceInfo>> watch();
  Future<int> pendingCount(String spaceId);
  Future<Result<void>> select(String spaceId);
  Future<Result<void>> create(Map<String, Object?> input, String operationId);
  Future<Result<void>> change(
    SpaceInfo space,
    String action,
    String operationId, {
    Map<String, Object?>? body,
    String? target,
  });
  Future<Result<List<Map<String, Object?>>>> invitations(String? spaceId);
  Future<Result<void>> decide(
    String id,
    String operationId, {
    required bool accept,
  });
}
