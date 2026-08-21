// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'participant_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ParticipantState {
  String get id;
  String get name;
  RTCVideoRenderer? get videoRenderer;
  RTCVideoRenderer? get screenShareRenderer;
  bool get hasVideo;
  bool get isSpeaking;
  bool get isMuted;
  bool get isScreenSharing;

  /// Create a copy of ParticipantState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ParticipantStateCopyWith<ParticipantState> get copyWith =>
      _$ParticipantStateCopyWithImpl<ParticipantState>(
          this as ParticipantState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ParticipantState &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.videoRenderer, videoRenderer) ||
                other.videoRenderer == videoRenderer) &&
            (identical(other.screenShareRenderer, screenShareRenderer) ||
                other.screenShareRenderer == screenShareRenderer) &&
            (identical(other.hasVideo, hasVideo) ||
                other.hasVideo == hasVideo) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isScreenSharing, isScreenSharing) ||
                other.isScreenSharing == isScreenSharing));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, videoRenderer,
      screenShareRenderer, hasVideo, isSpeaking, isMuted, isScreenSharing);

  @override
  String toString() {
    return 'ParticipantState(id: $id, name: $name, videoRenderer: $videoRenderer, screenShareRenderer: $screenShareRenderer, hasVideo: $hasVideo, isSpeaking: $isSpeaking, isMuted: $isMuted, isScreenSharing: $isScreenSharing)';
  }
}

/// @nodoc
abstract mixin class $ParticipantStateCopyWith<$Res> {
  factory $ParticipantStateCopyWith(
          ParticipantState value, $Res Function(ParticipantState) _then) =
      _$ParticipantStateCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      RTCVideoRenderer? videoRenderer,
      RTCVideoRenderer? screenShareRenderer,
      bool hasVideo,
      bool isSpeaking,
      bool isMuted,
      bool isScreenSharing});
}

/// @nodoc
class _$ParticipantStateCopyWithImpl<$Res>
    implements $ParticipantStateCopyWith<$Res> {
  _$ParticipantStateCopyWithImpl(this._self, this._then);

  final ParticipantState _self;
  final $Res Function(ParticipantState) _then;

  /// Create a copy of ParticipantState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? videoRenderer = freezed,
    Object? screenShareRenderer = freezed,
    Object? hasVideo = null,
    Object? isSpeaking = null,
    Object? isMuted = null,
    Object? isScreenSharing = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      videoRenderer: freezed == videoRenderer
          ? _self.videoRenderer
          : videoRenderer // ignore: cast_nullable_to_non_nullable
              as RTCVideoRenderer?,
      screenShareRenderer: freezed == screenShareRenderer
          ? _self.screenShareRenderer
          : screenShareRenderer // ignore: cast_nullable_to_non_nullable
              as RTCVideoRenderer?,
      hasVideo: null == hasVideo
          ? _self.hasVideo
          : hasVideo // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _self.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isScreenSharing: null == isScreenSharing
          ? _self.isScreenSharing
          : isScreenSharing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [ParticipantState].
extension ParticipantStatePatterns on ParticipantState {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ParticipantState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ParticipantState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ParticipantState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String name,
            RTCVideoRenderer? videoRenderer,
            RTCVideoRenderer? screenShareRenderer,
            bool hasVideo,
            bool isSpeaking,
            bool isMuted,
            bool isScreenSharing)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.videoRenderer,
            _that.screenShareRenderer,
            _that.hasVideo,
            _that.isSpeaking,
            _that.isMuted,
            _that.isScreenSharing);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String name,
            RTCVideoRenderer? videoRenderer,
            RTCVideoRenderer? screenShareRenderer,
            bool hasVideo,
            bool isSpeaking,
            bool isMuted,
            bool isScreenSharing)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState():
        return $default(
            _that.id,
            _that.name,
            _that.videoRenderer,
            _that.screenShareRenderer,
            _that.hasVideo,
            _that.isSpeaking,
            _that.isMuted,
            _that.isScreenSharing);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String name,
            RTCVideoRenderer? videoRenderer,
            RTCVideoRenderer? screenShareRenderer,
            bool hasVideo,
            bool isSpeaking,
            bool isMuted,
            bool isScreenSharing)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.videoRenderer,
            _that.screenShareRenderer,
            _that.hasVideo,
            _that.isSpeaking,
            _that.isMuted,
            _that.isScreenSharing);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ParticipantState implements ParticipantState {
  const _ParticipantState(
      {required this.id,
      required this.name,
      this.videoRenderer,
      this.screenShareRenderer,
      this.hasVideo = false,
      this.isSpeaking = false,
      this.isMuted = false,
      this.isScreenSharing = false});

  @override
  final String id;
  @override
  final String name;
  @override
  final RTCVideoRenderer? videoRenderer;
  @override
  final RTCVideoRenderer? screenShareRenderer;
  @override
  @JsonKey()
  final bool hasVideo;
  @override
  @JsonKey()
  final bool isSpeaking;
  @override
  @JsonKey()
  final bool isMuted;
  @override
  @JsonKey()
  final bool isScreenSharing;

  /// Create a copy of ParticipantState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ParticipantStateCopyWith<_ParticipantState> get copyWith =>
      __$ParticipantStateCopyWithImpl<_ParticipantState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ParticipantState &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.videoRenderer, videoRenderer) ||
                other.videoRenderer == videoRenderer) &&
            (identical(other.screenShareRenderer, screenShareRenderer) ||
                other.screenShareRenderer == screenShareRenderer) &&
            (identical(other.hasVideo, hasVideo) ||
                other.hasVideo == hasVideo) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isScreenSharing, isScreenSharing) ||
                other.isScreenSharing == isScreenSharing));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, videoRenderer,
      screenShareRenderer, hasVideo, isSpeaking, isMuted, isScreenSharing);

  @override
  String toString() {
    return 'ParticipantState(id: $id, name: $name, videoRenderer: $videoRenderer, screenShareRenderer: $screenShareRenderer, hasVideo: $hasVideo, isSpeaking: $isSpeaking, isMuted: $isMuted, isScreenSharing: $isScreenSharing)';
  }
}

