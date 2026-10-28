// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_logs_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LogEntryDto _$LogEntryDtoFromJson(Map<String, dynamic> json) => _LogEntryDto(
  ts: apiTimeFromJson(json['ts'] as String),
  level: json['level'] as String,
  logger: json['logger'] as String,
  message: json['message'] as String,
  errorType: json['error_type'] as String?,
  stack: json['stack'] as String?,
  requestId: json['request_id'] as String?,
);

Map<String, dynamic> _$LogEntryDtoToJson(_LogEntryDto instance) =>
    <String, dynamic>{
      'ts': apiTimeToJson(instance.ts),
      'level': instance.level,
      'logger': instance.logger,
      'message': instance.message,
      'error_type': ?instance.errorType,
      'stack': ?instance.stack,
      'request_id': ?instance.requestId,
    };

_ClientLogsDto _$ClientLogsDtoFromJson(Map<String, dynamic> json) =>
    _ClientLogsDto(
      entries: (json['entries'] as List<dynamic>)
          .map((e) => LogEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      appVersion: json['app_version'] as String,
      build: (json['build'] as num).toInt(),
      deviceModel: json['device_model'] as String,
      osVersion: json['os_version'] as String,
    );

Map<String, dynamic> _$ClientLogsDtoToJson(_ClientLogsDto instance) =>
    <String, dynamic>{
      'entries': instance.entries.map((e) => e.toJson()).toList(),
      'app_version': instance.appVersion,
      'build': instance.build,
      'device_model': instance.deviceModel,
      'os_version': instance.osVersion,
    };
