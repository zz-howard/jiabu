// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UpdateUiState {

 ReleaseInfo? get release; bool get bannerVisible; bool get clientTooOld; bool get sheetOpen; UpdatePhase get phase; int get received; int get total; UpdateFailure? get failure;
/// Create a copy of UpdateUiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateUiStateCopyWith<UpdateUiState> get copyWith => _$UpdateUiStateCopyWithImpl<UpdateUiState>(this as UpdateUiState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UpdateUiState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateUiState&&(identical(other.release, _this.release) || other.release == _this.release)&&(identical(other.bannerVisible, _this.bannerVisible) || other.bannerVisible == _this.bannerVisible)&&(identical(other.clientTooOld, _this.clientTooOld) || other.clientTooOld == _this.clientTooOld)&&(identical(other.sheetOpen, _this.sheetOpen) || other.sheetOpen == _this.sheetOpen)&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.received, _this.received) || other.received == _this.received)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as UpdateUiState;
  return Object.hash(runtimeType,_this.release,_this.bannerVisible,_this.clientTooOld,_this.sheetOpen,_this.phase,_this.received,_this.total,_this.failure);
}

@override
String toString() {
  final _this = this as UpdateUiState;
  return 'UpdateUiState(release: ${_this.release}, bannerVisible: ${_this.bannerVisible}, clientTooOld: ${_this.clientTooOld}, sheetOpen: ${_this.sheetOpen}, phase: ${_this.phase}, received: ${_this.received}, total: ${_this.total}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $UpdateUiStateCopyWith<$Res>  {
  factory $UpdateUiStateCopyWith(UpdateUiState value, $Res Function(UpdateUiState) _then) = _$UpdateUiStateCopyWithImpl;
@useResult
$Res call({
 ReleaseInfo? release, bool bannerVisible, bool clientTooOld, bool sheetOpen, UpdatePhase phase, int received, int total, UpdateFailure? failure
});




}
/// @nodoc
class _$UpdateUiStateCopyWithImpl<$Res>
    implements $UpdateUiStateCopyWith<$Res> {
  _$UpdateUiStateCopyWithImpl(this._self, this._then);

  final UpdateUiState _self;
  final $Res Function(UpdateUiState) _then;

/// Create a copy of UpdateUiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? release = freezed,Object? bannerVisible = null,Object? clientTooOld = null,Object? sheetOpen = null,Object? phase = null,Object? received = null,Object? total = null,Object? failure = freezed,}) {
  return _then(UpdateUiState(
release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as ReleaseInfo?,bannerVisible: null == bannerVisible ? _self.bannerVisible : bannerVisible // ignore: cast_nullable_to_non_nullable
as bool,clientTooOld: null == clientTooOld ? _self.clientTooOld : clientTooOld // ignore: cast_nullable_to_non_nullable
as bool,sheetOpen: null == sheetOpen ? _self.sheetOpen : sheetOpen // ignore: cast_nullable_to_non_nullable
as bool,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as UpdatePhase,received: null == received ? _self.received : received // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as UpdateFailure?,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateUiState].
extension UpdateUiStatePatterns on UpdateUiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateUiState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateUiState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateUiState value)  $default,){
final _that = this;
switch (_that) {
case _UpdateUiState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateUiState value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateUiState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReleaseInfo? release,  bool bannerVisible,  bool clientTooOld,  bool sheetOpen,  UpdatePhase phase,  int received,  int total,  UpdateFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateUiState() when $default != null:
return $default(_that.release,_that.bannerVisible,_that.clientTooOld,_that.sheetOpen,_that.phase,_that.received,_that.total,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReleaseInfo? release,  bool bannerVisible,  bool clientTooOld,  bool sheetOpen,  UpdatePhase phase,  int received,  int total,  UpdateFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _UpdateUiState():
return $default(_that.release,_that.bannerVisible,_that.clientTooOld,_that.sheetOpen,_that.phase,_that.received,_that.total,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReleaseInfo? release,  bool bannerVisible,  bool clientTooOld,  bool sheetOpen,  UpdatePhase phase,  int received,  int total,  UpdateFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _UpdateUiState() when $default != null:
return $default(_that.release,_that.bannerVisible,_that.clientTooOld,_that.sheetOpen,_that.phase,_that.received,_that.total,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _UpdateUiState implements UpdateUiState {
  const _UpdateUiState({this.release, this.bannerVisible = false, this.clientTooOld = false, this.sheetOpen = false, this.phase = UpdatePhase.available, this.received = 0, this.total = 0, this.failure});
  

@override final  ReleaseInfo? release;
@override@JsonKey() final  bool bannerVisible;
@override@JsonKey() final  bool clientTooOld;
@override@JsonKey() final  bool sheetOpen;
@override@JsonKey() final  UpdatePhase phase;
@override@JsonKey() final  int received;
@override@JsonKey() final  int total;
@override final  UpdateFailure? failure;

/// Create a copy of UpdateUiState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateUiStateCopyWith<_UpdateUiState> get copyWith => __$UpdateUiStateCopyWithImpl<_UpdateUiState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateUiState&&(identical(other.release, release) || other.release == release)&&(identical(other.bannerVisible, bannerVisible) || other.bannerVisible == bannerVisible)&&(identical(other.clientTooOld, clientTooOld) || other.clientTooOld == clientTooOld)&&(identical(other.sheetOpen, sheetOpen) || other.sheetOpen == sheetOpen)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.received, received) || other.received == received)&&(identical(other.total, total) || other.total == total)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,release,bannerVisible,clientTooOld,sheetOpen,phase,received,total,failure);
}

@override
String toString() {
    return 'UpdateUiState(release: $release, bannerVisible: $bannerVisible, clientTooOld: $clientTooOld, sheetOpen: $sheetOpen, phase: $phase, received: $received, total: $total, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$UpdateUiStateCopyWith<$Res> implements $UpdateUiStateCopyWith<$Res> {
  factory _$UpdateUiStateCopyWith(_UpdateUiState value, $Res Function(_UpdateUiState) _then) = __$UpdateUiStateCopyWithImpl;
@override @useResult
$Res call({
 ReleaseInfo? release, bool bannerVisible, bool clientTooOld, bool sheetOpen, UpdatePhase phase, int received, int total, UpdateFailure? failure
});




}
/// @nodoc
class __$UpdateUiStateCopyWithImpl<$Res>
    implements _$UpdateUiStateCopyWith<$Res> {
  __$UpdateUiStateCopyWithImpl(this._self, this._then);

  final _UpdateUiState _self;
  final $Res Function(_UpdateUiState) _then;

/// Create a copy of UpdateUiState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? release = freezed,Object? bannerVisible = null,Object? clientTooOld = null,Object? sheetOpen = null,Object? phase = null,Object? received = null,Object? total = null,Object? failure = freezed,}) {
  return _then(_UpdateUiState(
release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as ReleaseInfo?,bannerVisible: null == bannerVisible ? _self.bannerVisible : bannerVisible // ignore: cast_nullable_to_non_nullable
as bool,clientTooOld: null == clientTooOld ? _self.clientTooOld : clientTooOld // ignore: cast_nullable_to_non_nullable
as bool,sheetOpen: null == sheetOpen ? _self.sheetOpen : sheetOpen // ignore: cast_nullable_to_non_nullable
as bool,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as UpdatePhase,received: null == received ? _self.received : received // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as UpdateFailure?,
  ));
}


}

// dart format on
