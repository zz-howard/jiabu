// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'problem_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProblemDto {

 String get code; int? get status; String? get requestId; int? get retryAfter; Map<String, Object?>? get current; List<Map<String, Object?>>? get errors; String? get type; String? get title;
/// Create a copy of ProblemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProblemDtoCopyWith<ProblemDto> get copyWith => _$ProblemDtoCopyWithImpl<ProblemDto>(this as ProblemDto, _$identity);

  /// Serializes this ProblemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProblemDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProblemDto&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.retryAfter, _this.retryAfter) || other.retryAfter == _this.retryAfter)&&const DeepCollectionEquality().equals(other.current, _this.current)&&const DeepCollectionEquality().equals(other.errors, _this.errors)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.title, _this.title) || other.title == _this.title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProblemDto;
  return Object.hash(runtimeType,_this.code,_this.status,_this.requestId,_this.retryAfter,const DeepCollectionEquality().hash(_this.current),const DeepCollectionEquality().hash(_this.errors),_this.type,_this.title);
}

@override
String toString() {
  final _this = this as ProblemDto;
  return 'ProblemDto(code: ${_this.code}, status: ${_this.status}, requestId: ${_this.requestId}, retryAfter: ${_this.retryAfter}, current: ${_this.current}, errors: ${_this.errors}, type: ${_this.type}, title: ${_this.title})';
}


}

/// @nodoc
abstract mixin class $ProblemDtoCopyWith<$Res>  {
  factory $ProblemDtoCopyWith(ProblemDto value, $Res Function(ProblemDto) _then) = _$ProblemDtoCopyWithImpl;
@useResult
$Res call({
 String code, int? status, String? requestId, int? retryAfter, Map<String, Object?>? current, List<Map<String, Object?>>? errors, String? type, String? title
});




}
/// @nodoc
class _$ProblemDtoCopyWithImpl<$Res>
    implements $ProblemDtoCopyWith<$Res> {
  _$ProblemDtoCopyWithImpl(this._self, this._then);

  final ProblemDto _self;
  final $Res Function(ProblemDto) _then;

/// Create a copy of ProblemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? status = freezed,Object? requestId = freezed,Object? retryAfter = freezed,Object? current = freezed,Object? errors = freezed,Object? type = freezed,Object? title = freezed,}) {
  return _then(ProblemDto(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,retryAfter: freezed == retryAfter ? _self.retryAfter : retryAfter // ignore: cast_nullable_to_non_nullable
as int?,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,errors: freezed == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProblemDto].
extension ProblemDtoPatterns on ProblemDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProblemDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProblemDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProblemDto value)  $default,){
final _that = this;
switch (_that) {
case _ProblemDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProblemDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProblemDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int? status,  String? requestId,  int? retryAfter,  Map<String, Object?>? current,  List<Map<String, Object?>>? errors,  String? type,  String? title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProblemDto() when $default != null:
return $default(_that.code,_that.status,_that.requestId,_that.retryAfter,_that.current,_that.errors,_that.type,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int? status,  String? requestId,  int? retryAfter,  Map<String, Object?>? current,  List<Map<String, Object?>>? errors,  String? type,  String? title)  $default,) {final _that = this;
switch (_that) {
case _ProblemDto():
return $default(_that.code,_that.status,_that.requestId,_that.retryAfter,_that.current,_that.errors,_that.type,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int? status,  String? requestId,  int? retryAfter,  Map<String, Object?>? current,  List<Map<String, Object?>>? errors,  String? type,  String? title)?  $default,) {final _that = this;
switch (_that) {
case _ProblemDto() when $default != null:
return $default(_that.code,_that.status,_that.requestId,_that.retryAfter,_that.current,_that.errors,_that.type,_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProblemDto implements ProblemDto {
  const _ProblemDto({required this.code, this.status, this.requestId, this.retryAfter,  Map<String, Object?>? current,  List<Map<String, Object?>>? errors, this.type, this.title}): _current = current,_errors = errors;
  factory _ProblemDto.fromJson(Map<String, dynamic> json) => _$ProblemDtoFromJson(json);

@override final  String code;
@override final  int? status;
@override final  String? requestId;
@override final  int? retryAfter;
 final  Map<String, Object?>? _current;
@override Map<String, Object?>? get current {
  final value = _current;
  if (value == null) return null;
  if (_current is EqualUnmodifiableMapView) return _current;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<Map<String, Object?>>? _errors;
@override List<Map<String, Object?>>? get errors {
  final value = _errors;
  if (value == null) return null;
  if (_errors is EqualUnmodifiableListView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? type;
@override final  String? title;

/// Create a copy of ProblemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProblemDtoCopyWith<_ProblemDto> get copyWith => __$ProblemDtoCopyWithImpl<_ProblemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProblemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProblemDto&&(identical(other.code, code) || other.code == code)&&(identical(other.status, status) || other.status == status)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.retryAfter, retryAfter) || other.retryAfter == retryAfter)&&const DeepCollectionEquality().equals(other.current, _current)&&const DeepCollectionEquality().equals(other.errors, _errors)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,status,requestId,retryAfter,const DeepCollectionEquality().hash(_current),const DeepCollectionEquality().hash(_errors),type,title);
}

@override
String toString() {
    return 'ProblemDto(code: $code, status: $status, requestId: $requestId, retryAfter: $retryAfter, current: $current, errors: $errors, type: $type, title: $title)';
}


}

/// @nodoc
abstract mixin class _$ProblemDtoCopyWith<$Res> implements $ProblemDtoCopyWith<$Res> {
  factory _$ProblemDtoCopyWith(_ProblemDto value, $Res Function(_ProblemDto) _then) = __$ProblemDtoCopyWithImpl;
@override @useResult
$Res call({
 String code, int? status, String? requestId, int? retryAfter, Map<String, Object?>? current, List<Map<String, Object?>>? errors, String? type, String? title
});




}
/// @nodoc
class __$ProblemDtoCopyWithImpl<$Res>
    implements _$ProblemDtoCopyWith<$Res> {
  __$ProblemDtoCopyWithImpl(this._self, this._then);

  final _ProblemDto _self;
  final $Res Function(_ProblemDto) _then;

/// Create a copy of ProblemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? status = freezed,Object? requestId = freezed,Object? retryAfter = freezed,Object? current = freezed,Object? errors = freezed,Object? type = freezed,Object? title = freezed,}) {
  return _then(_ProblemDto(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,retryAfter: freezed == retryAfter ? _self.retryAfter : retryAfter // ignore: cast_nullable_to_non_nullable
as int?,current: freezed == current ? _self._current : current // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,errors: freezed == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
