// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PushOpDto {

 String get opId; String get spaceId; int get joinEpoch; String get requestId; String get tool; Map<String, Object?> get args;
/// Create a copy of PushOpDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushOpDtoCopyWith<PushOpDto> get copyWith => _$PushOpDtoCopyWithImpl<PushOpDto>(this as PushOpDto, _$identity);

  /// Serializes this PushOpDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PushOpDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushOpDto&&(identical(other.opId, _this.opId) || other.opId == _this.opId)&&(identical(other.spaceId, _this.spaceId) || other.spaceId == _this.spaceId)&&(identical(other.joinEpoch, _this.joinEpoch) || other.joinEpoch == _this.joinEpoch)&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.tool, _this.tool) || other.tool == _this.tool)&&const DeepCollectionEquality().equals(other.args, _this.args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PushOpDto;
  return Object.hash(runtimeType,_this.opId,_this.spaceId,_this.joinEpoch,_this.requestId,_this.tool,const DeepCollectionEquality().hash(_this.args));
}

@override
String toString() {
  final _this = this as PushOpDto;
  return 'PushOpDto(opId: ${_this.opId}, spaceId: ${_this.spaceId}, joinEpoch: ${_this.joinEpoch}, requestId: ${_this.requestId}, tool: ${_this.tool}, args: ${_this.args})';
}


}

/// @nodoc
abstract mixin class $PushOpDtoCopyWith<$Res>  {
  factory $PushOpDtoCopyWith(PushOpDto value, $Res Function(PushOpDto) _then) = _$PushOpDtoCopyWithImpl;
@useResult
$Res call({
 String opId, String spaceId, int joinEpoch, String requestId, String tool, Map<String, Object?> args
});




}
/// @nodoc
class _$PushOpDtoCopyWithImpl<$Res>
    implements $PushOpDtoCopyWith<$Res> {
  _$PushOpDtoCopyWithImpl(this._self, this._then);

  final PushOpDto _self;
  final $Res Function(PushOpDto) _then;

/// Create a copy of PushOpDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? opId = null,Object? spaceId = null,Object? joinEpoch = null,Object? requestId = null,Object? tool = null,Object? args = null,}) {
  return _then(PushOpDto(
opId: null == opId ? _self.opId : opId // ignore: cast_nullable_to_non_nullable
as String,spaceId: null == spaceId ? _self.spaceId : spaceId // ignore: cast_nullable_to_non_nullable
as String,joinEpoch: null == joinEpoch ? _self.joinEpoch : joinEpoch // ignore: cast_nullable_to_non_nullable
as int,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [PushOpDto].
extension PushOpDtoPatterns on PushOpDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushOpDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushOpDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushOpDto value)  $default,){
final _that = this;
switch (_that) {
case _PushOpDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushOpDto value)?  $default,){
final _that = this;
switch (_that) {
case _PushOpDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String opId,  String spaceId,  int joinEpoch,  String requestId,  String tool,  Map<String, Object?> args)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushOpDto() when $default != null:
return $default(_that.opId,_that.spaceId,_that.joinEpoch,_that.requestId,_that.tool,_that.args);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String opId,  String spaceId,  int joinEpoch,  String requestId,  String tool,  Map<String, Object?> args)  $default,) {final _that = this;
switch (_that) {
case _PushOpDto():
return $default(_that.opId,_that.spaceId,_that.joinEpoch,_that.requestId,_that.tool,_that.args);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String opId,  String spaceId,  int joinEpoch,  String requestId,  String tool,  Map<String, Object?> args)?  $default,) {final _that = this;
switch (_that) {
case _PushOpDto() when $default != null:
return $default(_that.opId,_that.spaceId,_that.joinEpoch,_that.requestId,_that.tool,_that.args);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushOpDto implements PushOpDto {
  const _PushOpDto({required this.opId, required this.spaceId, required this.joinEpoch, required this.requestId, required this.tool, required  Map<String, Object?> args}): _args = args;
  factory _PushOpDto.fromJson(Map<String, dynamic> json) => _$PushOpDtoFromJson(json);

@override final  String opId;
@override final  String spaceId;
@override final  int joinEpoch;
@override final  String requestId;
@override final  String tool;
 final  Map<String, Object?> _args;
@override Map<String, Object?> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}


/// Create a copy of PushOpDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushOpDtoCopyWith<_PushOpDto> get copyWith => __$PushOpDtoCopyWithImpl<_PushOpDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushOpDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushOpDto&&(identical(other.opId, opId) || other.opId == opId)&&(identical(other.spaceId, spaceId) || other.spaceId == spaceId)&&(identical(other.joinEpoch, joinEpoch) || other.joinEpoch == joinEpoch)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.tool, tool) || other.tool == tool)&&const DeepCollectionEquality().equals(other.args, _args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,opId,spaceId,joinEpoch,requestId,tool,const DeepCollectionEquality().hash(_args));
}

@override
String toString() {
    return 'PushOpDto(opId: $opId, spaceId: $spaceId, joinEpoch: $joinEpoch, requestId: $requestId, tool: $tool, args: $args)';
}


}

