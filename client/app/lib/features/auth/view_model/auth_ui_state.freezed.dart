// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthUiState {

 AuthPage get page; bool get busy; bool get authenticated; bool get forcedPassword; String get server; String get defaultServer; List<String> get servers; bool get serverProbeSucceeded; String? get errorCode; DateTime? get adminResetAt; int? get switchCount; int get partitionRevision; SyncStatus get syncStatus; bool get spaceCleared; int get clearedCount;
/// Create a copy of AuthUiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthUiStateCopyWith<AuthUiState> get copyWith => _$AuthUiStateCopyWithImpl<AuthUiState>(this as AuthUiState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AuthUiState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUiState&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.authenticated, _this.authenticated) || other.authenticated == _this.authenticated)&&(identical(other.forcedPassword, _this.forcedPassword) || other.forcedPassword == _this.forcedPassword)&&(identical(other.server, _this.server) || other.server == _this.server)&&(identical(other.defaultServer, _this.defaultServer) || other.defaultServer == _this.defaultServer)&&const DeepCollectionEquality().equals(other.servers, _this.servers)&&(identical(other.serverProbeSucceeded, _this.serverProbeSucceeded) || other.serverProbeSucceeded == _this.serverProbeSucceeded)&&(identical(other.errorCode, _this.errorCode) || other.errorCode == _this.errorCode)&&(identical(other.adminResetAt, _this.adminResetAt) || other.adminResetAt == _this.adminResetAt)&&(identical(other.switchCount, _this.switchCount) || other.switchCount == _this.switchCount)&&(identical(other.partitionRevision, _this.partitionRevision) || other.partitionRevision == _this.partitionRevision)&&(identical(other.syncStatus, _this.syncStatus) || other.syncStatus == _this.syncStatus)&&(identical(other.spaceCleared, _this.spaceCleared) || other.spaceCleared == _this.spaceCleared)&&(identical(other.clearedCount, _this.clearedCount) || other.clearedCount == _this.clearedCount));
}


@override
int get hashCode {
  final _this = this as AuthUiState;
  return Object.hash(runtimeType,_this.page,_this.busy,_this.authenticated,_this.forcedPassword,_this.server,_this.defaultServer,const DeepCollectionEquality().hash(_this.servers),_this.serverProbeSucceeded,_this.errorCode,_this.adminResetAt,_this.switchCount,_this.partitionRevision,_this.syncStatus,_this.spaceCleared,_this.clearedCount);
}

@override
String toString() {
  final _this = this as AuthUiState;
  return 'AuthUiState(page: ${_this.page}, busy: ${_this.busy}, authenticated: ${_this.authenticated}, forcedPassword: ${_this.forcedPassword}, server: ${_this.server}, defaultServer: ${_this.defaultServer}, servers: ${_this.servers}, serverProbeSucceeded: ${_this.serverProbeSucceeded}, errorCode: ${_this.errorCode}, adminResetAt: ${_this.adminResetAt}, switchCount: ${_this.switchCount}, partitionRevision: ${_this.partitionRevision}, syncStatus: ${_this.syncStatus}, spaceCleared: ${_this.spaceCleared}, clearedCount: ${_this.clearedCount})';
}


}

