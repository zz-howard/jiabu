// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MetaDto _$MetaDtoFromJson(Map<String, dynamic> json) => _MetaDto(
  serverVersion: json['server_version'] as String,
  apiVersions: (json['api_versions'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  minClientBuild: Map<String, int>.from(json['min_client_build'] as Map),
  features: (json['features'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MetaDtoToJson(_MetaDto instance) => <String, dynamic>{
  'server_version': instance.serverVersion,
  'api_versions': instance.apiVersions,
  'min_client_build': instance.minClientBuild,
  'features': instance.features,
};
