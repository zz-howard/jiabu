// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatUiState {

 ChatConversation? get conversation; bool get busy; String get draft; List<String> get images; int get revision; Set<String> get stopping; String? get error;
/// Create a copy of ChatUiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatUiStateCopyWith<ChatUiState> get copyWith => _$ChatUiStateCopyWithImpl<ChatUiState>(this as ChatUiState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChatUiState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatUiState&&(identical(other.conversation, _this.conversation) || other.conversation == _this.conversation)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&const DeepCollectionEquality().equals(other.images, _this.images)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.stopping, _this.stopping)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as ChatUiState;
  return Object.hash(runtimeType,_this.conversation,_this.busy,_this.draft,const DeepCollectionEquality().hash(_this.images),_this.revision,const DeepCollectionEquality().hash(_this.stopping),_this.error);
}

@override
String toString() {
  final _this = this as ChatUiState;
  return 'ChatUiState(conversation: ${_this.conversation}, busy: ${_this.busy}, draft: ${_this.draft}, images: ${_this.images}, revision: ${_this.revision}, stopping: ${_this.stopping}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $ChatUiStateCopyWith<$Res>  {
  factory $ChatUiStateCopyWith(ChatUiState value, $Res Function(ChatUiState) _then) = _$ChatUiStateCopyWithImpl;
@useResult
$Res call({
 ChatConversation? conversation, bool busy, String draft, List<String> images, int revision, Set<String> stopping, String? error
});




}
/// @nodoc
class _$ChatUiStateCopyWithImpl<$Res>
    implements $ChatUiStateCopyWith<$Res> {
  _$ChatUiStateCopyWithImpl(this._self, this._then);

  final ChatUiState _self;
  final $Res Function(ChatUiState) _then;

/// Create a copy of ChatUiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? conversation = freezed,Object? busy = null,Object? draft = null,Object? images = null,Object? revision = null,Object? stopping = null,Object? error = freezed,}) {
  return _then(ChatUiState(
conversation: freezed == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as ChatConversation?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<String>,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,stopping: null == stopping ? _self.stopping : stopping // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatUiState].
extension ChatUiStatePatterns on ChatUiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatUiState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatUiState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatUiState value)  $default,){
final _that = this;
switch (_that) {
case _ChatUiState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatUiState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatUiState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatConversation? conversation,  bool busy,  String draft,  List<String> images,  int revision,  Set<String> stopping,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatUiState() when $default != null:
return $default(_that.conversation,_that.busy,_that.draft,_that.images,_that.revision,_that.stopping,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatConversation? conversation,  bool busy,  String draft,  List<String> images,  int revision,  Set<String> stopping,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ChatUiState():
return $default(_that.conversation,_that.busy,_that.draft,_that.images,_that.revision,_that.stopping,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatConversation? conversation,  bool busy,  String draft,  List<String> images,  int revision,  Set<String> stopping,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ChatUiState() when $default != null:
return $default(_that.conversation,_that.busy,_that.draft,_that.images,_that.revision,_that.stopping,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ChatUiState implements ChatUiState {
  const _ChatUiState({this.conversation, this.busy = false, this.draft = '',  List<String> images = const <String>[], this.revision = 0,  Set<String> stopping = const <String>{}, this.error}): _images = images,_stopping = stopping;
  

@override final  ChatConversation? conversation;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  String draft;
 final  List<String> _images;
@override@JsonKey() List<String> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

@override@JsonKey() final  int revision;
 final  Set<String> _stopping;
@override@JsonKey() Set<String> get stopping {
  if (_stopping is EqualUnmodifiableSetView) return _stopping;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_stopping);
}

@override final  String? error;

/// Create a copy of ChatUiState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatUiStateCopyWith<_ChatUiState> get copyWith => __$ChatUiStateCopyWithImpl<_ChatUiState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatUiState&&(identical(other.conversation, conversation) || other.conversation == conversation)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.draft, draft) || other.draft == draft)&&const DeepCollectionEquality().equals(other.images, _images)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.stopping, _stopping)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,conversation,busy,draft,const DeepCollectionEquality().hash(_images),revision,const DeepCollectionEquality().hash(_stopping),error);
}

@override
String toString() {
    return 'ChatUiState(conversation: $conversation, busy: $busy, draft: $draft, images: $images, revision: $revision, stopping: $stopping, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ChatUiStateCopyWith<$Res> implements $ChatUiStateCopyWith<$Res> {
  factory _$ChatUiStateCopyWith(_ChatUiState value, $Res Function(_ChatUiState) _then) = __$ChatUiStateCopyWithImpl;
@override @useResult
$Res call({
 ChatConversation? conversation, bool busy, String draft, List<String> images, int revision, Set<String> stopping, String? error
});




}
/// @nodoc
class __$ChatUiStateCopyWithImpl<$Res>
    implements _$ChatUiStateCopyWith<$Res> {
  __$ChatUiStateCopyWithImpl(this._self, this._then);

  final _ChatUiState _self;
  final $Res Function(_ChatUiState) _then;

/// Create a copy of ChatUiState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? conversation = freezed,Object? busy = null,Object? draft = null,Object? images = null,Object? revision = null,Object? stopping = null,Object? error = freezed,}) {
  return _then(_ChatUiState(
conversation: freezed == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as ChatConversation?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<String>,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,stopping: null == stopping ? _self._stopping : stopping // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