/// @nodoc
abstract mixin class $AuthUiStateCopyWith<$Res>  {
  factory $AuthUiStateCopyWith(AuthUiState value, $Res Function(AuthUiState) _then) = _$AuthUiStateCopyWithImpl;
@useResult
$Res call({
 AuthPage page, bool busy, bool authenticated, bool forcedPassword, String server, String defaultServer, List<String> servers, bool serverProbeSucceeded, String? errorCode, DateTime? adminResetAt, int? switchCount, int partitionRevision, SyncStatus syncStatus, bool spaceCleared, int clearedCount
});




}
/// @nodoc
class _$AuthUiStateCopyWithImpl<$Res>
    implements $AuthUiStateCopyWith<$Res> {
  _$AuthUiStateCopyWithImpl(this._self, this._then);

  final AuthUiState _self;
  final $Res Function(AuthUiState) _then;

/// Create a copy of AuthUiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? page = null,Object? busy = null,Object? authenticated = null,Object? forcedPassword = null,Object? server = null,Object? defaultServer = null,Object? servers = null,Object? serverProbeSucceeded = null,Object? errorCode = freezed,Object? adminResetAt = freezed,Object? switchCount = freezed,Object? partitionRevision = null,Object? syncStatus = null,Object? spaceCleared = null,Object? clearedCount = null,}) {
  return _then(AuthUiState(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as AuthPage,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,authenticated: null == authenticated ? _self.authenticated : authenticated // ignore: cast_nullable_to_non_nullable
as bool,forcedPassword: null == forcedPassword ? _self.forcedPassword : forcedPassword // ignore: cast_nullable_to_non_nullable
as bool,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,defaultServer: null == defaultServer ? _self.defaultServer : defaultServer // ignore: cast_nullable_to_non_nullable
as String,servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<String>,serverProbeSucceeded: null == serverProbeSucceeded ? _self.serverProbeSucceeded : serverProbeSucceeded // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,adminResetAt: freezed == adminResetAt ? _self.adminResetAt : adminResetAt // ignore: cast_nullable_to_non_nullable
as DateTime?,switchCount: freezed == switchCount ? _self.switchCount : switchCount // ignore: cast_nullable_to_non_nullable
as int?,partitionRevision: null == partitionRevision ? _self.partitionRevision : partitionRevision // ignore: cast_nullable_to_non_nullable
as int,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as SyncStatus,spaceCleared: null == spaceCleared ? _self.spaceCleared : spaceCleared // ignore: cast_nullable_to_non_nullable
as bool,clearedCount: null == clearedCount ? _self.clearedCount : clearedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthUiState].
extension AuthUiStatePatterns on AuthUiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthUiState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthUiState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthUiState value)  $default,){
final _that = this;
switch (_that) {
case _AuthUiState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthUiState value)?  $default,){
final _that = this;
switch (_that) {
case _AuthUiState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AuthPage page,  bool busy,  bool authenticated,  bool forcedPassword,  String server,  String defaultServer,  List<String> servers,  bool serverProbeSucceeded,  String? errorCode,  DateTime? adminResetAt,  int? switchCount,  int partitionRevision,  SyncStatus syncStatus,  bool spaceCleared,  int clearedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthUiState() when $default != null:
return $default(_that.page,_that.busy,_that.authenticated,_that.forcedPassword,_that.server,_that.defaultServer,_that.servers,_that.serverProbeSucceeded,_that.errorCode,_that.adminResetAt,_that.switchCount,_that.partitionRevision,_that.syncStatus,_that.spaceCleared,_that.clearedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AuthPage page,  bool busy,  bool authenticated,  bool forcedPassword,  String server,  String defaultServer,  List<String> servers,  bool serverProbeSucceeded,  String? errorCode,  DateTime? adminResetAt,  int? switchCount,  int partitionRevision,  SyncStatus syncStatus,  bool spaceCleared,  int clearedCount)  $default,) {final _that = this;
switch (_that) {
case _AuthUiState():
return $default(_that.page,_that.busy,_that.authenticated,_that.forcedPassword,_that.server,_that.defaultServer,_that.servers,_that.serverProbeSucceeded,_that.errorCode,_that.adminResetAt,_that.switchCount,_that.partitionRevision,_that.syncStatus,_that.spaceCleared,_that.clearedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AuthPage page,  bool busy,  bool authenticated,  bool forcedPassword,  String server,  String defaultServer,  List<String> servers,  bool serverProbeSucceeded,  String? errorCode,  DateTime? adminResetAt,  int? switchCount,  int partitionRevision,  SyncStatus syncStatus,  bool spaceCleared,  int clearedCount)?  $default,) {final _that = this;
switch (_that) {
case _AuthUiState() when $default != null:
return $default(_that.page,_that.busy,_that.authenticated,_that.forcedPassword,_that.server,_that.defaultServer,_that.servers,_that.serverProbeSucceeded,_that.errorCode,_that.adminResetAt,_that.switchCount,_that.partitionRevision,_that.syncStatus,_that.spaceCleared,_that.clearedCount);case _:
  return null;

}
}

}

/// @nodoc


class _AuthUiState implements AuthUiState {
  const _AuthUiState({this.page = AuthPage.loading, this.busy = false, this.authenticated = false, this.forcedPassword = false, this.server = '', this.defaultServer = '',  List<String> servers = const <String>[], this.serverProbeSucceeded = false, this.errorCode, this.adminResetAt, this.switchCount, this.partitionRevision = 0, this.syncStatus = SyncStatus.idle, this.spaceCleared = false, this.clearedCount = 0}): _servers = servers;
  

@override@JsonKey() final  AuthPage page;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool authenticated;
@override@JsonKey() final  bool forcedPassword;
@override@JsonKey() final  String server;
@override@JsonKey() final  String defaultServer;
 final  List<String> _servers;
@override@JsonKey() List<String> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}

@override@JsonKey() final  bool serverProbeSucceeded;
@override final  String? errorCode;
@override final  DateTime? adminResetAt;
@override final  int? switchCount;
@override@JsonKey() final  int partitionRevision;
@override@JsonKey() final  SyncStatus syncStatus;
@override@JsonKey() final  bool spaceCleared;
@override@JsonKey() final  int clearedCount;

/// Create a copy of AuthUiState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthUiStateCopyWith<_AuthUiState> get copyWith => __$AuthUiStateCopyWithImpl<_AuthUiState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthUiState&&(identical(other.page, page) || other.page == page)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.authenticated, authenticated) || other.authenticated == authenticated)&&(identical(other.forcedPassword, forcedPassword) || other.forcedPassword == forcedPassword)&&(identical(other.server, server) || other.server == server)&&(identical(other.defaultServer, defaultServer) || other.defaultServer == defaultServer)&&const DeepCollectionEquality().equals(other.servers, _servers)&&(identical(other.serverProbeSucceeded, serverProbeSucceeded) || other.serverProbeSucceeded == serverProbeSucceeded)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.adminResetAt, adminResetAt) || other.adminResetAt == adminResetAt)&&(identical(other.switchCount, switchCount) || other.switchCount == switchCount)&&(identical(other.partitionRevision, partitionRevision) || other.partitionRevision == partitionRevision)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus)&&(identical(other.spaceCleared, spaceCleared) || other.spaceCleared == spaceCleared)&&(identical(other.clearedCount, clearedCount) || other.clearedCount == clearedCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,page,busy,authenticated,forcedPassword,server,defaultServer,const DeepCollectionEquality().hash(_servers),serverProbeSucceeded,errorCode,adminResetAt,switchCount,partitionRevision,syncStatus,spaceCleared,clearedCount);
}