/// @nodoc
abstract mixin class _$PushOpDtoCopyWith<$Res> implements $PushOpDtoCopyWith<$Res> {
  factory _$PushOpDtoCopyWith(_PushOpDto value, $Res Function(_PushOpDto) _then) = __$PushOpDtoCopyWithImpl;
@override @useResult
$Res call({
 String opId, String spaceId, int joinEpoch, String requestId, String tool, Map<String, Object?> args
});




}
/// @nodoc
class __$PushOpDtoCopyWithImpl<$Res>
    implements _$PushOpDtoCopyWith<$Res> {
  __$PushOpDtoCopyWithImpl(this._self, this._then);

  final _PushOpDto _self;
  final $Res Function(_PushOpDto) _then;

/// Create a copy of PushOpDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? opId = null,Object? spaceId = null,Object? joinEpoch = null,Object? requestId = null,Object? tool = null,Object? args = null,}) {
  return _then(_PushOpDto(
opId: null == opId ? _self.opId : opId // ignore: cast_nullable_to_non_nullable
as String,spaceId: null == spaceId ? _self.spaceId : spaceId // ignore: cast_nullable_to_non_nullable
as String,joinEpoch: null == joinEpoch ? _self.joinEpoch : joinEpoch // ignore: cast_nullable_to_non_nullable
as int,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$PushRequestDto {

 List<PushOpDto> get ops;
/// Create a copy of PushRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushRequestDtoCopyWith<PushRequestDto> get copyWith => _$PushRequestDtoCopyWithImpl<PushRequestDto>(this as PushRequestDto, _$identity);

  /// Serializes this PushRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PushRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushRequestDto&&const DeepCollectionEquality().equals(other.ops, _this.ops));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PushRequestDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.ops));
}

@override
String toString() {
  final _this = this as PushRequestDto;
  return 'PushRequestDto(ops: ${_this.ops})';
}


}

/// @nodoc
abstract mixin class $PushRequestDtoCopyWith<$Res>  {
  factory $PushRequestDtoCopyWith(PushRequestDto value, $Res Function(PushRequestDto) _then) = _$PushRequestDtoCopyWithImpl;
@useResult
$Res call({
 List<PushOpDto> ops
});




}
/// @nodoc
class _$PushRequestDtoCopyWithImpl<$Res>
    implements $PushRequestDtoCopyWith<$Res> {
  _$PushRequestDtoCopyWithImpl(this._self, this._then);

  final PushRequestDto _self;
  final $Res Function(PushRequestDto) _then;

/// Create a copy of PushRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ops = null,}) {
  return _then(PushRequestDto(
ops: null == ops ? _self.ops : ops // ignore: cast_nullable_to_non_nullable
as List<PushOpDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PushRequestDto].
extension PushRequestDtoPatterns on PushRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _PushRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _PushRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PushOpDto> ops)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushRequestDto() when $default != null:
return $default(_that.ops);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PushOpDto> ops)  $default,) {final _that = this;
switch (_that) {
case _PushRequestDto():
return $default(_that.ops);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PushOpDto> ops)?  $default,) {final _that = this;
switch (_that) {
case _PushRequestDto() when $default != null:
return $default(_that.ops);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushRequestDto implements PushRequestDto {
  const _PushRequestDto({required  List<PushOpDto> ops}): _ops = ops;
  factory _PushRequestDto.fromJson(Map<String, dynamic> json) => _$PushRequestDtoFromJson(json);

 final  List<PushOpDto> _ops;
@override List<PushOpDto> get ops {
  if (_ops is EqualUnmodifiableListView) return _ops;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ops);
}


/// Create a copy of PushRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushRequestDtoCopyWith<_PushRequestDto> get copyWith => __$PushRequestDtoCopyWithImpl<_PushRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushRequestDto&&const DeepCollectionEquality().equals(other.ops, _ops));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_ops));
}

@override
String toString() {
    return 'PushRequestDto(ops: $ops)';
}


}

/// @nodoc
abstract mixin class _$PushRequestDtoCopyWith<$Res> implements $PushRequestDtoCopyWith<$Res> {
  factory _$PushRequestDtoCopyWith(_PushRequestDto value, $Res Function(_PushRequestDto) _then) = __$PushRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PushOpDto> ops
});




}
/// @nodoc
class __$PushRequestDtoCopyWithImpl<$Res>
    implements _$PushRequestDtoCopyWith<$Res> {
  __$PushRequestDtoCopyWithImpl(this._self, this._then);

  final _PushRequestDto _self;
  final $Res Function(_PushRequestDto) _then;

/// Create a copy of PushRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ops = null,}) {
  return _then(_PushRequestDto(
ops: null == ops ? _self._ops : ops // ignore: cast_nullable_to_non_nullable
as List<PushOpDto>,
  ));
}


}


