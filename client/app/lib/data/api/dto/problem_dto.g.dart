// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProblemDto _$ProblemDtoFromJson(Map<String, dynamic> json) => _ProblemDto(
  code: json['code'] as String,
  status: (json['status'] as num?)?.toInt(),
  requestId: json['request_id'] as String?,
  retryAfter: (json['retry_after'] as num?)?.toInt(),
  current: json['current'] as Map<String, dynamic>?,
  errors: (json['errors'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
  type: json['type'] as String?,
  title: json['title'] as String?,
);

Map<String, dynamic> _$ProblemDtoToJson(_ProblemDto instance) =>
    <String, dynamic>{
      'code': instance.code,
      'status': ?instance.status,
      'request_id': ?instance.requestId,
      'retry_after': ?instance.retryAfter,
      'current': ?instance.current,
      'errors': ?instance.errors,
      'type': ?instance.type,
      'title': ?instance.title,
    };
