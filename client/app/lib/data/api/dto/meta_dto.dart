import 'package:freezed_annotation/freezed_annotation.dart';

part 'meta_dto.freezed.dart';
part 'meta_dto.g.dart';

@freezed
abstract class MetaDto with _$MetaDto {
  const factory MetaDto({
    required String serverVersion,
    required List<int> apiVersions,
    required Map<String, int> minClientBuild,
    required List<String> features,
  }) = _MetaDto;
  factory MetaDto.fromJson(Map<String, Object?> json) =>
      _$MetaDtoFromJson(json);
}