/// @nodoc
abstract mixin class _$ParticipantStateCopyWith<$Res>
    implements $ParticipantStateCopyWith<$Res> {
  factory _$ParticipantStateCopyWith(
          _ParticipantState value, $Res Function(_ParticipantState) _then) =
      __$ParticipantStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      RTCVideoRenderer? videoRenderer,
      RTCVideoRenderer? screenShareRenderer,
      bool hasVideo,
      bool isSpeaking,
      bool isMuted,
      bool isScreenSharing});
}

/// @nodoc
class __$ParticipantStateCopyWithImpl<$Res>
    implements _$ParticipantStateCopyWith<$Res> {
  __$ParticipantStateCopyWithImpl(this._self, this._then);

  final _ParticipantState _self;
  final $Res Function(_ParticipantState) _then;

  /// Create a copy of ParticipantState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? videoRenderer = freezed,
    Object? screenShareRenderer = freezed,
    Object? hasVideo = null,
    Object? isSpeaking = null,
    Object? isMuted = null,
    Object? isScreenSharing = null,
  }) {
    return _then(_ParticipantState(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      videoRenderer: freezed == videoRenderer
          ? _self.videoRenderer
          : videoRenderer // ignore: cast_nullable_to_non_nullable
              as RTCVideoRenderer?,
      screenShareRenderer: freezed == screenShareRenderer
          ? _self.screenShareRenderer
          : screenShareRenderer // ignore: cast_nullable_to_non_nullable
              as RTCVideoRenderer?,
      hasVideo: null == hasVideo
          ? _self.hasVideo
          : hasVideo // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _self.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isScreenSharing: null == isScreenSharing
          ? _self.isScreenSharing
          : isScreenSharing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$RoomState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is RoomState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'RoomState()';
  }
}

/// @nodoc
class $RoomStateCopyWith<$Res> {
  $RoomStateCopyWith(RoomState _, $Res Function(RoomState) __);
}

/// Adds pattern-matching-related methods to [RoomState].
extension RoomStatePatterns on RoomState {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Disconnected value)? disconnected,
    TResult Function(_Connecting value)? connecting,
    TResult Function(_Connected value)? connected,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected() when disconnected != null:
        return disconnected(_that);
      case _Connecting() when connecting != null:
        return connecting(_that);
      case _Connected() when connected != null:
        return connected(_that);
      case _Error() when error != null:
        return error(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Disconnected value) disconnected,
    required TResult Function(_Connecting value) connecting,
    required TResult Function(_Connected value) connected,
    required TResult Function(_Error value) error,
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected():
        return disconnected(_that);
      case _Connecting():
        return connecting(_that);
      case _Connected():
        return connected(_that);
      case _Error():
        return error(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Disconnected value)? disconnected,
    TResult? Function(_Connecting value)? connecting,
    TResult? Function(_Connected value)? connected,
    TResult? Function(_Error value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected() when disconnected != null:
        return disconnected(_that);
      case _Connecting() when connecting != null:
        return connecting(_that);
      case _Connected() when connected != null:
        return connected(_that);
      case _Error() when error != null:
        return error(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? disconnected,
    TResult Function()? connecting,
    TResult Function(
            String roomName, Map<String, ParticipantState> participants)?
        connected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected() when disconnected != null:
        return disconnected();
      case _Connecting() when connecting != null:
        return connecting();
      case _Connected() when connected != null:
        return connected(_that.roomName, _that.participants);
      case _Error() when error != null:
        return error(_that.message);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() disconnected,
    required TResult Function() connecting,
    required TResult Function(
            String roomName, Map<String, ParticipantState> participants)
        connected,
    required TResult Function(String message) error,
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected():
        return disconnected();
      case _Connecting():
        return connecting();
      case _Connected():
        return connected(_that.roomName, _that.participants);
      case _Error():
        return error(_that.message);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? disconnected,
    TResult? Function()? connecting,
    TResult? Function(
            String roomName, Map<String, ParticipantState> participants)?
        connected,
    TResult? Function(String message)? error,
  }) {
    final _that = this;
    switch (_that) {
      case _Disconnected() when disconnected != null:
        return disconnected();
      case _Connecting() when connecting != null:
        return connecting();
      case _Connected() when connected != null:
        return connected(_that.roomName, _that.participants);
      case _Error() when error != null:
        return error(_that.message);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Disconnected implements RoomState {
  const _Disconnected();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Disconnected);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'RoomState.disconnected()';
  }
}

/// @nodoc

class _Connecting implements RoomState {
  const _Connecting();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Connecting);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'RoomState.connecting()';
  }
}

