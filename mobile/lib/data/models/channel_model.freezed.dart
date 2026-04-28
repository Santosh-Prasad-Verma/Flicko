// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChannelModel {

 String get id;@JsonKey(name: 'server_id') String get serverId; String get name; ChannelType get type; String? get topic; int get position; bool get nsfw;@JsonKey(name: 'parent_id') String? get parentId;@JsonKey(name: 'slowmode_seconds') int get slowmodeSeconds;@JsonKey(name: 'last_message_id') String? get lastMessageId;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of ChannelModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelModelCopyWith<ChannelModel> get copyWith => _$ChannelModelCopyWithImpl<ChannelModel>(this as ChannelModel, _$identity);

  /// Serializes this ChannelModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelModel&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.position, position) || other.position == position)&&(identical(other.nsfw, nsfw) || other.nsfw == nsfw)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.slowmodeSeconds, slowmodeSeconds) || other.slowmodeSeconds == slowmodeSeconds)&&(identical(other.lastMessageId, lastMessageId) || other.lastMessageId == lastMessageId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,type,topic,position,nsfw,parentId,slowmodeSeconds,lastMessageId,createdAt,updatedAt);

@override
String toString() {
  return 'ChannelModel(id: $id, serverId: $serverId, name: $name, type: $type, topic: $topic, position: $position, nsfw: $nsfw, parentId: $parentId, slowmodeSeconds: $slowmodeSeconds, lastMessageId: $lastMessageId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ChannelModelCopyWith<$Res>  {
  factory $ChannelModelCopyWith(ChannelModel value, $Res Function(ChannelModel) _then) = _$ChannelModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'server_id') String serverId, String name, ChannelType type, String? topic, int position, bool nsfw,@JsonKey(name: 'parent_id') String? parentId,@JsonKey(name: 'slowmode_seconds') int slowmodeSeconds,@JsonKey(name: 'last_message_id') String? lastMessageId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$ChannelModelCopyWithImpl<$Res>
    implements $ChannelModelCopyWith<$Res> {
  _$ChannelModelCopyWithImpl(this._self, this._then);

  final ChannelModel _self;
  final $Res Function(ChannelModel) _then;

/// Create a copy of ChannelModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? type = null,Object? topic = freezed,Object? position = null,Object? nsfw = null,Object? parentId = freezed,Object? slowmodeSeconds = null,Object? lastMessageId = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ChannelType,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,nsfw: null == nsfw ? _self.nsfw : nsfw // ignore: cast_nullable_to_non_nullable
as bool,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,slowmodeSeconds: null == slowmodeSeconds ? _self.slowmodeSeconds : slowmodeSeconds // ignore: cast_nullable_to_non_nullable
as int,lastMessageId: freezed == lastMessageId ? _self.lastMessageId : lastMessageId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChannelModel].
extension ChannelModelPatterns on ChannelModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelModel value)  $default,){
final _that = this;
switch (_that) {
case _ChannelModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'server_id')  String serverId,  String name,  ChannelType type,  String? topic,  int position,  bool nsfw, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'slowmode_seconds')  int slowmodeSeconds, @JsonKey(name: 'last_message_id')  String? lastMessageId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelModel() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.topic,_that.position,_that.nsfw,_that.parentId,_that.slowmodeSeconds,_that.lastMessageId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'server_id')  String serverId,  String name,  ChannelType type,  String? topic,  int position,  bool nsfw, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'slowmode_seconds')  int slowmodeSeconds, @JsonKey(name: 'last_message_id')  String? lastMessageId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ChannelModel():
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.topic,_that.position,_that.nsfw,_that.parentId,_that.slowmodeSeconds,_that.lastMessageId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'server_id')  String serverId,  String name,  ChannelType type,  String? topic,  int position,  bool nsfw, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'slowmode_seconds')  int slowmodeSeconds, @JsonKey(name: 'last_message_id')  String? lastMessageId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ChannelModel() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.topic,_that.position,_that.nsfw,_that.parentId,_that.slowmodeSeconds,_that.lastMessageId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChannelModel implements ChannelModel {
  const _ChannelModel({required this.id, @JsonKey(name: 'server_id') required this.serverId, required this.name, this.type = ChannelType.text, this.topic, this.position = 0, this.nsfw = false, @JsonKey(name: 'parent_id') this.parentId, @JsonKey(name: 'slowmode_seconds') this.slowmodeSeconds = 0, @JsonKey(name: 'last_message_id') this.lastMessageId, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _ChannelModel.fromJson(Map<String, dynamic> json) => _$ChannelModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'server_id') final  String serverId;
@override final  String name;
@override@JsonKey() final  ChannelType type;
@override final  String? topic;
@override@JsonKey() final  int position;
@override@JsonKey() final  bool nsfw;
@override@JsonKey(name: 'parent_id') final  String? parentId;
@override@JsonKey(name: 'slowmode_seconds') final  int slowmodeSeconds;
@override@JsonKey(name: 'last_message_id') final  String? lastMessageId;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of ChannelModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelModelCopyWith<_ChannelModel> get copyWith => __$ChannelModelCopyWithImpl<_ChannelModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelModel&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.position, position) || other.position == position)&&(identical(other.nsfw, nsfw) || other.nsfw == nsfw)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.slowmodeSeconds, slowmodeSeconds) || other.slowmodeSeconds == slowmodeSeconds)&&(identical(other.lastMessageId, lastMessageId) || other.lastMessageId == lastMessageId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,type,topic,position,nsfw,parentId,slowmodeSeconds,lastMessageId,createdAt,updatedAt);

@override
String toString() {
  return 'ChannelModel(id: $id, serverId: $serverId, name: $name, type: $type, topic: $topic, position: $position, nsfw: $nsfw, parentId: $parentId, slowmodeSeconds: $slowmodeSeconds, lastMessageId: $lastMessageId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ChannelModelCopyWith<$Res> implements $ChannelModelCopyWith<$Res> {
  factory _$ChannelModelCopyWith(_ChannelModel value, $Res Function(_ChannelModel) _then) = __$ChannelModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'server_id') String serverId, String name, ChannelType type, String? topic, int position, bool nsfw,@JsonKey(name: 'parent_id') String? parentId,@JsonKey(name: 'slowmode_seconds') int slowmodeSeconds,@JsonKey(name: 'last_message_id') String? lastMessageId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$ChannelModelCopyWithImpl<$Res>
    implements _$ChannelModelCopyWith<$Res> {
  __$ChannelModelCopyWithImpl(this._self, this._then);

  final _ChannelModel _self;
  final $Res Function(_ChannelModel) _then;

/// Create a copy of ChannelModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? type = null,Object? topic = freezed,Object? position = null,Object? nsfw = null,Object? parentId = freezed,Object? slowmodeSeconds = null,Object? lastMessageId = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_ChannelModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ChannelType,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,nsfw: null == nsfw ? _self.nsfw : nsfw // ignore: cast_nullable_to_non_nullable
as bool,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,slowmodeSeconds: null == slowmodeSeconds ? _self.slowmodeSeconds : slowmodeSeconds // ignore: cast_nullable_to_non_nullable
as int,lastMessageId: freezed == lastMessageId ? _self.lastMessageId : lastMessageId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
