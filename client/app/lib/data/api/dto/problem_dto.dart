import 'package:freezed_annotation/freezed_annotation.dart';

part 'problem_dto.freezed.dart';
part 'problem_dto.g.dart';

@freezed
abstract class ProblemDto with _$ProblemDto {
  const factory ProblemDto({
    required String code,
    int? status,
    String? requestId,
    int? retryAfter,
    Map<String, Object?>? current,
    List<Map<String, Object?>>? errors,
    String? type,
    String? title,
  }) = _ProblemDto;
  factory ProblemDto.fromJson(Map<String, Object?> json) =>
      _$ProblemDtoFromJson(json);
}