/// @nodoc

class _Connected implements RoomState {
  const _Connected(
      {required this.roomName,
      required final Map<String, ParticipantState> participants})
      : _participants = participants;

  final String roomName;
  final Map<String, ParticipantState> _participants;
  Map<String, ParticipantState> get participants {
    if (_participants is EqualUnmodifiableMapView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_participants);
  }

  /// Create a copy of RoomState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConnectedCopyWith<_Connected> get copyWith =>
      __$ConnectedCopyWithImpl<_Connected>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Connected &&
            (identical(other.roomName, roomName) ||
                other.roomName == roomName) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants));
  }

  @override
  int get hashCode => Object.hash(runtimeType, roomName,
      const DeepCollectionEquality().hash(_participants));

  @override
  String toString() {
    return 'RoomState.connected(roomName: $roomName, participants: $participants)';
  }
}

/// @nodoc
abstract mixin class _$ConnectedCopyWith<$Res>
    implements $RoomStateCopyWith<$Res> {
  factory _$ConnectedCopyWith(
          _Connected value, $Res Function(_Connected) _then) =
      __$ConnectedCopyWithImpl;
  @useResult
  $Res call({String roomName, Map<String, ParticipantState> participants});
}

/// @nodoc
class __$ConnectedCopyWithImpl<$Res> implements _$ConnectedCopyWith<$Res> {
  __$ConnectedCopyWithImpl(this._self, this._then);

  final _Connected _self;
  final $Res Function(_Connected) _then;

  /// Create a copy of RoomState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? roomName = null,
    Object? participants = null,
  }) {
    return _then(_Connected(
      roomName: null == roomName
          ? _self.roomName
          : roomName // ignore: cast_nullable_to_non_nullable
              as String,
      participants: null == participants
          ? _self._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as Map<String, ParticipantState>,
    ));
  }
}

/// @nodoc

class _Error implements RoomState {
  const _Error(this.message);

  final String message;

  /// Create a copy of RoomState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErrorCopyWith<_Error> get copyWith =>
      __$ErrorCopyWithImpl<_Error>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Error &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() {
    return 'RoomState.error(message: $message)';
  }
}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $RoomStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) =
      __$ErrorCopyWithImpl;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$ErrorCopyWithImpl<$Res> implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

  /// Create a copy of RoomState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
  }) {
    return _then(_Error(
      null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