/// @nodoc
mixin _$PushResultDto {

 String get status;@JsonKey(includeIfNull: true) String? get opId; Map<String, Object?>? get result; ProblemDto? get problem;
/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushResultDtoCopyWith<PushResultDto> get copyWith => _$PushResultDtoCopyWithImpl<PushResultDto>(this as PushResultDto, _$identity);

  /// Serializes this PushResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PushResultDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushResultDto&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.opId, _this.opId) || other.opId == _this.opId)&&const DeepCollectionEquality().equals(other.result, _this.result)&&(identical(other.problem, _this.problem) || other.problem == _this.problem));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PushResultDto;
  return Object.hash(runtimeType,_this.status,_this.opId,const DeepCollectionEquality().hash(_this.result),_this.problem);
}

@override
String toString() {
  final _this = this as PushResultDto;
  return 'PushResultDto(status: ${_this.status}, opId: ${_this.opId}, result: ${_this.result}, problem: ${_this.problem})';
}


}

/// @nodoc
abstract mixin class $PushResultDtoCopyWith<$Res>  {
  factory $PushResultDtoCopyWith(PushResultDto value, $Res Function(PushResultDto) _then) = _$PushResultDtoCopyWithImpl;
@useResult
$Res call({
 String status,@JsonKey(includeIfNull: true) String? opId, Map<String, Object?>? result, ProblemDto? problem
});


$ProblemDtoCopyWith<$Res>? get problem;

}
/// @nodoc
class _$PushResultDtoCopyWithImpl<$Res>
    implements $PushResultDtoCopyWith<$Res> {
  _$PushResultDtoCopyWithImpl(this._self, this._then);

  final PushResultDto _self;
  final $Res Function(PushResultDto) _then;

/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? opId = freezed,Object? result = freezed,Object? problem = freezed,}) {
  return _then(PushResultDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,opId: freezed == opId ? _self.opId : opId // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as ProblemDto?,
  ));
}
/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProblemDtoCopyWith<$Res>? get problem {
    if (_self.problem == null) {
    return null;
  }

  return $ProblemDtoCopyWith<$Res>(_self.problem!, (value) {
    return _then(_self.copyWith(problem: value));
  });
}
}