@override
String toString() {
    return 'AuthUiState(page: $page, busy: $busy, authenticated: $authenticated, forcedPassword: $forcedPassword, server: $server, defaultServer: $defaultServer, servers: $servers, serverProbeSucceeded: $serverProbeSucceeded, errorCode: $errorCode, adminResetAt: $adminResetAt, switchCount: $switchCount, partitionRevision: $partitionRevision, syncStatus: $syncStatus, spaceCleared: $spaceCleared, clearedCount: $clearedCount)';
}


}

/// @nodoc
abstract mixin class _$AuthUiStateCopyWith<$Res> implements $AuthUiStateCopyWith<$Res> {
  factory _$AuthUiStateCopyWith(_AuthUiState value, $Res Function(_AuthUiState) _then) = __$AuthUiStateCopyWithImpl;
@override @useResult
$Res call({
 AuthPage page, bool busy, bool authenticated, bool forcedPassword, String server, String defaultServer, List<String> servers, bool serverProbeSucceeded, String? errorCode, DateTime? adminResetAt, int? switchCount, int partitionRevision, SyncStatus syncStatus, bool spaceCleared, int clearedCount
});




}
/// @nodoc
class __$AuthUiStateCopyWithImpl<$Res>
    implements _$AuthUiStateCopyWith<$Res> {
  __$AuthUiStateCopyWithImpl(this._self, this._then);

  final _AuthUiState _self;
  final $Res Function(_AuthUiState) _then;

/// Create a copy of AuthUiState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? page = null,Object? busy = null,Object? authenticated = null,Object? forcedPassword = null,Object? server = null,Object? defaultServer = null,Object? servers = null,Object? serverProbeSucceeded = null,Object? errorCode = freezed,Object? adminResetAt = freezed,Object? switchCount = freezed,Object? partitionRevision = null,Object? syncStatus = null,Object? spaceCleared = null,Object? clearedCount = null,}) {
  return _then(_AuthUiState(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as AuthPage,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,authenticated: null == authenticated ? _self.authenticated : authenticated // ignore: cast_nullable_to_non_nullable
as bool,forcedPassword: null == forcedPassword ? _self.forcedPassword : forcedPassword // ignore: cast_nullable_to_non_nullable
as bool,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,defaultServer: null == defaultServer ? _self.defaultServer : defaultServer // ignore: cast_nullable_to_non_nullable
as String,servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<String>,serverProbeSucceeded: null == serverProbeSucceeded ? _self.serverProbeSucceeded : serverProbeSucceeded // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,adminResetAt: freezed == adminResetAt ? _self.adminResetAt : adminResetAt // ignore: cast_nullable_to_non_nullable
as DateTime?,switchCount: freezed == switchCount ? _self.switchCount : switchCount // ignore: cast_nullable_to_non_nullable
as int?,partitionRevision: null == partitionRevision ? _self.partitionRevision : partitionRevision // ignore: cast_nullable_to_non_nullable
as int,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as SyncStatus,spaceCleared: null == spaceCleared ? _self.spaceCleared : spaceCleared // ignore: cast_nullable_to_non_nullable
as bool,clearedCount: null == clearedCount ? _self.clearedCount : clearedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
