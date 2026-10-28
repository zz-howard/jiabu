import 'package:freezed_annotation/freezed_annotation.dart';

part 'spaces_dto.freezed.dart';
part 'spaces_dto.g.dart';

@freezed
abstract class MemberSummaryDto with _$MemberSummaryDto {
  const factory MemberSummaryDto({
    required String id,
    required String displayName,
    required String role,
    required String status,
    required int version,
  }) = _MemberSummaryDto;
  factory MemberSummaryDto.fromJson(Map<String, Object?> json) =>
      _$MemberSummaryDtoFromJson(json);
}

@freezed
abstract class SpaceDto with _$SpaceDto {
  const factory SpaceDto({
    required String id,
    required String name,
    required String accentColor,
    required String currency,
    required String timezone,
    required bool isDefault,
    required int version,
    required String role,
    required int joinEpoch,
    required String memberId,
    required Map<String, String> modules,
    required List<MemberSummaryDto> members,
  }) = _SpaceDto;
  factory SpaceDto.fromJson(Map<String, Object?> json) =>
      _$SpaceDtoFromJson(json);
}

@freezed
abstract class SpacesDto with _$SpacesDto {
  const factory SpacesDto({required List<SpaceDto> spaces}) = _SpacesDto;
  factory SpacesDto.fromJson(Map<String, Object?> json) =>
      _$SpacesDtoFromJson(json);
}
