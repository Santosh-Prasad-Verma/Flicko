// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceState {

 String get channelId; String get userId; bool get isMuted; bool get isDeafened; bool get isVideoEnabled; DateTime get joinedAt; String? get avatarUrl; String? get displayName;
/// Create a copy of VoiceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceStateCopyWith<VoiceState> get copyWith => _$VoiceStateCopyWithImpl<VoiceState>(this as VoiceState, _$identity);

  /// Serializes this VoiceState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceState&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isDeafened, isDeafened) || other.isDeafened == isDeafened)&&(identical(other.isVideoEnabled, isVideoEnabled) || other.isVideoEnabled == isVideoEnabled)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channelId,userId,isMuted,isDeafened,isVideoEnabled,joinedAt,avatarUrl,displayName);

@override
String toString() {
  return 'VoiceState(channelId: $channelId, userId: $userId, isMuted: $isMuted, isDeafened: $isDeafened, isVideoEnabled: $isVideoEnabled, joinedAt: $joinedAt, avatarUrl: $avatarUrl, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $VoiceStateCopyWith<$Res>  {
  factory $VoiceStateCopyWith(VoiceState value, $Res Function(VoiceState) _then) = _$VoiceStateCopyWithImpl;
@useResult
$Res call({
 String channelId, String userId, bool isMuted, bool isDeafened, bool isVideoEnabled, DateTime joinedAt, String? avatarUrl, String? displayName
});




}
/// @nodoc
class _$VoiceStateCopyWithImpl<$Res>
    implements $VoiceStateCopyWith<$Res> {
  _$VoiceStateCopyWithImpl(this._self, this._then);

  final VoiceState _self;
  final $Res Function(VoiceState) _then;

/// Create a copy of VoiceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channelId = null,Object? userId = null,Object? isMuted = null,Object? isDeafened = null,Object? isVideoEnabled = null,Object? joinedAt = null,Object? avatarUrl = freezed,Object? displayName = freezed,}) {
  return _then(_self.copyWith(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isDeafened: null == isDeafened ? _self.isDeafened : isDeafened // ignore: cast_nullable_to_non_nullable
as bool,isVideoEnabled: null == isVideoEnabled ? _self.isVideoEnabled : isVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceState].
extension VoiceStatePatterns on VoiceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceState value)  $default,){
final _that = this;
switch (_that) {
case _VoiceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceState value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String channelId,  String userId,  bool isMuted,  bool isDeafened,  bool isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceState() when $default != null:
return $default(_that.channelId,_that.userId,_that.isMuted,_that.isDeafened,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String channelId,  String userId,  bool isMuted,  bool isDeafened,  bool isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)  $default,) {final _that = this;
switch (_that) {
case _VoiceState():
return $default(_that.channelId,_that.userId,_that.isMuted,_that.isDeafened,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String channelId,  String userId,  bool isMuted,  bool isDeafened,  bool isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)?  $default,) {final _that = this;
switch (_that) {
case _VoiceState() when $default != null:
return $default(_that.channelId,_that.userId,_that.isMuted,_that.isDeafened,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceState implements VoiceState {
  const _VoiceState({required this.channelId, required this.userId, this.isMuted = false, this.isDeafened = false, this.isVideoEnabled = false, required this.joinedAt, this.avatarUrl, this.displayName});
  factory _VoiceState.fromJson(Map<String, dynamic> json) => _$VoiceStateFromJson(json);

@override final  String channelId;
@override final  String userId;
@override@JsonKey() final  bool isMuted;
@override@JsonKey() final  bool isDeafened;
@override@JsonKey() final  bool isVideoEnabled;
@override final  DateTime joinedAt;
@override final  String? avatarUrl;
@override final  String? displayName;

/// Create a copy of VoiceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceStateCopyWith<_VoiceState> get copyWith => __$VoiceStateCopyWithImpl<_VoiceState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceState&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isDeafened, isDeafened) || other.isDeafened == isDeafened)&&(identical(other.isVideoEnabled, isVideoEnabled) || other.isVideoEnabled == isVideoEnabled)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channelId,userId,isMuted,isDeafened,isVideoEnabled,joinedAt,avatarUrl,displayName);

@override
String toString() {
  return 'VoiceState(channelId: $channelId, userId: $userId, isMuted: $isMuted, isDeafened: $isDeafened, isVideoEnabled: $isVideoEnabled, joinedAt: $joinedAt, avatarUrl: $avatarUrl, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$VoiceStateCopyWith<$Res> implements $VoiceStateCopyWith<$Res> {
  factory _$VoiceStateCopyWith(_VoiceState value, $Res Function(_VoiceState) _then) = __$VoiceStateCopyWithImpl;
@override @useResult
$Res call({
 String channelId, String userId, bool isMuted, bool isDeafened, bool isVideoEnabled, DateTime joinedAt, String? avatarUrl, String? displayName
});




}
/// @nodoc
class __$VoiceStateCopyWithImpl<$Res>
    implements _$VoiceStateCopyWith<$Res> {
  __$VoiceStateCopyWithImpl(this._self, this._then);

  final _VoiceState _self;
  final $Res Function(_VoiceState) _then;

/// Create a copy of VoiceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channelId = null,Object? userId = null,Object? isMuted = null,Object? isDeafened = null,Object? isVideoEnabled = null,Object? joinedAt = null,Object? avatarUrl = freezed,Object? displayName = freezed,}) {
  return _then(_VoiceState(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isDeafened: null == isDeafened ? _self.isDeafened : isDeafened // ignore: cast_nullable_to_non_nullable
as bool,isVideoEnabled: null == isVideoEnabled ? _self.isVideoEnabled : isVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VoiceParticipant {

 String get participantSid;// LiveKit SID
 String get userId;// Supabase user ID
 bool get isMuted; bool get isSpeaking;// Local or Remote detection
 bool get isDeafened; bool get isLocal; bool? get isVideoEnabled;// Future proofing
 DateTime get joinedAt; String? get avatarUrl; String? get displayName;
/// Create a copy of VoiceParticipant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceParticipantCopyWith<VoiceParticipant> get copyWith => _$VoiceParticipantCopyWithImpl<VoiceParticipant>(this as VoiceParticipant, _$identity);

  /// Serializes this VoiceParticipant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceParticipant&&(identical(other.participantSid, participantSid) || other.participantSid == participantSid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isSpeaking, isSpeaking) || other.isSpeaking == isSpeaking)&&(identical(other.isDeafened, isDeafened) || other.isDeafened == isDeafened)&&(identical(other.isLocal, isLocal) || other.isLocal == isLocal)&&(identical(other.isVideoEnabled, isVideoEnabled) || other.isVideoEnabled == isVideoEnabled)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,participantSid,userId,isMuted,isSpeaking,isDeafened,isLocal,isVideoEnabled,joinedAt,avatarUrl,displayName);

@override
String toString() {
  return 'VoiceParticipant(participantSid: $participantSid, userId: $userId, isMuted: $isMuted, isSpeaking: $isSpeaking, isDeafened: $isDeafened, isLocal: $isLocal, isVideoEnabled: $isVideoEnabled, joinedAt: $joinedAt, avatarUrl: $avatarUrl, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $VoiceParticipantCopyWith<$Res>  {
  factory $VoiceParticipantCopyWith(VoiceParticipant value, $Res Function(VoiceParticipant) _then) = _$VoiceParticipantCopyWithImpl;
@useResult
$Res call({
 String participantSid, String userId, bool isMuted, bool isSpeaking, bool isDeafened, bool isLocal, bool? isVideoEnabled, DateTime joinedAt, String? avatarUrl, String? displayName
});




}
/// @nodoc
class _$VoiceParticipantCopyWithImpl<$Res>
    implements $VoiceParticipantCopyWith<$Res> {
  _$VoiceParticipantCopyWithImpl(this._self, this._then);

  final VoiceParticipant _self;
  final $Res Function(VoiceParticipant) _then;

/// Create a copy of VoiceParticipant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? participantSid = null,Object? userId = null,Object? isMuted = null,Object? isSpeaking = null,Object? isDeafened = null,Object? isLocal = null,Object? isVideoEnabled = freezed,Object? joinedAt = null,Object? avatarUrl = freezed,Object? displayName = freezed,}) {
  return _then(_self.copyWith(
participantSid: null == participantSid ? _self.participantSid : participantSid // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isDeafened: null == isDeafened ? _self.isDeafened : isDeafened // ignore: cast_nullable_to_non_nullable
as bool,isLocal: null == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool,isVideoEnabled: freezed == isVideoEnabled ? _self.isVideoEnabled : isVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceParticipant].
extension VoiceParticipantPatterns on VoiceParticipant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceParticipant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceParticipant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceParticipant value)  $default,){
final _that = this;
switch (_that) {
case _VoiceParticipant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceParticipant value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceParticipant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String participantSid,  String userId,  bool isMuted,  bool isSpeaking,  bool isDeafened,  bool isLocal,  bool? isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceParticipant() when $default != null:
return $default(_that.participantSid,_that.userId,_that.isMuted,_that.isSpeaking,_that.isDeafened,_that.isLocal,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String participantSid,  String userId,  bool isMuted,  bool isSpeaking,  bool isDeafened,  bool isLocal,  bool? isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)  $default,) {final _that = this;
switch (_that) {
case _VoiceParticipant():
return $default(_that.participantSid,_that.userId,_that.isMuted,_that.isSpeaking,_that.isDeafened,_that.isLocal,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String participantSid,  String userId,  bool isMuted,  bool isSpeaking,  bool isDeafened,  bool isLocal,  bool? isVideoEnabled,  DateTime joinedAt,  String? avatarUrl,  String? displayName)?  $default,) {final _that = this;
switch (_that) {
case _VoiceParticipant() when $default != null:
return $default(_that.participantSid,_that.userId,_that.isMuted,_that.isSpeaking,_that.isDeafened,_that.isLocal,_that.isVideoEnabled,_that.joinedAt,_that.avatarUrl,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceParticipant implements VoiceParticipant {
  const _VoiceParticipant({required this.participantSid, required this.userId, this.isMuted = false, this.isSpeaking = false, this.isDeafened = false, this.isLocal = false, this.isVideoEnabled = null, required this.joinedAt, this.avatarUrl, this.displayName});
  factory _VoiceParticipant.fromJson(Map<String, dynamic> json) => _$VoiceParticipantFromJson(json);

@override final  String participantSid;
// LiveKit SID
@override final  String userId;
// Supabase user ID
@override@JsonKey() final  bool isMuted;
@override@JsonKey() final  bool isSpeaking;
// Local or Remote detection
@override@JsonKey() final  bool isDeafened;
@override@JsonKey() final  bool isLocal;
@override@JsonKey() final  bool? isVideoEnabled;
// Future proofing
@override final  DateTime joinedAt;
@override final  String? avatarUrl;
@override final  String? displayName;

/// Create a copy of VoiceParticipant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceParticipantCopyWith<_VoiceParticipant> get copyWith => __$VoiceParticipantCopyWithImpl<_VoiceParticipant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceParticipantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceParticipant&&(identical(other.participantSid, participantSid) || other.participantSid == participantSid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isSpeaking, isSpeaking) || other.isSpeaking == isSpeaking)&&(identical(other.isDeafened, isDeafened) || other.isDeafened == isDeafened)&&(identical(other.isLocal, isLocal) || other.isLocal == isLocal)&&(identical(other.isVideoEnabled, isVideoEnabled) || other.isVideoEnabled == isVideoEnabled)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,participantSid,userId,isMuted,isSpeaking,isDeafened,isLocal,isVideoEnabled,joinedAt,avatarUrl,displayName);

@override
String toString() {
  return 'VoiceParticipant(participantSid: $participantSid, userId: $userId, isMuted: $isMuted, isSpeaking: $isSpeaking, isDeafened: $isDeafened, isLocal: $isLocal, isVideoEnabled: $isVideoEnabled, joinedAt: $joinedAt, avatarUrl: $avatarUrl, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$VoiceParticipantCopyWith<$Res> implements $VoiceParticipantCopyWith<$Res> {
  factory _$VoiceParticipantCopyWith(_VoiceParticipant value, $Res Function(_VoiceParticipant) _then) = __$VoiceParticipantCopyWithImpl;
@override @useResult
$Res call({
 String participantSid, String userId, bool isMuted, bool isSpeaking, bool isDeafened, bool isLocal, bool? isVideoEnabled, DateTime joinedAt, String? avatarUrl, String? displayName
});




}
/// @nodoc
class __$VoiceParticipantCopyWithImpl<$Res>
    implements _$VoiceParticipantCopyWith<$Res> {
  __$VoiceParticipantCopyWithImpl(this._self, this._then);

  final _VoiceParticipant _self;
  final $Res Function(_VoiceParticipant) _then;

/// Create a copy of VoiceParticipant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? participantSid = null,Object? userId = null,Object? isMuted = null,Object? isSpeaking = null,Object? isDeafened = null,Object? isLocal = null,Object? isVideoEnabled = freezed,Object? joinedAt = null,Object? avatarUrl = freezed,Object? displayName = freezed,}) {
  return _then(_VoiceParticipant(
participantSid: null == participantSid ? _self.participantSid : participantSid // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isDeafened: null == isDeafened ? _self.isDeafened : isDeafened // ignore: cast_nullable_to_non_nullable
as bool,isLocal: null == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool,isVideoEnabled: freezed == isVideoEnabled ? _self.isVideoEnabled : isVideoEnabled // ignore: cast_nullable_to_non_nullable
as bool?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
