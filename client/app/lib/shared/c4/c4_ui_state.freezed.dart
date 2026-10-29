// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'c4_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$C4UiState {

 bool get busy; bool get online; bool get copied; int get revision; Map<String, Object?> get values; List<Map<String, Object?>> get rows; String? get error;
/// Create a copy of C4UiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$C4UiStateCopyWith<C4UiState> get copyWith => _$C4UiStateCopyWithImpl<C4UiState>(this as C4UiState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as C4UiState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is C4UiState&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.online, _this.online) || other.online == _this.online)&&(identical(other.copied, _this.copied) || other.copied == _this.copied)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.values, _this.values)&&const DeepCollectionEquality().equals(other.rows, _this.rows)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as C4UiState;
  return Object.hash(runtimeType,_this.busy,_this.online,_this.copied,_this.revision,const DeepCollectionEquality().hash(_this.values),const DeepCollectionEquality().hash(_this.rows),_this.error);
}

@override
String toString() {
  final _this = this as C4UiState;
  return 'C4UiState(busy: ${_this.busy}, online: ${_this.online}, copied: ${_this.copied}, revision: ${_this.revision}, values: ${_this.values}, rows: ${_this.rows}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $C4UiStateCopyWith<$Res>  {
  factory $C4UiStateCopyWith(C4UiState value, $Res Function(C4UiState) _then) = _$C4UiStateCopyWithImpl;
@useResult
$Res call({
 bool busy, bool online, bool copied, int revision, Map<String, Object?> values, List<Map<String, Object?>> rows, String? error
});




}
/// @nodoc
class _$C4UiStateCopyWithImpl<$Res>
    implements $C4UiStateCopyWith<$Res> {
  _$C4UiStateCopyWithImpl(this._self, this._then);

  final C4UiState _self;
  final $Res Function(C4UiState) _then;

/// Create a copy of C4UiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? busy = null,Object? online = null,Object? copied = null,Object? revision = null,Object? values = null,Object? rows = null,Object? error = freezed,}) {
  return _then(C4UiState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,copied: null == copied ? _self.copied : copied // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [C4UiState].
extension C4UiStatePatterns on C4UiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _C4UiState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _C4UiState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _C4UiState value)  $default,){
final _that = this;
switch (_that) {
case _C4UiState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _C4UiState value)?  $default,){
final _that = this;
switch (_that) {
case _C4UiState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool busy,  bool online,  bool copied,  int revision,  Map<String, Object?> values,  List<Map<String, Object?>> rows,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _C4UiState() when $default != null:
return $default(_that.busy,_that.online,_that.copied,_that.revision,_that.values,_that.rows,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool busy,  bool online,  bool copied,  int revision,  Map<String, Object?> values,  List<Map<String, Object?>> rows,  String? error)  $default,) {final _that = this;
switch (_that) {
case _C4UiState():
return $default(_that.busy,_that.online,_that.copied,_that.revision,_that.values,_that.rows,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool busy,  bool online,  bool copied,  int revision,  Map<String, Object?> values,  List<Map<String, Object?>> rows,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _C4UiState() when $default != null:
return $default(_that.busy,_that.online,_that.copied,_that.revision,_that.values,_that.rows,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _C4UiState implements C4UiState {
  const _C4UiState({this.busy = false, this.online = false, this.copied = false, this.revision = 0,  Map<String, Object?> values = const <String, Object?>{},  List<Map<String, Object?>> rows = const <Map<String, Object?>>[], this.error}): _values = values,_rows = rows;
  

@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool online;
@override@JsonKey() final  bool copied;
@override@JsonKey() final  int revision;
 final  Map<String, Object?> _values;
@override@JsonKey() Map<String, Object?> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

 final  List<Map<String, Object?>> _rows;
@override@JsonKey() List<Map<String, Object?>> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override final  String? error;

/// Create a copy of C4UiState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$C4UiStateCopyWith<_C4UiState> get copyWith => __$C4UiStateCopyWithImpl<_C4UiState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _C4UiState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.online, online) || other.online == online)&&(identical(other.copied, copied) || other.copied == copied)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.values, _values)&&const DeepCollectionEquality().equals(other.rows, _rows)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,busy,online,copied,revision,const DeepCollectionEquality().hash(_values),const DeepCollectionEquality().hash(_rows),error);
}

@override
String toString() {
    return 'C4UiState(busy: $busy, online: $online, copied: $copied, revision: $revision, values: $values, rows: $rows, error: $error)';
}


}

/// @nodoc
abstract mixin class _$C4UiStateCopyWith<$Res> implements $C4UiStateCopyWith<$Res> {
  factory _$C4UiStateCopyWith(_C4UiState value, $Res Function(_C4UiState) _then) = __$C4UiStateCopyWithImpl;
@override @useResult
$Res call({
 bool busy, bool online, bool copied, int revision, Map<String, Object?> values, List<Map<String, Object?>> rows, String? error
});




}
/// @nodoc
class __$C4UiStateCopyWithImpl<$Res>
    implements _$C4UiStateCopyWith<$Res> {
  __$C4UiStateCopyWithImpl(this._self, this._then);

  final _C4UiState _self;
  final $Res Function(_C4UiState) _then;

/// Create a copy of C4UiState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? online = null,Object? copied = null,Object? revision = null,Object? values = null,Object? rows = null,Object? error = freezed,}) {
  return _then(_C4UiState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,copied: null == copied ? _self.copied : copied // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
