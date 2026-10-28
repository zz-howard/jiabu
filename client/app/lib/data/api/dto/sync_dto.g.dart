// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PushOpDto _$PushOpDtoFromJson(Map<String, dynamic> json) => _PushOpDto(
  opId: json['op_id'] as String,
  spaceId: json['space_id'] as String,
  joinEpoch: (json['join_epoch'] as num).toInt(),
  requestId: json['request_id'] as String,
  tool: json['tool'] as String,
  args: json['args'] as Map<String, dynamic>,
);

Map<String, dynamic> _$PushOpDtoToJson(_PushOpDto instance) =>
    <String, dynamic>{
      'op_id': instance.opId,
      'space_id': instance.spaceId,
      'join_epoch': instance.joinEpoch,
      'request_id': instance.requestId,
      'tool': instance.tool,
      'args': instance.args,
    };

_PushRequestDto _$PushRequestDtoFromJson(Map<String, dynamic> json) =>
    _PushRequestDto(
      ops: (json['ops'] as List<dynamic>)
          .map((e) => PushOpDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PushRequestDtoToJson(_PushRequestDto instance) =>
    <String, dynamic>{'ops': instance.ops.map((e) => e.toJson()).toList()};

_PushResultDto _$PushResultDtoFromJson(Map<String, dynamic> json) =>
    _PushResultDto(
      status: json['status'] as String,
      opId: json['op_id'] as String?,
      result: json['result'] as Map<String, dynamic>?,
      problem: json['problem'] == null
          ? null
          : ProblemDto.fromJson(json['problem'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PushResultDtoToJson(_PushResultDto instance) =>
    <String, dynamic>{
      'status': instance.status,
      'op_id': instance.opId,
      'result': ?instance.result,
      'problem': ?instance.problem?.toJson(),
    };

_PushResponseDto _$PushResponseDtoFromJson(Map<String, dynamic> json) =>
    _PushResponseDto(
      results: (json['results'] as List<dynamic>)
          .map((e) => PushResultDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PushResponseDtoToJson(_PushResponseDto instance) =>
    <String, dynamic>{
      'results': instance.results.map((e) => e.toJson()).toList(),
    };

_PullRequestDto _$PullRequestDtoFromJson(Map<String, dynamic> json) =>
    _PullRequestDto(
      spaces: Map<String, int>.from(json['spaces'] as Map),
      limit: (json['limit'] as num?)?.toInt() ?? 500,
    );

Map<String, dynamic> _$PullRequestDtoToJson(_PullRequestDto instance) =>
    <String, dynamic>{'spaces': instance.spaces, 'limit': instance.limit};

_ChangeDto _$ChangeDtoFromJson(Map<String, dynamic> json) => _ChangeDto(
  entity: json['entity'] as String,
  data: json['data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$ChangeDtoToJson(_ChangeDto instance) =>
    <String, dynamic>{'entity': instance.entity, 'data': instance.data};

_PullPageDto _$PullPageDtoFromJson(Map<String, dynamic> json) => _PullPageDto(
  spaceId: json['space_id'] as String,
  cursor: (json['cursor'] as num).toInt(),
  hasMore: json['has_more'] as bool,
  changes: (json['changes'] as List<dynamic>)
      .map((e) => ChangeDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PullPageDtoToJson(_PullPageDto instance) =>
    <String, dynamic>{
      'space_id': instance.spaceId,
      'cursor': instance.cursor,
      'has_more': instance.hasMore,
      'changes': instance.changes.map((e) => e.toJson()).toList(),
    };

_PullResponseDto _$PullResponseDtoFromJson(Map<String, dynamic> json) =>
    _PullResponseDto(
      spaces: (json['spaces'] as List<dynamic>)
          .map((e) => PullPageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      unavailable: (json['unavailable'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$PullResponseDtoToJson(_PullResponseDto instance) =>
    <String, dynamic>{
      'spaces': instance.spaces.map((e) => e.toJson()).toList(),
      'unavailable': instance.unavailable,
    };