/// Adds pattern-matching-related methods to [PushResultDto].
extension PushResultDtoPatterns on PushResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PushResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PushResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status, @JsonKey(includeIfNull: true)  String? opId,  Map<String, Object?>? result,  ProblemDto? problem)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushResultDto() when $default != null:
return $default(_that.status,_that.opId,_that.result,_that.problem);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status, @JsonKey(includeIfNull: true)  String? opId,  Map<String, Object?>? result,  ProblemDto? problem)  $default,) {final _that = this;
switch (_that) {
case _PushResultDto():
return $default(_that.status,_that.opId,_that.result,_that.problem);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status, @JsonKey(includeIfNull: true)  String? opId,  Map<String, Object?>? result,  ProblemDto? problem)?  $default,) {final _that = this;
switch (_that) {
case _PushResultDto() when $default != null:
return $default(_that.status,_that.opId,_that.result,_that.problem);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushResultDto implements PushResultDto {
  const _PushResultDto({required this.status, @JsonKey(includeIfNull: true) this.opId,  Map<String, Object?>? result, this.problem}): _result = result;
  factory _PushResultDto.fromJson(Map<String, dynamic> json) => _$PushResultDtoFromJson(json);

@override final  String status;
@override@JsonKey(includeIfNull: true) final  String? opId;
 final  Map<String, Object?>? _result;
@override Map<String, Object?>? get result {
  final value = _result;
  if (value == null) return null;
  if (_result is EqualUnmodifiableMapView) return _result;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  ProblemDto? problem;

/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushResultDtoCopyWith<_PushResultDto> get copyWith => __$PushResultDtoCopyWithImpl<_PushResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushResultDto&&(identical(other.status, status) || other.status == status)&&(identical(other.opId, opId) || other.opId == opId)&&const DeepCollectionEquality().equals(other.result, _result)&&(identical(other.problem, problem) || other.problem == problem));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,opId,const DeepCollectionEquality().hash(_result),problem);
}

@override
String toString() {
    return 'PushResultDto(status: $status, opId: $opId, result: $result, problem: $problem)';
}


}

/// @nodoc
abstract mixin class _$PushResultDtoCopyWith<$Res> implements $PushResultDtoCopyWith<$Res> {
  factory _$PushResultDtoCopyWith(_PushResultDto value, $Res Function(_PushResultDto) _then) = __$PushResultDtoCopyWithImpl;
@override @useResult
$Res call({
 String status,@JsonKey(includeIfNull: true) String? opId, Map<String, Object?>? result, ProblemDto? problem
});


@override $ProblemDtoCopyWith<$Res>? get problem;

}
/// @nodoc
class __$PushResultDtoCopyWithImpl<$Res>
    implements _$PushResultDtoCopyWith<$Res> {
  __$PushResultDtoCopyWithImpl(this._self, this._then);

  final _PushResultDto _self;
  final $Res Function(_PushResultDto) _then;

/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? opId = freezed,Object? result = freezed,Object? problem = freezed,}) {
  return _then(_PushResultDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,opId: freezed == opId ? _self.opId : opId // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self._result : result // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as ProblemDto?,
  ));
}

/// Create a copy of PushResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProblemDtoCopyWith<$Res>? get problem {
    if (_self.problem == null) {
    return null;
  }

  return $ProblemDtoCopyWith<$Res>(_self.problem!, (value) {
    return _then(_self.copyWith(problem: value));
  });
}
}


/// @nodoc
mixin _$PushResponseDto {

 List<PushResultDto> get results;
/// Create a copy of PushResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushResponseDtoCopyWith<PushResponseDto> get copyWith => _$PushResponseDtoCopyWithImpl<PushResponseDto>(this as PushResponseDto, _$identity);

  /// Serializes this PushResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PushResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushResponseDto&&const DeepCollectionEquality().equals(other.results, _this.results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PushResponseDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.results));
}

@override
String toString() {
  final _this = this as PushResponseDto;
  return 'PushResponseDto(results: ${_this.results})';
}


}

/// @nodoc
abstract mixin class $PushResponseDtoCopyWith<$Res>  {
  factory $PushResponseDtoCopyWith(PushResponseDto value, $Res Function(PushResponseDto) _then) = _$PushResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<PushResultDto> results
});




}
/// @nodoc
class _$PushResponseDtoCopyWithImpl<$Res>
    implements $PushResponseDtoCopyWith<$Res> {
  _$PushResponseDtoCopyWithImpl(this._self, this._then);

  final PushResponseDto _self;
  final $Res Function(PushResponseDto) _then;

/// Create a copy of PushResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? results = null,}) {
  return _then(PushResponseDto(
results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<PushResultDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PushResponseDto].
extension PushResponseDtoPatterns on PushResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _PushResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _PushResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PushResultDto> results)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushResponseDto() when $default != null:
return $default(_that.results);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PushResultDto> results)  $default,) {final _that = this;
switch (_that) {
case _PushResponseDto():
return $default(_that.results);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PushResultDto> results)?  $default,) {final _that = this;
switch (_that) {
case _PushResponseDto() when $default != null:
return $default(_that.results);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushResponseDto implements PushResponseDto {
  const _PushResponseDto({required  List<PushResultDto> results}): _results = results;
  factory _PushResponseDto.fromJson(Map<String, dynamic> json) => _$PushResponseDtoFromJson(json);

 final  List<PushResultDto> _results;
@override List<PushResultDto> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}


/// Create a copy of PushResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushResponseDtoCopyWith<_PushResponseDto> get copyWith => __$PushResponseDtoCopyWithImpl<_PushResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushResponseDto&&const DeepCollectionEquality().equals(other.results, _results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_results));
}

@override
String toString() {
    return 'PushResponseDto(results: $results)';
}


}

