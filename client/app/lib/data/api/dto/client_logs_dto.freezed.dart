// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_logs_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LogEntryDto {

@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson) DateTime get ts; String get level; String get logger; String get message; String? get errorType; String? get stack; String? get requestId;
/// Create a copy of LogEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LogEntryDtoCopyWith<LogEntryDto> get copyWith => _$LogEntryDtoCopyWithImpl<LogEntryDto>(this as LogEntryDto, _$identity);

  /// Serializes this LogEntryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LogEntryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LogEntryDto&&(identical(other.ts, _this.ts) || other.ts == _this.ts)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.logger, _this.logger) || other.logger == _this.logger)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.errorType, _this.errorType) || other.errorType == _this.errorType)&&(identical(other.stack, _this.stack) || other.stack == _this.stack)&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LogEntryDto;
  return Object.hash(runtimeType,_this.ts,_this.level,_this.logger,_this.message,_this.errorType,_this.stack,_this.requestId);
}

@override
String toString() {
  final _this = this as LogEntryDto;
  return 'LogEntryDto(ts: ${_this.ts}, level: ${_this.level}, logger: ${_this.logger}, message: ${_this.message}, errorType: ${_this.errorType}, stack: ${_this.stack}, requestId: ${_this.requestId})';
}


}

/// @nodoc
abstract mixin class $LogEntryDtoCopyWith<$Res>  {
  factory $LogEntryDtoCopyWith(LogEntryDto value, $Res Function(LogEntryDto) _then) = _$LogEntryDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson) DateTime ts, String level, String logger, String message, String? errorType, String? stack, String? requestId
});




}
/// @nodoc
class _$LogEntryDtoCopyWithImpl<$Res>
    implements $LogEntryDtoCopyWith<$Res> {
  _$LogEntryDtoCopyWithImpl(this._self, this._then);

  final LogEntryDto _self;
  final $Res Function(LogEntryDto) _then;

/// Create a copy of LogEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ts = null,Object? level = null,Object? logger = null,Object? message = null,Object? errorType = freezed,Object? stack = freezed,Object? requestId = freezed,}) {
  return _then(LogEntryDto(
ts: null == ts ? _self.ts : ts // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,logger: null == logger ? _self.logger : logger // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,errorType: freezed == errorType ? _self.errorType : errorType // ignore: cast_nullable_to_non_nullable
as String?,stack: freezed == stack ? _self.stack : stack // ignore: cast_nullable_to_non_nullable
as String?,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LogEntryDto].
extension LogEntryDtoPatterns on LogEntryDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LogEntryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LogEntryDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LogEntryDto value)  $default,){
final _that = this;
switch (_that) {
case _LogEntryDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LogEntryDto value)?  $default,){
final _that = this;
switch (_that) {
case _LogEntryDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson)  DateTime ts,  String level,  String logger,  String message,  String? errorType,  String? stack,  String? requestId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LogEntryDto() when $default != null:
return $default(_that.ts,_that.level,_that.logger,_that.message,_that.errorType,_that.stack,_that.requestId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson)  DateTime ts,  String level,  String logger,  String message,  String? errorType,  String? stack,  String? requestId)  $default,) {final _that = this;
switch (_that) {
case _LogEntryDto():
return $default(_that.ts,_that.level,_that.logger,_that.message,_that.errorType,_that.stack,_that.requestId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson)  DateTime ts,  String level,  String logger,  String message,  String? errorType,  String? stack,  String? requestId)?  $default,) {final _that = this;
switch (_that) {
case _LogEntryDto() when $default != null:
return $default(_that.ts,_that.level,_that.logger,_that.message,_that.errorType,_that.stack,_that.requestId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LogEntryDto implements LogEntryDto {
  const _LogEntryDto({@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson) required this.ts, required this.level, required this.logger, required this.message, this.errorType, this.stack, this.requestId});
  factory _LogEntryDto.fromJson(Map<String, dynamic> json) => _$LogEntryDtoFromJson(json);

@override@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson) final  DateTime ts;
@override final  String level;
@override final  String logger;
@override final  String message;
@override final  String? errorType;
@override final  String? stack;
@override final  String? requestId;

/// Create a copy of LogEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LogEntryDtoCopyWith<_LogEntryDto> get copyWith => __$LogEntryDtoCopyWithImpl<_LogEntryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LogEntryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogEntryDto&&(identical(other.ts, ts) || other.ts == ts)&&(identical(other.level, level) || other.level == level)&&(identical(other.logger, logger) || other.logger == logger)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorType, errorType) || other.errorType == errorType)&&(identical(other.stack, stack) || other.stack == stack)&&(identical(other.requestId, requestId) || other.requestId == requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ts,level,logger,message,errorType,stack,requestId);
}

@override
String toString() {
    return 'LogEntryDto(ts: $ts, level: $level, logger: $logger, message: $message, errorType: $errorType, stack: $stack, requestId: $requestId)';
}


}

