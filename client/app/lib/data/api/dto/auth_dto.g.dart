// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserDto _$UserDtoFromJson(Map<String, dynamic> json) => _UserDto(
  id: json['id'] as String,
  username: json['username'] as String,
  locale: json['locale'] as String,
);

Map<String, dynamic> _$UserDtoToJson(_UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'locale': instance.locale,
};

_LoginRequestDto _$LoginRequestDtoFromJson(Map<String, dynamic> json) =>
    _LoginRequestDto(
      username: json['username'] as String,
      password: json['password'] as String,
      deviceName: json['device_name'] as String?,
    );

Map<String, dynamic> _$LoginRequestDtoToJson(_LoginRequestDto instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
      'device_name': ?instance.deviceName,
    };

_LoginResponseDto _$LoginResponseDtoFromJson(Map<String, dynamic> json) =>
    _LoginResponseDto(
      token: json['token'] as String,
      sessionKind: json['session_kind'] as String,
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
      adminResetAt: optionalApiTimeFromJson(json['admin_reset_at'] as String?),
    );

Map<String, dynamic> _$LoginResponseDtoToJson(_LoginResponseDto instance) =>
    <String, dynamic>{
      'token': instance.token,
      'session_kind': instance.sessionKind,
      'user': instance.user.toJson(),
      'admin_reset_at': ?optionalApiTimeToJson(instance.adminResetAt),
    };

_ChangePasswordDto _$ChangePasswordDtoFromJson(Map<String, dynamic> json) =>
    _ChangePasswordDto(
      currentPassword: json['current_password'] as String,
      newPassword: json['new_password'] as String,
    );

Map<String, dynamic> _$ChangePasswordDtoToJson(_ChangePasswordDto instance) =>
    <String, dynamic>{
      'current_password': instance.currentPassword,
      'new_password': instance.newPassword,
    };