/// @nodoc
abstract mixin class _$PushResponseDtoCopyWith<$Res> implements $PushResponseDtoCopyWith<$Res> {
  factory _$PushResponseDtoCopyWith(_PushResponseDto value, $Res Function(_PushResponseDto) _then) = __$PushResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PushResultDto> results
});




}
/// @nodoc
class __$PushResponseDtoCopyWithImpl<$Res>
    implements _$PushResponseDtoCopyWith<$Res> {
  __$PushResponseDtoCopyWithImpl(this._self, this._then);

  final _PushResponseDto _self;
  final $Res Function(_PushResponseDto) _then;

/// Create a copy of PushResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? results = null,}) {
  return _then(_PushResponseDto(
results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<PushResultDto>,
  ));
}


}


/// @nodoc
mixin _$PullRequestDto {

 Map<String, int> get spaces; int get limit;
/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestDtoCopyWith<PullRequestDto> get copyWith => _$PullRequestDtoCopyWithImpl<PullRequestDto>(this as PullRequestDto, _$identity);

  /// Serializes this PullRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestDto&&const DeepCollectionEquality().equals(other.spaces, _this.spaces)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullRequestDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.spaces),_this.limit);
}

@override
String toString() {
  final _this = this as PullRequestDto;
  return 'PullRequestDto(spaces: ${_this.spaces}, limit: ${_this.limit})';
}


}