/// @nodoc
abstract mixin class _$LogEntryDtoCopyWith<$Res> implements $LogEntryDtoCopyWith<$Res> {
  factory _$LogEntryDtoCopyWith(_LogEntryDto value, $Res Function(_LogEntryDto) _then) = __$LogEntryDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: apiTimeFromJson, toJson: apiTimeToJson) DateTime ts, String level, String logger, String message, String? errorType, String? stack, String? requestId
});




}
/// @nodoc
class __$LogEntryDtoCopyWithImpl<$Res>
    implements _$LogEntryDtoCopyWith<$Res> {
  __$LogEntryDtoCopyWithImpl(this._self, this._then);

  final _LogEntryDto _self;
  final $Res Function(_LogEntryDto) _then;

/// Create a copy of LogEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ts = null,Object? level = null,Object? logger = null,Object? message = null,Object? errorType = freezed,Object? stack = freezed,Object? requestId = freezed,}) {
  return _then(_LogEntryDto(
ts: null == ts ? _self.ts : ts // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,logger: null == logger ? _self.logger : logger // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,errorType: freezed == errorType ? _self.errorType : errorType // ignore: cast_nullable_to_non_nullable
as String?,stack: freezed == stack ? _self.stack : stack // ignore: cast_nullable_to_non_nullable
as String?,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ClientLogsDto {

 List<LogEntryDto> get entries; String get appVersion; int get build; String get deviceModel; String get osVersion;
/// Create a copy of ClientLogsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientLogsDtoCopyWith<ClientLogsDto> get copyWith => _$ClientLogsDtoCopyWithImpl<ClientLogsDto>(this as ClientLogsDto, _$identity);

  /// Serializes this ClientLogsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ClientLogsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientLogsDto&&const DeepCollectionEquality().equals(other.entries, _this.entries)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.build, _this.build) || other.build == _this.build)&&(identical(other.deviceModel, _this.deviceModel) || other.deviceModel == _this.deviceModel)&&(identical(other.osVersion, _this.osVersion) || other.osVersion == _this.osVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClientLogsDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.entries),_this.appVersion,_this.build,_this.deviceModel,_this.osVersion);
}

@override
String toString() {
  final _this = this as ClientLogsDto;
  return 'ClientLogsDto(entries: ${_this.entries}, appVersion: ${_this.appVersion}, build: ${_this.build}, deviceModel: ${_this.deviceModel}, osVersion: ${_this.osVersion})';
}


}

/// @nodoc
abstract mixin class $ClientLogsDtoCopyWith<$Res>  {
  factory $ClientLogsDtoCopyWith(ClientLogsDto value, $Res Function(ClientLogsDto) _then) = _$ClientLogsDtoCopyWithImpl;
@useResult
$Res call({
 List<LogEntryDto> entries, String appVersion, int build, String deviceModel, String osVersion
});




}
/// @nodoc
class _$ClientLogsDtoCopyWithImpl<$Res>
    implements $ClientLogsDtoCopyWith<$Res> {
  _$ClientLogsDtoCopyWithImpl(this._self, this._then);

  final ClientLogsDto _self;
  final $Res Function(ClientLogsDto) _then;

/// Create a copy of ClientLogsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,Object? appVersion = null,Object? build = null,Object? deviceModel = null,Object? osVersion = null,}) {
  return _then(ClientLogsDto(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<LogEntryDto>,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,build: null == build ? _self.build : build // ignore: cast_nullable_to_non_nullable
as int,deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,osVersion: null == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientLogsDto].
extension ClientLogsDtoPatterns on ClientLogsDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientLogsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientLogsDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientLogsDto value)  $default,){
final _that = this;
switch (_that) {
case _ClientLogsDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientLogsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ClientLogsDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LogEntryDto> entries,  String appVersion,  int build,  String deviceModel,  String osVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientLogsDto() when $default != null:
return $default(_that.entries,_that.appVersion,_that.build,_that.deviceModel,_that.osVersion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LogEntryDto> entries,  String appVersion,  int build,  String deviceModel,  String osVersion)  $default,) {final _that = this;
switch (_that) {
case _ClientLogsDto():
return $default(_that.entries,_that.appVersion,_that.build,_that.deviceModel,_that.osVersion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LogEntryDto> entries,  String appVersion,  int build,  String deviceModel,  String osVersion)?  $default,) {final _that = this;
switch (_that) {
case _ClientLogsDto() when $default != null:
return $default(_that.entries,_that.appVersion,_that.build,_that.deviceModel,_that.osVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientLogsDto implements ClientLogsDto {
  const _ClientLogsDto({required  List<LogEntryDto> entries, required this.appVersion, required this.build, required this.deviceModel, required this.osVersion}): _entries = entries;
  factory _ClientLogsDto.fromJson(Map<String, dynamic> json) => _$ClientLogsDtoFromJson(json);

 final  List<LogEntryDto> _entries;
@override List<LogEntryDto> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

@override final  String appVersion;
@override final  int build;
@override final  String deviceModel;
@override final  String osVersion;

/// Create a copy of ClientLogsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientLogsDtoCopyWith<_ClientLogsDto> get copyWith => __$ClientLogsDtoCopyWithImpl<_ClientLogsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientLogsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientLogsDto&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.build, build) || other.build == build)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.osVersion, osVersion) || other.osVersion == osVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),appVersion,build,deviceModel,osVersion);
}

@override
String toString() {
    return 'ClientLogsDto(entries: $entries, appVersion: $appVersion, build: $build, deviceModel: $deviceModel, osVersion: $osVersion)';
}


}

/// @nodoc
abstract mixin class _$ClientLogsDtoCopyWith<$Res> implements $ClientLogsDtoCopyWith<$Res> {
  factory _$ClientLogsDtoCopyWith(_ClientLogsDto value, $Res Function(_ClientLogsDto) _then) = __$ClientLogsDtoCopyWithImpl;
@override @useResult
$Res call({
 List<LogEntryDto> entries, String appVersion, int build, String deviceModel, String osVersion
});




}
/// @nodoc
class __$ClientLogsDtoCopyWithImpl<$Res>
    implements _$ClientLogsDtoCopyWith<$Res> {
  __$ClientLogsDtoCopyWithImpl(this._self, this._then);

  final _ClientLogsDto _self;
  final $Res Function(_ClientLogsDto) _then;

/// Create a copy of ClientLogsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? appVersion = null,Object? build = null,Object? deviceModel = null,Object? osVersion = null,}) {
  return _then(_ClientLogsDto(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<LogEntryDto>,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,build: null == build ? _self.build : build // ignore: cast_nullable_to_non_nullable
as int,deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,osVersion: null == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
