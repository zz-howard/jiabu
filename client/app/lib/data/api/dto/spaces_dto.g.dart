// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spaces_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MemberSummaryDto _$MemberSummaryDtoFromJson(Map<String, dynamic> json) =>
    _MemberSummaryDto(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$MemberSummaryDtoToJson(_MemberSummaryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'role': instance.role,
      'status': instance.status,
      'version': instance.version,
    };

_SpaceDto _$SpaceDtoFromJson(Map<String, dynamic> json) => _SpaceDto(
  id: json['id'] as String,
  name: json['name'] as String,
  accentColor: json['accent_color'] as String,
  currency: json['currency'] as String,
  timezone: json['timezone'] as String,
  isDefault: json['is_default'] as bool,
  version: (json['version'] as num).toInt(),
  role: json['role'] as String,
  joinEpoch: (json['join_epoch'] as num).toInt(),
  memberId: json['member_id'] as String,
  modules: Map<String, String>.from(json['modules'] as Map),
  members: (json['members'] as List<dynamic>)
      .map((e) => MemberSummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SpaceDtoToJson(_SpaceDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'accent_color': instance.accentColor,
  'currency': instance.currency,
  'timezone': instance.timezone,
  'is_default': instance.isDefault,
  'version': instance.version,
  'role': instance.role,
  'join_epoch': instance.joinEpoch,
  'member_id': instance.memberId,
  'modules': instance.modules,
  'members': instance.members.map((e) => e.toJson()).toList(),
};

_SpacesDto _$SpacesDtoFromJson(Map<String, dynamic> json) => _SpacesDto(
  spaces: (json['spaces'] as List<dynamic>)
      .map((e) => SpaceDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SpacesDtoToJson(_SpacesDto instance) =>
    <String, dynamic>{
      'spaces': instance.spaces.map((e) => e.toJson()).toList(),
    };
