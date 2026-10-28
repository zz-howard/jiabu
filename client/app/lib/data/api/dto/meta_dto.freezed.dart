// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaDto {

 String get serverVersion; List<int> get apiVersions; Map<String, int> get minClientBuild; List<String> get features;
/// Create a copy of MetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaDtoCopyWith<MetaDto> get copyWith => _$MetaDtoCopyWithImpl<MetaDto>(this as MetaDto, _$identity);

  /// Serializes this MetaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaDto&&(identical(other.serverVersion, _this.serverVersion) || other.serverVersion == _this.serverVersion)&&const DeepCollectionEquality().equals(other.apiVersions, _this.apiVersions)&&const DeepCollectionEquality().equals(other.minClientBuild, _this.minClientBuild)&&const DeepCollectionEquality().equals(other.features, _this.features));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MetaDto;
  return Object.hash(runtimeType,_this.serverVersion,const DeepCollectionEquality().hash(_this.apiVersions),const DeepCollectionEquality().hash(_this.minClientBuild),const DeepCollectionEquality().hash(_this.features));
}

@override
String toString() {
  final _this = this as MetaDto;
  return 'MetaDto(serverVersion: ${_this.serverVersion}, apiVersions: ${_this.apiVersions}, minClientBuild: ${_this.minClientBuild}, features: ${_this.features})';
}


}

/// @nodoc
abstract mixin class $MetaDtoCopyWith<$Res>  {
  factory $MetaDtoCopyWith(MetaDto value, $Res Function(MetaDto) _then) = _$MetaDtoCopyWithImpl;
@useResult
$Res call({
 String serverVersion, List<int> apiVersions, Map<String, int> minClientBuild, List<String> features
});




}
/// @nodoc
class _$MetaDtoCopyWithImpl<$Res>
    implements $MetaDtoCopyWith<$Res> {
  _$MetaDtoCopyWithImpl(this._self, this._then);

  final MetaDto _self;
  final $Res Function(MetaDto) _then;

/// Create a copy of MetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverVersion = null,Object? apiVersions = null,Object? minClientBuild = null,Object? features = null,}) {
  return _then(MetaDto(
serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,apiVersions: null == apiVersions ? _self.apiVersions : apiVersions // ignore: cast_nullable_to_non_nullable
as List<int>,minClientBuild: null == minClientBuild ? _self.minClientBuild : minClientBuild // ignore: cast_nullable_to_non_nullable
as Map<String, int>,features: null == features ? _self.features : features // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaDto].
extension MetaDtoPatterns on MetaDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaDto value)  $default,){
final _that = this;
switch (_that) {
case _MetaDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaDto value)?  $default,){
final _that = this;
switch (_that) {
case _MetaDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverVersion,  List<int> apiVersions,  Map<String, int> minClientBuild,  List<String> features)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MetaDto() when $default != null:
return $default(_that.serverVersion,_that.apiVersions,_that.minClientBuild,_that.features);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverVersion,  List<int> apiVersions,  Map<String, int> minClientBuild,  List<String> features)  $default,) {final _that = this;
switch (_that) {
case _MetaDto():
return $default(_that.serverVersion,_that.apiVersions,_that.minClientBuild,_that.features);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverVersion,  List<int> apiVersions,  Map<String, int> minClientBuild,  List<String> features)?  $default,) {final _that = this;
switch (_that) {
case _MetaDto() when $default != null:
return $default(_that.serverVersion,_that.apiVersions,_that.minClientBuild,_that.features);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaDto implements MetaDto {
  const _MetaDto({required this.serverVersion, required  List<int> apiVersions, required  Map<String, int> minClientBuild, required  List<String> features}): _apiVersions = apiVersions,_minClientBuild = minClientBuild,_features = features;
  factory _MetaDto.fromJson(Map<String, dynamic> json) => _$MetaDtoFromJson(json);

@override final  String serverVersion;
 final  List<int> _apiVersions;
@override List<int> get apiVersions {
  if (_apiVersions is EqualUnmodifiableListView) return _apiVersions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_apiVersions);
}

 final  Map<String, int> _minClientBuild;
@override Map<String, int> get minClientBuild {
  if (_minClientBuild is EqualUnmodifiableMapView) return _minClientBuild;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_minClientBuild);
}

 final  List<String> _features;
@override List<String> get features {
  if (_features is EqualUnmodifiableListView) return _features;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_features);
}


/// Create a copy of MetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaDtoCopyWith<_MetaDto> get copyWith => __$MetaDtoCopyWithImpl<_MetaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaDto&&(identical(other.serverVersion, serverVersion) || other.serverVersion == serverVersion)&&const DeepCollectionEquality().equals(other.apiVersions, _apiVersions)&&const DeepCollectionEquality().equals(other.minClientBuild, _minClientBuild)&&const DeepCollectionEquality().equals(other.features, _features));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,serverVersion,const DeepCollectionEquality().hash(_apiVersions),const DeepCollectionEquality().hash(_minClientBuild),const DeepCollectionEquality().hash(_features));
}

@override
String toString() {
    return 'MetaDto(serverVersion: $serverVersion, apiVersions: $apiVersions, minClientBuild: $minClientBuild, features: $features)';
}


}

/// @nodoc
abstract mixin class _$MetaDtoCopyWith<$Res> implements $MetaDtoCopyWith<$Res> {
  factory _$MetaDtoCopyWith(_MetaDto value, $Res Function(_MetaDto) _then) = __$MetaDtoCopyWithImpl;
@override @useResult
$Res call({
 String serverVersion, List<int> apiVersions, Map<String, int> minClientBuild, List<String> features
});




}
/// @nodoc
class __$MetaDtoCopyWithImpl<$Res>
    implements _$MetaDtoCopyWith<$Res> {
  __$MetaDtoCopyWithImpl(this._self, this._then);

  final _MetaDto _self;
  final $Res Function(_MetaDto) _then;

/// Create a copy of MetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverVersion = null,Object? apiVersions = null,Object? minClientBuild = null,Object? features = null,}) {
  return _then(_MetaDto(
serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,apiVersions: null == apiVersions ? _self._apiVersions : apiVersions // ignore: cast_nullable_to_non_nullable
as List<int>,minClientBuild: null == minClientBuild ? _self._minClientBuild : minClientBuild // ignore: cast_nullable_to_non_nullable
as Map<String, int>,features: null == features ? _self._features : features // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
