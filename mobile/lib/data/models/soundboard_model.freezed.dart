// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'soundboard_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SoundboardSound {

 String get id; String get serverId; String get name; String get emoji; String get url; int get duration;// in seconds
 bool get isFavorite; String get creatorId; DateTime get createdAt;
/// Create a copy of SoundboardSound
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoundboardSoundCopyWith<SoundboardSound> get copyWith => _$SoundboardSoundCopyWithImpl<SoundboardSound>(this as SoundboardSound, _$identity);

  /// Serializes this SoundboardSound to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundboardSound&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.url, url) || other.url == url)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.creatorId, creatorId) || other.creatorId == creatorId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,emoji,url,duration,isFavorite,creatorId,createdAt);

@override
String toString() {
  return 'SoundboardSound(id: $id, serverId: $serverId, name: $name, emoji: $emoji, url: $url, duration: $duration, isFavorite: $isFavorite, creatorId: $creatorId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SoundboardSoundCopyWith<$Res>  {
  factory $SoundboardSoundCopyWith(SoundboardSound value, $Res Function(SoundboardSound) _then) = _$SoundboardSoundCopyWithImpl;
@useResult
$Res call({
 String id, String serverId, String name, String emoji, String url, int duration, bool isFavorite, String creatorId, DateTime createdAt
});




}
/// @nodoc
class _$SoundboardSoundCopyWithImpl<$Res>
    implements $SoundboardSoundCopyWith<$Res> {
  _$SoundboardSoundCopyWithImpl(this._self, this._then);

  final SoundboardSound _self;
  final $Res Function(SoundboardSound) _then;

/// Create a copy of SoundboardSound
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? emoji = null,Object? url = null,Object? duration = null,Object? isFavorite = null,Object? creatorId = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,creatorId: null == creatorId ? _self.creatorId : creatorId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SoundboardSound].
extension SoundboardSoundPatterns on SoundboardSound {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SoundboardSound value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SoundboardSound() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SoundboardSound value)  $default,){
final _that = this;
switch (_that) {
case _SoundboardSound():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SoundboardSound value)?  $default,){
final _that = this;
switch (_that) {
case _SoundboardSound() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  String emoji,  String url,  int duration,  bool isFavorite,  String creatorId,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SoundboardSound() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.emoji,_that.url,_that.duration,_that.isFavorite,_that.creatorId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  String emoji,  String url,  int duration,  bool isFavorite,  String creatorId,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SoundboardSound():
return $default(_that.id,_that.serverId,_that.name,_that.emoji,_that.url,_that.duration,_that.isFavorite,_that.creatorId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serverId,  String name,  String emoji,  String url,  int duration,  bool isFavorite,  String creatorId,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SoundboardSound() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.emoji,_that.url,_that.duration,_that.isFavorite,_that.creatorId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SoundboardSound implements SoundboardSound {
  const _SoundboardSound({required this.id, required this.serverId, required this.name, required this.emoji, required this.url, this.duration = 3, this.isFavorite = false, required this.creatorId, required this.createdAt});
  factory _SoundboardSound.fromJson(Map<String, dynamic> json) => _$SoundboardSoundFromJson(json);

@override final  String id;
@override final  String serverId;
@override final  String name;
@override final  String emoji;
@override final  String url;
@override@JsonKey() final  int duration;
// in seconds
@override@JsonKey() final  bool isFavorite;
@override final  String creatorId;
@override final  DateTime createdAt;

/// Create a copy of SoundboardSound
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SoundboardSoundCopyWith<_SoundboardSound> get copyWith => __$SoundboardSoundCopyWithImpl<_SoundboardSound>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoundboardSoundToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SoundboardSound&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.url, url) || other.url == url)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.creatorId, creatorId) || other.creatorId == creatorId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,emoji,url,duration,isFavorite,creatorId,createdAt);

@override
String toString() {
  return 'SoundboardSound(id: $id, serverId: $serverId, name: $name, emoji: $emoji, url: $url, duration: $duration, isFavorite: $isFavorite, creatorId: $creatorId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SoundboardSoundCopyWith<$Res> implements $SoundboardSoundCopyWith<$Res> {
  factory _$SoundboardSoundCopyWith(_SoundboardSound value, $Res Function(_SoundboardSound) _then) = __$SoundboardSoundCopyWithImpl;
@override @useResult
$Res call({
 String id, String serverId, String name, String emoji, String url, int duration, bool isFavorite, String creatorId, DateTime createdAt
});




}
/// @nodoc
class __$SoundboardSoundCopyWithImpl<$Res>
    implements _$SoundboardSoundCopyWith<$Res> {
  __$SoundboardSoundCopyWithImpl(this._self, this._then);

  final _SoundboardSound _self;
  final $Res Function(_SoundboardSound) _then;

/// Create a copy of SoundboardSound
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? emoji = null,Object? url = null,Object? duration = null,Object? isFavorite = null,Object? creatorId = null,Object? createdAt = null,}) {
  return _then(_SoundboardSound(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,creatorId: null == creatorId ? _self.creatorId : creatorId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
