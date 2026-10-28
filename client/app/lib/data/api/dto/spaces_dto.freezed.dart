// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spaces_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MemberSummaryDto {

 String get id; String get displayName; String get role; String get status; int get version;
/// Create a copy of MemberSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberSummaryDtoCopyWith<MemberSummaryDto> get copyWith => _$MemberSummaryDtoCopyWithImpl<MemberSummaryDto>(this as MemberSummaryDto, _$identity);

  /// Serializes this MemberSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MemberSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemberSummaryDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.version, _this.version) || other.version == _this.version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MemberSummaryDto;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.role,_this.status,_this.version);
}

@override
String toString() {
  final _this = this as MemberSummaryDto;
  return 'MemberSummaryDto(id: ${_this.id}, displayName: ${_this.displayName}, role: ${_this.role}, status: ${_this.status}, version: ${_this.version})';
}


}

/// @nodoc
abstract mixin class $MemberSummaryDtoCopyWith<$Res>  {
  factory $MemberSummaryDtoCopyWith(MemberSummaryDto value, $Res Function(MemberSummaryDto) _then) = _$MemberSummaryDtoCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String role, String status, int version
});




}
/// @nodoc
class _$MemberSummaryDtoCopyWithImpl<$Res>
    implements $MemberSummaryDtoCopyWith<$Res> {
  _$MemberSummaryDtoCopyWithImpl(this._self, this._then);

  final MemberSummaryDto _self;
  final $Res Function(MemberSummaryDto) _then;

/// Create a copy of MemberSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? role = null,Object? status = null,Object? version = null,}) {
  return _then(MemberSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MemberSummaryDto].
extension MemberSummaryDtoPatterns on MemberSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemberSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemberSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemberSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _MemberSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemberSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _MemberSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String role,  String status,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemberSummaryDto() when $default != null:
return $default(_that.id,_that.displayName,_that.role,_that.status,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String role,  String status,  int version)  $default,) {final _that = this;
switch (_that) {
case _MemberSummaryDto():
return $default(_that.id,_that.displayName,_that.role,_that.status,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String role,  String status,  int version)?  $default,) {final _that = this;
switch (_that) {
case _MemberSummaryDto() when $default != null:
return $default(_that.id,_that.displayName,_that.role,_that.status,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MemberSummaryDto implements MemberSummaryDto {
  const _MemberSummaryDto({required this.id, required this.displayName, required this.role, required this.status, required this.version});
  factory _MemberSummaryDto.fromJson(Map<String, dynamic> json) => _$MemberSummaryDtoFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String role;
@override final  String status;
@override final  int version;

/// Create a copy of MemberSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberSummaryDtoCopyWith<_MemberSummaryDto> get copyWith => __$MemberSummaryDtoCopyWithImpl<_MemberSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MemberSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemberSummaryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,role,status,version);
}

@override
String toString() {
    return 'MemberSummaryDto(id: $id, displayName: $displayName, role: $role, status: $status, version: $version)';
}


}

/// @nodoc
abstract mixin class _$MemberSummaryDtoCopyWith<$Res> implements $MemberSummaryDtoCopyWith<$Res> {
  factory _$MemberSummaryDtoCopyWith(_MemberSummaryDto value, $Res Function(_MemberSummaryDto) _then) = __$MemberSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String role, String status, int version
});




}
/// @nodoc
class __$MemberSummaryDtoCopyWithImpl<$Res>
    implements _$MemberSummaryDtoCopyWith<$Res> {
  __$MemberSummaryDtoCopyWithImpl(this._self, this._then);

  final _MemberSummaryDto _self;
  final $Res Function(_MemberSummaryDto) _then;

/// Create a copy of MemberSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? role = null,Object? status = null,Object? version = null,}) {
  return _then(_MemberSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SpaceDto {

 String get id; String get name; String get accentColor; String get currency; String get timezone; bool get isDefault; int get version; String get role; int get joinEpoch; String get memberId; Map<String, String> get modules; List<MemberSummaryDto> get members;
/// Create a copy of SpaceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpaceDtoCopyWith<SpaceDto> get copyWith => _$SpaceDtoCopyWithImpl<SpaceDto>(this as SpaceDto, _$identity);

  /// Serializes this SpaceDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpaceDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpaceDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.accentColor, _this.accentColor) || other.accentColor == _this.accentColor)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.joinEpoch, _this.joinEpoch) || other.joinEpoch == _this.joinEpoch)&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&const DeepCollectionEquality().equals(other.modules, _this.modules)&&const DeepCollectionEquality().equals(other.members, _this.members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpaceDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.accentColor,_this.currency,_this.timezone,_this.isDefault,_this.version,_this.role,_this.joinEpoch,_this.memberId,const DeepCollectionEquality().hash(_this.modules),const DeepCollectionEquality().hash(_this.members));
}

@override
String toString() {
  final _this = this as SpaceDto;
  return 'SpaceDto(id: ${_this.id}, name: ${_this.name}, accentColor: ${_this.accentColor}, currency: ${_this.currency}, timezone: ${_this.timezone}, isDefault: ${_this.isDefault}, version: ${_this.version}, role: ${_this.role}, joinEpoch: ${_this.joinEpoch}, memberId: ${_this.memberId}, modules: ${_this.modules}, members: ${_this.members})';
}


}

/// @nodoc
abstract mixin class $SpaceDtoCopyWith<$Res>  {
  factory $SpaceDtoCopyWith(SpaceDto value, $Res Function(SpaceDto) _then) = _$SpaceDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String accentColor, String currency, String timezone, bool isDefault, int version, String role, int joinEpoch, String memberId, Map<String, String> modules, List<MemberSummaryDto> members
});




}
/// @nodoc
class _$SpaceDtoCopyWithImpl<$Res>
    implements $SpaceDtoCopyWith<$Res> {
  _$SpaceDtoCopyWithImpl(this._self, this._then);

  final SpaceDto _self;
  final $Res Function(SpaceDto) _then;

/// Create a copy of SpaceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? accentColor = null,Object? currency = null,Object? timezone = null,Object? isDefault = null,Object? version = null,Object? role = null,Object? joinEpoch = null,Object? memberId = null,Object? modules = null,Object? members = null,}) {
  return _then(SpaceDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinEpoch: null == joinEpoch ? _self.joinEpoch : joinEpoch // ignore: cast_nullable_to_non_nullable
as int,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
as Map<String, String>,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<MemberSummaryDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [SpaceDto].
extension SpaceDtoPatterns on SpaceDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpaceDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpaceDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpaceDto value)  $default,){
final _that = this;
switch (_that) {
case _SpaceDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpaceDto value)?  $default,){
final _that = this;
switch (_that) {
case _SpaceDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String accentColor,  String currency,  String timezone,  bool isDefault,  int version,  String role,  int joinEpoch,  String memberId,  Map<String, String> modules,  List<MemberSummaryDto> members)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpaceDto() when $default != null:
return $default(_that.id,_that.name,_that.accentColor,_that.currency,_that.timezone,_that.isDefault,_that.version,_that.role,_that.joinEpoch,_that.memberId,_that.modules,_that.members);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String accentColor,  String currency,  String timezone,  bool isDefault,  int version,  String role,  int joinEpoch,  String memberId,  Map<String, String> modules,  List<MemberSummaryDto> members)  $default,) {final _that = this;
switch (_that) {
case _SpaceDto():
return $default(_that.id,_that.name,_that.accentColor,_that.currency,_that.timezone,_that.isDefault,_that.version,_that.role,_that.joinEpoch,_that.memberId,_that.modules,_that.members);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String accentColor,  String currency,  String timezone,  bool isDefault,  int version,  String role,  int joinEpoch,  String memberId,  Map<String, String> modules,  List<MemberSummaryDto> members)?  $default,) {final _that = this;
switch (_that) {
case _SpaceDto() when $default != null:
return $default(_that.id,_that.name,_that.accentColor,_that.currency,_that.timezone,_that.isDefault,_that.version,_that.role,_that.joinEpoch,_that.memberId,_that.modules,_that.members);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpaceDto implements SpaceDto {
  const _SpaceDto({required this.id, required this.name, required this.accentColor, required this.currency, required this.timezone, required this.isDefault, required this.version, required this.role, required this.joinEpoch, required this.memberId, required  Map<String, String> modules, required  List<MemberSummaryDto> members}): _modules = modules,_members = members;
  factory _SpaceDto.fromJson(Map<String, dynamic> json) => _$SpaceDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String accentColor;
@override final  String currency;
@override final  String timezone;
@override final  bool isDefault;
@override final  int version;
@override final  String role;
@override final  int joinEpoch;
@override final  String memberId;
 final  Map<String, String> _modules;
@override Map<String, String> get modules {
  if (_modules is EqualUnmodifiableMapView) return _modules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_modules);
}

 final  List<MemberSummaryDto> _members;
@override List<MemberSummaryDto> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}


/// Create a copy of SpaceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpaceDtoCopyWith<_SpaceDto> get copyWith => __$SpaceDtoCopyWithImpl<_SpaceDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpaceDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpaceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.version, version) || other.version == version)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinEpoch, joinEpoch) || other.joinEpoch == joinEpoch)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&const DeepCollectionEquality().equals(other.modules, _modules)&&const DeepCollectionEquality().equals(other.members, _members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,accentColor,currency,timezone,isDefault,version,role,joinEpoch,memberId,const DeepCollectionEquality().hash(_modules),const DeepCollectionEquality().hash(_members));
}

