import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';

part 'sync_dto.freezed.dart';
part 'sync_dto.g.dart';

@freezed
abstract class PushOpDto with _$PushOpDto {
  const factory PushOpDto({
    required String opId,
    required String spaceId,
    required int joinEpoch,
    required String requestId,
    required String tool,
    required Map<String, Object?> args,
  }) = _PushOpDto;
  factory PushOpDto.fromJson(Map<String, Object?> json) =>
      _$PushOpDtoFromJson(json);
}

@freezed
abstract class PushRequestDto with _$PushRequestDto {
  const factory PushRequestDto({required List<PushOpDto> ops}) =
      _PushRequestDto;
  factory PushRequestDto.fromJson(Map<String, Object?> json) =>
      _$PushRequestDtoFromJson(json);
}

@freezed
abstract class PushResultDto with _$PushResultDto {
  const factory PushResultDto({
    required String status,
    @JsonKey(includeIfNull: true) String? opId,
    Map<String, Object?>? result,
    ProblemDto? problem,
  }) = _PushResultDto;
  factory PushResultDto.fromJson(Map<String, Object?> json) =>
      _$PushResultDtoFromJson(json);
}

@freezed
abstract class PushResponseDto with _$PushResponseDto {
  const factory PushResponseDto({required List<PushResultDto> results}) =
      _PushResponseDto;
  factory PushResponseDto.fromJson(Map<String, Object?> json) =>
      _$PushResponseDtoFromJson(json);
}

@freezed
abstract class PullRequestDto with _$PullRequestDto {
  const factory PullRequestDto({
    required Map<String, int> spaces,
    @Default(500) int limit,
  }) = _PullRequestDto;
  factory PullRequestDto.fromJson(Map<String, Object?> json) =>
      _$PullRequestDtoFromJson(json);
}

@freezed
abstract class ChangeDto with _$ChangeDto {
  const factory ChangeDto({
    required String entity,
    required Map<String, Object?> data,
  }) = _ChangeDto;
  factory ChangeDto.fromJson(Map<String, Object?> json) =>
      _$ChangeDtoFromJson(json);
}

@freezed
abstract class PullPageDto with _$PullPageDto {
  const factory PullPageDto({
    required String spaceId,
    required int cursor,
    required bool hasMore,
    required List<ChangeDto> changes,
  }) = _PullPageDto;
  factory PullPageDto.fromJson(Map<String, Object?> json) =>
      _$PullPageDtoFromJson(json);
}

@freezed
abstract class PullResponseDto with _$PullResponseDto {
  const factory PullResponseDto({
    required List<PullPageDto> spaces,
    required List<String> unavailable,
  }) = _PullResponseDto;
  factory PullResponseDto.fromJson(Map<String, Object?> json) =>
      _$PullResponseDtoFromJson(json);
}