/// @nodoc
abstract mixin class $PullRequestDtoCopyWith<$Res>  {
  factory $PullRequestDtoCopyWith(PullRequestDto value, $Res Function(PullRequestDto) _then) = _$PullRequestDtoCopyWithImpl;
@useResult
$Res call({
 Map<String, int> spaces, int limit
});




}
/// @nodoc
class _$PullRequestDtoCopyWithImpl<$Res>
    implements $PullRequestDtoCopyWith<$Res> {
  _$PullRequestDtoCopyWithImpl(this._self, this._then);

  final PullRequestDto _self;
  final $Res Function(PullRequestDto) _then;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spaces = null,Object? limit = null,}) {
  return _then(PullRequestDto(
spaces: null == spaces ? _self.spaces : spaces // ignore: cast_nullable_to_non_nullable
as Map<String, int>,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PullRequestDto].
extension PullRequestDtoPatterns on PullRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _PullRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _PullRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, int> spaces,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullRequestDto() when $default != null:
return $default(_that.spaces,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, int> spaces,  int limit)  $default,) {final _that = this;
switch (_that) {
case _PullRequestDto():
return $default(_that.spaces,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, int> spaces,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _PullRequestDto() when $default != null:
return $default(_that.spaces,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullRequestDto implements PullRequestDto {
  const _PullRequestDto({required  Map<String, int> spaces, this.limit = 500}): _spaces = spaces;
  factory _PullRequestDto.fromJson(Map<String, dynamic> json) => _$PullRequestDtoFromJson(json);

 final  Map<String, int> _spaces;
@override Map<String, int> get spaces {
  if (_spaces is EqualUnmodifiableMapView) return _spaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_spaces);
}

@override@JsonKey() final  int limit;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestDtoCopyWith<_PullRequestDto> get copyWith => __$PullRequestDtoCopyWithImpl<_PullRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestDto&&const DeepCollectionEquality().equals(other.spaces, _spaces)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_spaces),limit);
}

@override
String toString() {
    return 'PullRequestDto(spaces: $spaces, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$PullRequestDtoCopyWith<$Res> implements $PullRequestDtoCopyWith<$Res> {
  factory _$PullRequestDtoCopyWith(_PullRequestDto value, $Res Function(_PullRequestDto) _then) = __$PullRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 Map<String, int> spaces, int limit
});




}
/// @nodoc
class __$PullRequestDtoCopyWithImpl<$Res>
    implements _$PullRequestDtoCopyWith<$Res> {
  __$PullRequestDtoCopyWithImpl(this._self, this._then);

  final _PullRequestDto _self;
  final $Res Function(_PullRequestDto) _then;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? spaces = null,Object? limit = null,}) {
  return _then(_PullRequestDto(
spaces: null == spaces ? _self._spaces : spaces // ignore: cast_nullable_to_non_nullable
as Map<String, int>,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ChangeDto {

 String get entity; Map<String, Object?> get data;
/// Create a copy of ChangeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeDtoCopyWith<ChangeDto> get copyWith => _$ChangeDtoCopyWithImpl<ChangeDto>(this as ChangeDto, _$identity);

  /// Serializes this ChangeDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChangeDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeDto&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChangeDto;
  return Object.hash(runtimeType,_this.entity,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as ChangeDto;
  return 'ChangeDto(entity: ${_this.entity}, data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $ChangeDtoCopyWith<$Res>  {
  factory $ChangeDtoCopyWith(ChangeDto value, $Res Function(ChangeDto) _then) = _$ChangeDtoCopyWithImpl;
@useResult
$Res call({
 String entity, Map<String, Object?> data
});




}
/// @nodoc
class _$ChangeDtoCopyWithImpl<$Res>
    implements $ChangeDtoCopyWith<$Res> {
  _$ChangeDtoCopyWithImpl(this._self, this._then);

  final ChangeDto _self;
  final $Res Function(ChangeDto) _then;

/// Create a copy of ChangeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entity = null,Object? data = null,}) {
  return _then(ChangeDto(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangeDto].
extension ChangeDtoPatterns on ChangeDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangeDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangeDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangeDto value)  $default,){
final _that = this;
switch (_that) {
case _ChangeDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangeDto value)?  $default,){
final _that = this;
switch (_that) {
case _ChangeDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String entity,  Map<String, Object?> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangeDto() when $default != null:
return $default(_that.entity,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String entity,  Map<String, Object?> data)  $default,) {final _that = this;
switch (_that) {
case _ChangeDto():
return $default(_that.entity,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String entity,  Map<String, Object?> data)?  $default,) {final _that = this;
switch (_that) {
case _ChangeDto() when $default != null:
return $default(_that.entity,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChangeDto implements ChangeDto {
  const _ChangeDto({required this.entity, required  Map<String, Object?> data}): _data = data;
  factory _ChangeDto.fromJson(Map<String, dynamic> json) => _$ChangeDtoFromJson(json);

@override final  String entity;
 final  Map<String, Object?> _data;
@override Map<String, Object?> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}


/// Create a copy of ChangeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangeDtoCopyWith<_ChangeDto> get copyWith => __$ChangeDtoCopyWithImpl<_ChangeDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangeDto&&(identical(other.entity, entity) || other.entity == entity)&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,entity,const DeepCollectionEquality().hash(_data));
}

@override
String toString() {
    return 'ChangeDto(entity: $entity, data: $data)';
}


}

/// @nodoc
abstract mixin class _$ChangeDtoCopyWith<$Res> implements $ChangeDtoCopyWith<$Res> {
  factory _$ChangeDtoCopyWith(_ChangeDto value, $Res Function(_ChangeDto) _then) = __$ChangeDtoCopyWithImpl;
@override @useResult
$Res call({
 String entity, Map<String, Object?> data
});




}
/// @nodoc
class __$ChangeDtoCopyWithImpl<$Res>
    implements _$ChangeDtoCopyWith<$Res> {
  __$ChangeDtoCopyWithImpl(this._self, this._then);

  final _ChangeDto _self;
  final $Res Function(_ChangeDto) _then;

/// Create a copy of ChangeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? data = null,}) {
  return _then(_ChangeDto(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$PullPageDto {

 String get spaceId; int get cursor; bool get hasMore; List<ChangeDto> get changes;
/// Create a copy of PullPageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullPageDtoCopyWith<PullPageDto> get copyWith => _$PullPageDtoCopyWithImpl<PullPageDto>(this as PullPageDto, _$identity);

  /// Serializes this PullPageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullPageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullPageDto&&(identical(other.spaceId, _this.spaceId) || other.spaceId == _this.spaceId)&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore)&&const DeepCollectionEquality().equals(other.changes, _this.changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullPageDto;
  return Object.hash(runtimeType,_this.spaceId,_this.cursor,_this.hasMore,const DeepCollectionEquality().hash(_this.changes));
}

@override
String toString() {
  final _this = this as PullPageDto;
  return 'PullPageDto(spaceId: ${_this.spaceId}, cursor: ${_this.cursor}, hasMore: ${_this.hasMore}, changes: ${_this.changes})';
}


}

/// @nodoc
abstract mixin class $PullPageDtoCopyWith<$Res>  {
  factory $PullPageDtoCopyWith(PullPageDto value, $Res Function(PullPageDto) _then) = _$PullPageDtoCopyWithImpl;
@useResult
$Res call({
 String spaceId, int cursor, bool hasMore, List<ChangeDto> changes
});




}
/// @nodoc
class _$PullPageDtoCopyWithImpl<$Res>
    implements $PullPageDtoCopyWith<$Res> {
  _$PullPageDtoCopyWithImpl(this._self, this._then);

  final PullPageDto _self;
  final $Res Function(PullPageDto) _then;

/// Create a copy of PullPageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spaceId = null,Object? cursor = null,Object? hasMore = null,Object? changes = null,}) {
  return _then(PullPageDto(
spaceId: null == spaceId ? _self.spaceId : spaceId // ignore: cast_nullable_to_non_nullable
as String,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<ChangeDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PullPageDto].
extension PullPageDtoPatterns on PullPageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullPageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullPageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullPageDto value)  $default,){
final _that = this;
switch (_that) {
case _PullPageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullPageDto value)?  $default,){
final _that = this;
switch (_that) {
case _PullPageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String spaceId,  int cursor,  bool hasMore,  List<ChangeDto> changes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullPageDto() when $default != null:
return $default(_that.spaceId,_that.cursor,_that.hasMore,_that.changes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String spaceId,  int cursor,  bool hasMore,  List<ChangeDto> changes)  $default,) {final _that = this;
switch (_that) {
case _PullPageDto():
return $default(_that.spaceId,_that.cursor,_that.hasMore,_that.changes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String spaceId,  int cursor,  bool hasMore,  List<ChangeDto> changes)?  $default,) {final _that = this;
switch (_that) {
case _PullPageDto() when $default != null:
return $default(_that.spaceId,_that.cursor,_that.hasMore,_that.changes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullPageDto implements PullPageDto {
  const _PullPageDto({required this.spaceId, required this.cursor, required this.hasMore, required  List<ChangeDto> changes}): _changes = changes;
  factory _PullPageDto.fromJson(Map<String, dynamic> json) => _$PullPageDtoFromJson(json);

@override final  String spaceId;
@override final  int cursor;
@override final  bool hasMore;
 final  List<ChangeDto> _changes;
@override List<ChangeDto> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}


/// Create a copy of PullPageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullPageDtoCopyWith<_PullPageDto> get copyWith => __$PullPageDtoCopyWithImpl<_PullPageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullPageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullPageDto&&(identical(other.spaceId, spaceId) || other.spaceId == spaceId)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&const DeepCollectionEquality().equals(other.changes, _changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,spaceId,cursor,hasMore,const DeepCollectionEquality().hash(_changes));
}

@override
String toString() {
    return 'PullPageDto(spaceId: $spaceId, cursor: $cursor, hasMore: $hasMore, changes: $changes)';
}


}

/// @nodoc
abstract mixin class _$PullPageDtoCopyWith<$Res> implements $PullPageDtoCopyWith<$Res> {
  factory _$PullPageDtoCopyWith(_PullPageDto value, $Res Function(_PullPageDto) _then) = __$PullPageDtoCopyWithImpl;
@override @useResult
$Res call({
 String spaceId, int cursor, bool hasMore, List<ChangeDto> changes
});




}
/// @nodoc
class __$PullPageDtoCopyWithImpl<$Res>
    implements _$PullPageDtoCopyWith<$Res> {
  __$PullPageDtoCopyWithImpl(this._self, this._then);

  final _PullPageDto _self;
  final $Res Function(_PullPageDto) _then;

/// Create a copy of PullPageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? spaceId = null,Object? cursor = null,Object? hasMore = null,Object? changes = null,}) {
  return _then(_PullPageDto(
spaceId: null == spaceId ? _self.spaceId : spaceId // ignore: cast_nullable_to_non_nullable
as String,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<ChangeDto>,
  ));
}


}


/// @nodoc
mixin _$PullResponseDto {

 List<PullPageDto> get spaces; List<String> get unavailable;
/// Create a copy of PullResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullResponseDtoCopyWith<PullResponseDto> get copyWith => _$PullResponseDtoCopyWithImpl<PullResponseDto>(this as PullResponseDto, _$identity);

  /// Serializes this PullResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullResponseDto&&const DeepCollectionEquality().equals(other.spaces, _this.spaces)&&const DeepCollectionEquality().equals(other.unavailable, _this.unavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullResponseDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.spaces),const DeepCollectionEquality().hash(_this.unavailable));
}

@override
String toString() {
  final _this = this as PullResponseDto;
  return 'PullResponseDto(spaces: ${_this.spaces}, unavailable: ${_this.unavailable})';
}


}

/// @nodoc
abstract mixin class $PullResponseDtoCopyWith<$Res>  {
  factory $PullResponseDtoCopyWith(PullResponseDto value, $Res Function(PullResponseDto) _then) = _$PullResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<PullPageDto> spaces, List<String> unavailable
});




}
/// @nodoc
class _$PullResponseDtoCopyWithImpl<$Res>
    implements $PullResponseDtoCopyWith<$Res> {
  _$PullResponseDtoCopyWithImpl(this._self, this._then);

  final PullResponseDto _self;
  final $Res Function(PullResponseDto) _then;

/// Create a copy of PullResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spaces = null,Object? unavailable = null,}) {
  return _then(PullResponseDto(
spaces: null == spaces ? _self.spaces : spaces // ignore: cast_nullable_to_non_nullable
as List<PullPageDto>,unavailable: null == unavailable ? _self.unavailable : unavailable // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PullResponseDto].
extension PullResponseDtoPatterns on PullResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _PullResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _PullResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PullPageDto> spaces,  List<String> unavailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullResponseDto() when $default != null:
return $default(_that.spaces,_that.unavailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PullPageDto> spaces,  List<String> unavailable)  $default,) {final _that = this;
switch (_that) {
case _PullResponseDto():
return $default(_that.spaces,_that.unavailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PullPageDto> spaces,  List<String> unavailable)?  $default,) {final _that = this;
switch (_that) {
case _PullResponseDto() when $default != null:
return $default(_that.spaces,_that.unavailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullResponseDto implements PullResponseDto {
  const _PullResponseDto({required  List<PullPageDto> spaces, required  List<String> unavailable}): _spaces = spaces,_unavailable = unavailable;
  factory _PullResponseDto.fromJson(Map<String, dynamic> json) => _$PullResponseDtoFromJson(json);

 final  List<PullPageDto> _spaces;
@override List<PullPageDto> get spaces {
  if (_spaces is EqualUnmodifiableListView) return _spaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spaces);
}

 final  List<String> _unavailable;
@override List<String> get unavailable {
  if (_unavailable is EqualUnmodifiableListView) return _unavailable;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_unavailable);
}


/// Create a copy of PullResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullResponseDtoCopyWith<_PullResponseDto> get copyWith => __$PullResponseDtoCopyWithImpl<_PullResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullResponseDto&&const DeepCollectionEquality().equals(other.spaces, _spaces)&&const DeepCollectionEquality().equals(other.unavailable, _unavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_spaces),const DeepCollectionEquality().hash(_unavailable));
}

@override
String toString() {
    return 'PullResponseDto(spaces: $spaces, unavailable: $unavailable)';
}


}

/// @nodoc
abstract mixin class _$PullResponseDtoCopyWith<$Res> implements $PullResponseDtoCopyWith<$Res> {
  factory _$PullResponseDtoCopyWith(_PullResponseDto value, $Res Function(_PullResponseDto) _then) = __$PullResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PullPageDto> spaces, List<String> unavailable
});




}
/// @nodoc
class __$PullResponseDtoCopyWithImpl<$Res>
    implements _$PullResponseDtoCopyWith<$Res> {
  __$PullResponseDtoCopyWithImpl(this._self, this._then);

  final _PullResponseDto _self;
  final $Res Function(_PullResponseDto) _then;

/// Create a copy of PullResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? spaces = null,Object? unavailable = null,}) {
  return _then(_PullResponseDto(
spaces: null == spaces ? _self._spaces : spaces // ignore: cast_nullable_to_non_nullable
as List<PullPageDto>,unavailable: null == unavailable ? _self._unavailable : unavailable // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