@override
String toString() {
    return 'SpaceDto(id: $id, name: $name, accentColor: $accentColor, currency: $currency, timezone: $timezone, isDefault: $isDefault, version: $version, role: $role, joinEpoch: $joinEpoch, memberId: $memberId, modules: $modules, members: $members)';
}


}

/// @nodoc
abstract mixin class _$SpaceDtoCopyWith<$Res> implements $SpaceDtoCopyWith<$Res> {
  factory _$SpaceDtoCopyWith(_SpaceDto value, $Res Function(_SpaceDto) _then) = __$SpaceDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String accentColor, String currency, String timezone, bool isDefault, int version, String role, int joinEpoch, String memberId, Map<String, String> modules, List<MemberSummaryDto> members
});




}
/// @nodoc
class __$SpaceDtoCopyWithImpl<$Res>
    implements _$SpaceDtoCopyWith<$Res> {
  __$SpaceDtoCopyWithImpl(this._self, this._then);

  final _SpaceDto _self;
  final $Res Function(_SpaceDto) _then;

/// Create a copy of SpaceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? accentColor = null,Object? currency = null,Object? timezone = null,Object? isDefault = null,Object? version = null,Object? role = null,Object? joinEpoch = null,Object? memberId = null,Object? modules = null,Object? members = null,}) {
  return _then(_SpaceDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinEpoch: null == joinEpoch ? _self.joinEpoch : joinEpoch // ignore: cast_nullable_to_non_nullable
as int,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
as Map<String, String>,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<MemberSummaryDto>,
  ));
}


}


