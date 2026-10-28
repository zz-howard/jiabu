// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ledger_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LedgerUiState {

 LedgerSnapshot? get snapshot; HistoryFilter get filter; bool get busy; String? get error;
/// Create a copy of LedgerUiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LedgerUiStateCopyWith<LedgerUiState> get copyWith => _$LedgerUiStateCopyWithImpl<LedgerUiState>(this as LedgerUiState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LedgerUiState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LedgerUiState&&(identical(other.snapshot, _this.snapshot) || other.snapshot == _this.snapshot)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as LedgerUiState;
  return Object.hash(runtimeType,_this.snapshot,_this.filter,_this.busy,_this.error);
}

@override
String toString() {
  final _this = this as LedgerUiState;
  return 'LedgerUiState(snapshot: ${_this.snapshot}, filter: ${_this.filter}, busy: ${_this.busy}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $LedgerUiStateCopyWith<$Res>  {
  factory $LedgerUiStateCopyWith(LedgerUiState value, $Res Function(LedgerUiState) _then) = _$LedgerUiStateCopyWithImpl;
@useResult
$Res call({
 LedgerSnapshot? snapshot, HistoryFilter filter, bool busy, String? error
});




}
/// @nodoc
class _$LedgerUiStateCopyWithImpl<$Res>
    implements $LedgerUiStateCopyWith<$Res> {
  _$LedgerUiStateCopyWithImpl(this._self, this._then);

  final LedgerUiState _self;
  final $Res Function(LedgerUiState) _then;

/// Create a copy of LedgerUiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snapshot = freezed,Object? filter = null,Object? busy = null,Object? error = freezed,}) {
  return _then(LedgerUiState(
snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as LedgerSnapshot?,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as HistoryFilter,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LedgerUiState].
extension LedgerUiStatePatterns on LedgerUiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LedgerUiState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LedgerUiState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LedgerUiState value)  $default,){
final _that = this;
switch (_that) {
case _LedgerUiState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LedgerUiState value)?  $default,){
final _that = this;
switch (_that) {
case _LedgerUiState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LedgerSnapshot? snapshot,  HistoryFilter filter,  bool busy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LedgerUiState() when $default != null:
return $default(_that.snapshot,_that.filter,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LedgerSnapshot? snapshot,  HistoryFilter filter,  bool busy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _LedgerUiState():
return $default(_that.snapshot,_that.filter,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LedgerSnapshot? snapshot,  HistoryFilter filter,  bool busy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _LedgerUiState() when $default != null:
return $default(_that.snapshot,_that.filter,_that.busy,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _LedgerUiState implements LedgerUiState {
  const _LedgerUiState({this.snapshot, this.filter = const HistoryFilter(), this.busy = false, this.error});
  

@override final  LedgerSnapshot? snapshot;
@override@JsonKey() final  HistoryFilter filter;
@override@JsonKey() final  bool busy;
@override final  String? error;

/// Create a copy of LedgerUiState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LedgerUiStateCopyWith<_LedgerUiState> get copyWith => __$LedgerUiStateCopyWithImpl<_LedgerUiState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LedgerUiState&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,snapshot,filter,busy,error);
}

@override
String toString() {
    return 'LedgerUiState(snapshot: $snapshot, filter: $filter, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$LedgerUiStateCopyWith<$Res> implements $LedgerUiStateCopyWith<$Res> {
  factory _$LedgerUiStateCopyWith(_LedgerUiState value, $Res Function(_LedgerUiState) _then) = __$LedgerUiStateCopyWithImpl;
@override @useResult
$Res call({
 LedgerSnapshot? snapshot, HistoryFilter filter, bool busy, String? error
});




}
/// @nodoc
class __$LedgerUiStateCopyWithImpl<$Res>
    implements _$LedgerUiStateCopyWith<$Res> {
  __$LedgerUiStateCopyWithImpl(this._self, this._then);

  final _LedgerUiState _self;
  final $Res Function(_LedgerUiState) _then;

/// Create a copy of LedgerUiState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snapshot = freezed,Object? filter = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_LedgerUiState(
snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as LedgerSnapshot?,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as HistoryFilter,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$LedgerFormState {

 Map<String, Object?> get values; bool get busy; String? get error;
/// Create a copy of LedgerFormState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LedgerFormStateCopyWith<LedgerFormState> get copyWith => _$LedgerFormStateCopyWithImpl<LedgerFormState>(this as LedgerFormState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LedgerFormState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LedgerFormState&&const DeepCollectionEquality().equals(other.values, _this.values)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as LedgerFormState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.values),_this.busy,_this.error);
}

@override
String toString() {
  final _this = this as LedgerFormState;
  return 'LedgerFormState(values: ${_this.values}, busy: ${_this.busy}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $LedgerFormStateCopyWith<$Res>  {
  factory $LedgerFormStateCopyWith(LedgerFormState value, $Res Function(LedgerFormState) _then) = _$LedgerFormStateCopyWithImpl;
@useResult
$Res call({
 Map<String, Object?> values, bool busy, String? error
});




}
/// @nodoc
class _$LedgerFormStateCopyWithImpl<$Res>
    implements $LedgerFormStateCopyWith<$Res> {
  _$LedgerFormStateCopyWithImpl(this._self, this._then);

  final LedgerFormState _self;
  final $Res Function(LedgerFormState) _then;

/// Create a copy of LedgerFormState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? values = null,Object? busy = null,Object? error = freezed,}) {
  return _then(LedgerFormState(
values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LedgerFormState].
extension LedgerFormStatePatterns on LedgerFormState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LedgerFormState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LedgerFormState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LedgerFormState value)  $default,){
final _that = this;
switch (_that) {
case _LedgerFormState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LedgerFormState value)?  $default,){
final _that = this;
switch (_that) {
case _LedgerFormState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, Object?> values,  bool busy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LedgerFormState() when $default != null:
return $default(_that.values,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, Object?> values,  bool busy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _LedgerFormState():
return $default(_that.values,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, Object?> values,  bool busy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _LedgerFormState() when $default != null:
return $default(_that.values,_that.busy,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _LedgerFormState implements LedgerFormState {
  const _LedgerFormState({ Map<String, Object?> values = const <String, Object?>{}, this.busy = false, this.error}): _values = values;
  

 final  Map<String, Object?> _values;
@override@JsonKey() Map<String, Object?> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

@override@JsonKey() final  bool busy;
@override final  String? error;

/// Create a copy of LedgerFormState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LedgerFormStateCopyWith<_LedgerFormState> get copyWith => __$LedgerFormStateCopyWithImpl<_LedgerFormState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LedgerFormState&&const DeepCollectionEquality().equals(other.values, _values)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_values),busy,error);
}

@override
String toString() {
    return 'LedgerFormState(values: $values, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$LedgerFormStateCopyWith<$Res> implements $LedgerFormStateCopyWith<$Res> {
  factory _$LedgerFormStateCopyWith(_LedgerFormState value, $Res Function(_LedgerFormState) _then) = __$LedgerFormStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, Object?> values, bool busy, String? error
});




}
/// @nodoc
class __$LedgerFormStateCopyWithImpl<$Res>
    implements _$LedgerFormStateCopyWith<$Res> {
  __$LedgerFormStateCopyWithImpl(this._self, this._then);

  final _LedgerFormState _self;
  final $Res Function(_LedgerFormState) _then;

/// Create a copy of LedgerFormState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? values = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_LedgerFormState(
values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
