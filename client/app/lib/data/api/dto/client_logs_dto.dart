import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/data/api/dto/time_codec.dart';

part 'client_logs_dto.freezed.dart';
part 'client_logs_dto.g.dart';

@freezed
abstract class LogEntryDto with _$LogEntryDto {
  const factory LogEntryDto({
    @JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson)
    required DateTime ts,
    required String level,
    required String logger,
    required String message,
    String? errorType,
    String? stack,
    String? requestId,
  }) = _LogEntryDto;
  factory LogEntryDto.fromJson(Map<String, Object?> json) =>
      _$LogEntryDtoFromJson(json);
}

@freezed
abstract class ClientLogsDto with _$ClientLogsDto {
  const factory ClientLogsDto({
    required List<LogEntryDto> entries,
    required String appVersion,
    required int build,
    required String deviceModel,
    required String osVersion,
  }) = _ClientLogsDto;
  factory ClientLogsDto.fromJson(Map<String, Object?> json) =>
      _$ClientLogsDtoFromJson(json);
}