/// @nodoc
mixin _$SpacesDto {

 List<SpaceDto> get spaces;
/// Create a copy of SpacesDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpacesDtoCopyWith<SpacesDto> get copyWith => _$SpacesDtoCopyWithImpl<SpacesDto>(this as SpacesDto, _$identity);

  /// Serializes this SpacesDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpacesDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpacesDto&&const DeepCollectionEquality().equals(other.spaces, _this.spaces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpacesDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.spaces));
}

@override
String toString() {
  final _this = this as SpacesDto;
  return 'SpacesDto(spaces: ${_this.spaces})';
}


}

/// @nodoc
abstract mixin class $SpacesDtoCopyWith<$Res>  {
  factory $SpacesDtoCopyWith(SpacesDto value, $Res Function(SpacesDto) _then) = _$SpacesDtoCopyWithImpl;
@useResult
$Res call({
 List<SpaceDto> spaces
});




}
/// @nodoc
class _$SpacesDtoCopyWithImpl<$Res>
    implements $SpacesDtoCopyWith<$Res> {
  _$SpacesDtoCopyWithImpl(this._self, this._then);

  final SpacesDto _self;
  final $Res Function(SpacesDto) _then;

/// Create a copy of SpacesDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spaces = null,}) {
  return _then(SpacesDto(
spaces: null == spaces ? _self.spaces : spaces // ignore: cast_nullable_to_non_nullable
as List<SpaceDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [SpacesDto].
extension SpacesDtoPatterns on SpacesDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpacesDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpacesDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpacesDto value)  $default,){
final _that = this;
switch (_that) {
case _SpacesDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpacesDto value)?  $default,){
final _that = this;
switch (_that) {
case _SpacesDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SpaceDto> spaces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpacesDto() when $default != null:
return $default(_that.spaces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SpaceDto> spaces)  $default,) {final _that = this;
switch (_that) {
case _SpacesDto():
return $default(_that.spaces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SpaceDto> spaces)?  $default,) {final _that = this;
switch (_that) {
case _SpacesDto() when $default != null:
return $default(_that.spaces);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpacesDto implements SpacesDto {
  const _SpacesDto({required  List<SpaceDto> spaces}): _spaces = spaces;
  factory _SpacesDto.fromJson(Map<String, dynamic> json) => _$SpacesDtoFromJson(json);

 final  List<SpaceDto> _spaces;
@override List<SpaceDto> get spaces {
  if (_spaces is EqualUnmodifiableListView) return _spaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spaces);
}


/// Create a copy of SpacesDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpacesDtoCopyWith<_SpacesDto> get copyWith => __$SpacesDtoCopyWithImpl<_SpacesDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpacesDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpacesDto&&const DeepCollectionEquality().equals(other.spaces, _spaces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_spaces));
}

@override
String toString() {
    return 'SpacesDto(spaces: $spaces)';
}


}

/// @nodoc
abstract mixin class _$SpacesDtoCopyWith<$Res> implements $SpacesDtoCopyWith<$Res> {
  factory _$SpacesDtoCopyWith(_SpacesDto value, $Res Function(_SpacesDto) _then) = __$SpacesDtoCopyWithImpl;
@override @useResult
$Res call({
 List<SpaceDto> spaces
});




}
/// @nodoc
class __$SpacesDtoCopyWithImpl<$Res>
    implements _$SpacesDtoCopyWith<$Res> {
  __$SpacesDtoCopyWithImpl(this._self, this._then);

  final _SpacesDto _self;
  final $Res Function(_SpacesDto) _then;

/// Create a copy of SpacesDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? spaces = null,}) {
  return _then(_SpacesDto(
spaces: null == spaces ? _self._spaces : spaces // ignore: cast_nullable_to_non_nullable
as List<SpaceDto>,
  ));
}


}

// dart format on
