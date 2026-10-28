import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/data/api/dto/time_codec.dart';

part 'auth_dto.freezed.dart';
part 'auth_dto.g.dart';

@freezed
abstract class UserDto with _$UserDto {
  const factory UserDto({
    required String id,
    required String username,
    required String locale,
  }) = _UserDto;
  factory UserDto.fromJson(Map<String, Object?> json) =>
      _$UserDtoFromJson(json);
}

@freezed
abstract class LoginRequestDto with _$LoginRequestDto {
  const factory LoginRequestDto({
    required String username,
    required String password,
    String? deviceName,
  }) = _LoginRequestDto;
  factory LoginRequestDto.fromJson(Map<String, Object?> json) =>
      _$LoginRequestDtoFromJson(json);
}

@freezed
abstract class LoginResponseDto with _$LoginResponseDto {
  const factory LoginResponseDto({
    required String token,
    required String sessionKind,
    required UserDto user,
    @JsonKey(fromJson: optionalApiTimeFromJson, toJson: optionalApiTimeToJson)
    DateTime? adminResetAt,
  }) = _LoginResponseDto;
  factory LoginResponseDto.fromJson(Map<String, Object?> json) =>
      _$LoginResponseDtoFromJson(json);
}

@freezed
abstract class ChangePasswordDto with _$ChangePasswordDto {
  const factory ChangePasswordDto({
    required String currentPassword,
    required String newPassword,
  }) = _ChangePasswordDto;
  factory ChangePasswordDto.fromJson(Map<String, Object?> json) =>
      _$ChangePasswordDtoFromJson(json);
}
