// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'servers_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServersState {

 List<ServerModel> get servers; List<ChannelModel> get selectedServerChannels; String? get selectedServerId;// null means "Home" view
 bool get isLoading; String? get errorMessage;
/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServersStateCopyWith<ServersState> get copyWith => _$ServersStateCopyWithImpl<ServersState>(this as ServersState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServersState&&const DeepCollectionEquality().equals(other.servers, servers)&&const DeepCollectionEquality().equals(other.selectedServerChannels, selectedServerChannels)&&(identical(other.selectedServerId, selectedServerId) || other.selectedServerId == selectedServerId)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(servers),const DeepCollectionEquality().hash(selectedServerChannels),selectedServerId,isLoading,errorMessage);

@override
String toString() {
  return 'ServersState(servers: $servers, selectedServerChannels: $selectedServerChannels, selectedServerId: $selectedServerId, isLoading: $isLoading, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $ServersStateCopyWith<$Res>  {
  factory $ServersStateCopyWith(ServersState value, $Res Function(ServersState) _then) = _$ServersStateCopyWithImpl;
@useResult
$Res call({
 List<ServerModel> servers, List<ChannelModel> selectedServerChannels, String? selectedServerId, bool isLoading, String? errorMessage
});




}
/// @nodoc
class _$ServersStateCopyWithImpl<$Res>
    implements $ServersStateCopyWith<$Res> {
  _$ServersStateCopyWithImpl(this._self, this._then);

  final ServersState _self;
  final $Res Function(ServersState) _then;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? servers = null,Object? selectedServerChannels = null,Object? selectedServerId = freezed,Object? isLoading = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<ServerModel>,selectedServerChannels: null == selectedServerChannels ? _self.selectedServerChannels : selectedServerChannels // ignore: cast_nullable_to_non_nullable
as List<ChannelModel>,selectedServerId: freezed == selectedServerId ? _self.selectedServerId : selectedServerId // ignore: cast_nullable_to_non_nullable
as String?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServersState].
extension ServersStatePatterns on ServersState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServersState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServersState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServersState value)  $default,){
final _that = this;
switch (_that) {
case _ServersState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServersState value)?  $default,){
final _that = this;
switch (_that) {
case _ServersState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ServerModel> servers,  List<ChannelModel> selectedServerChannels,  String? selectedServerId,  bool isLoading,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServersState() when $default != null:
return $default(_that.servers,_that.selectedServerChannels,_that.selectedServerId,_that.isLoading,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ServerModel> servers,  List<ChannelModel> selectedServerChannels,  String? selectedServerId,  bool isLoading,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _ServersState():
return $default(_that.servers,_that.selectedServerChannels,_that.selectedServerId,_that.isLoading,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ServerModel> servers,  List<ChannelModel> selectedServerChannels,  String? selectedServerId,  bool isLoading,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _ServersState() when $default != null:
return $default(_that.servers,_that.selectedServerChannels,_that.selectedServerId,_that.isLoading,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _ServersState implements ServersState {
  const _ServersState({final  List<ServerModel> servers = const [], final  List<ChannelModel> selectedServerChannels = const [], this.selectedServerId, this.isLoading = false, this.errorMessage}): _servers = servers,_selectedServerChannels = selectedServerChannels;
  

 final  List<ServerModel> _servers;
@override@JsonKey() List<ServerModel> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}

 final  List<ChannelModel> _selectedServerChannels;
@override@JsonKey() List<ChannelModel> get selectedServerChannels {
  if (_selectedServerChannels is EqualUnmodifiableListView) return _selectedServerChannels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedServerChannels);
}

@override final  String? selectedServerId;
// null means "Home" view
@override@JsonKey() final  bool isLoading;
@override final  String? errorMessage;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServersStateCopyWith<_ServersState> get copyWith => __$ServersStateCopyWithImpl<_ServersState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServersState&&const DeepCollectionEquality().equals(other._servers, _servers)&&const DeepCollectionEquality().equals(other._selectedServerChannels, _selectedServerChannels)&&(identical(other.selectedServerId, selectedServerId) || other.selectedServerId == selectedServerId)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_servers),const DeepCollectionEquality().hash(_selectedServerChannels),selectedServerId,isLoading,errorMessage);

@override
String toString() {
  return 'ServersState(servers: $servers, selectedServerChannels: $selectedServerChannels, selectedServerId: $selectedServerId, isLoading: $isLoading, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$ServersStateCopyWith<$Res> implements $ServersStateCopyWith<$Res> {
  factory _$ServersStateCopyWith(_ServersState value, $Res Function(_ServersState) _then) = __$ServersStateCopyWithImpl;
@override @useResult
$Res call({
 List<ServerModel> servers, List<ChannelModel> selectedServerChannels, String? selectedServerId, bool isLoading, String? errorMessage
});




}
/// @nodoc
class __$ServersStateCopyWithImpl<$Res>
    implements _$ServersStateCopyWith<$Res> {
  __$ServersStateCopyWithImpl(this._self, this._then);

  final _ServersState _self;
  final $Res Function(_ServersState) _then;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? servers = null,Object? selectedServerChannels = null,Object? selectedServerId = freezed,Object? isLoading = null,Object? errorMessage = freezed,}) {
  return _then(_ServersState(
servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<ServerModel>,selectedServerChannels: null == selectedServerChannels ? _self._selectedServerChannels : selectedServerChannels // ignore: cast_nullable_to_non_nullable
as List<ChannelModel>,selectedServerId: freezed == selectedServerId ? _self.selectedServerId : selectedServerId // ignore: cast_nullable_to_non_nullable
as String?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
