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
  Participant get participant;
  VideoTrack? get videoTrack;
  VideoTrack? get screenShareTrack;
  AudioTrack? get audioTrack;
  bool get isSpeaking;
  bool get isMuted;

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
            (identical(other.participant, participant) ||
                other.participant == participant) &&
            (identical(other.videoTrack, videoTrack) ||
                other.videoTrack == videoTrack) &&
            (identical(other.screenShareTrack, screenShareTrack) ||
                other.screenShareTrack == screenShareTrack) &&
            (identical(other.audioTrack, audioTrack) ||
                other.audioTrack == audioTrack) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted));
  }

  @override
  int get hashCode => Object.hash(runtimeType, participant, videoTrack,
      screenShareTrack, audioTrack, isSpeaking, isMuted);

  @override
  String toString() {
    return 'ParticipantState(participant: $participant, videoTrack: $videoTrack, screenShareTrack: $screenShareTrack, audioTrack: $audioTrack, isSpeaking: $isSpeaking, isMuted: $isMuted)';
  }
}

/// @nodoc
abstract mixin class $ParticipantStateCopyWith<$Res> {
  factory $ParticipantStateCopyWith(
          ParticipantState value, $Res Function(ParticipantState) _then) =
      _$ParticipantStateCopyWithImpl;
  @useResult
  $Res call(
      {Participant participant,
      VideoTrack? videoTrack,
      VideoTrack? screenShareTrack,
      AudioTrack? audioTrack,
      bool isSpeaking,
      bool isMuted});
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
    Object? participant = null,
    Object? videoTrack = freezed,
    Object? screenShareTrack = freezed,
    Object? audioTrack = freezed,
    Object? isSpeaking = null,
    Object? isMuted = null,
  }) {
    return _then(_self.copyWith(
      participant: null == participant
          ? _self.participant
          : participant // ignore: cast_nullable_to_non_nullable
              as Participant,
      videoTrack: freezed == videoTrack
          ? _self.videoTrack
          : videoTrack // ignore: cast_nullable_to_non_nullable
              as VideoTrack?,
      screenShareTrack: freezed == screenShareTrack
          ? _self.screenShareTrack
          : screenShareTrack // ignore: cast_nullable_to_non_nullable
              as VideoTrack?,
      audioTrack: freezed == audioTrack
          ? _self.audioTrack
          : audioTrack // ignore: cast_nullable_to_non_nullable
              as AudioTrack?,
      isSpeaking: null == isSpeaking
          ? _self.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
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
            Participant participant,
            VideoTrack? videoTrack,
            VideoTrack? screenShareTrack,
            AudioTrack? audioTrack,
            bool isSpeaking,
            bool isMuted)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(
            _that.participant,
            _that.videoTrack,
            _that.screenShareTrack,
            _that.audioTrack,
            _that.isSpeaking,
            _that.isMuted);
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
            Participant participant,
            VideoTrack? videoTrack,
            VideoTrack? screenShareTrack,
            AudioTrack? audioTrack,
            bool isSpeaking,
            bool isMuted)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState():
        return $default(
            _that.participant,
            _that.videoTrack,
            _that.screenShareTrack,
            _that.audioTrack,
            _that.isSpeaking,
            _that.isMuted);
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
            Participant participant,
            VideoTrack? videoTrack,
            VideoTrack? screenShareTrack,
            AudioTrack? audioTrack,
            bool isSpeaking,
            bool isMuted)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ParticipantState() when $default != null:
        return $default(
            _that.participant,
            _that.videoTrack,
            _that.screenShareTrack,
            _that.audioTrack,
            _that.isSpeaking,
            _that.isMuted);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ParticipantState implements ParticipantState {
  const _ParticipantState(
      {required this.participant,
      this.videoTrack,
      this.screenShareTrack,
      this.audioTrack,
      this.isSpeaking = false,
      this.isMuted = false});

  @override
  final Participant participant;
  @override
  final VideoTrack? videoTrack;
  @override
  final VideoTrack? screenShareTrack;
  @override
  final AudioTrack? audioTrack;
  @override
  @JsonKey()
  final bool isSpeaking;
  @override
  @JsonKey()
  final bool isMuted;

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
            (identical(other.participant, participant) ||
                other.participant == participant) &&
            (identical(other.videoTrack, videoTrack) ||
                other.videoTrack == videoTrack) &&
            (identical(other.screenShareTrack, screenShareTrack) ||
                other.screenShareTrack == screenShareTrack) &&
            (identical(other.audioTrack, audioTrack) ||
                other.audioTrack == audioTrack) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted));
  }

  @override
  int get hashCode => Object.hash(runtimeType, participant, videoTrack,
      screenShareTrack, audioTrack, isSpeaking, isMuted);

  @override
  String toString() {
    return 'ParticipantState(participant: $participant, videoTrack: $videoTrack, screenShareTrack: $screenShareTrack, audioTrack: $audioTrack, isSpeaking: $isSpeaking, isMuted: $isMuted)';
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
      {Participant participant,
      VideoTrack? videoTrack,
      VideoTrack? screenShareTrack,
      AudioTrack? audioTrack,
      bool isSpeaking,
      bool isMuted});
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
    Object? participant = null,
    Object? videoTrack = freezed,
    Object? screenShareTrack = freezed,
    Object? audioTrack = freezed,
    Object? isSpeaking = null,
    Object? isMuted = null,
  }) {
    return _then(_ParticipantState(
      participant: null == participant
          ? _self.participant
          : participant // ignore: cast_nullable_to_non_nullable
              as Participant,
      videoTrack: freezed == videoTrack
          ? _self.videoTrack
          : videoTrack // ignore: cast_nullable_to_non_nullable
              as VideoTrack?,
      screenShareTrack: freezed == screenShareTrack
          ? _self.screenShareTrack
          : screenShareTrack // ignore: cast_nullable_to_non_nullable
              as VideoTrack?,
      audioTrack: freezed == audioTrack
          ? _self.audioTrack
          : audioTrack // ignore: cast_nullable_to_non_nullable
              as AudioTrack?,
      isSpeaking: null == isSpeaking
          ? _self.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
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
    TResult Function(Room room, Map<String, ParticipantState> participants)?
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
        return connected(_that.room, _that.participants);
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
            Room room, Map<String, ParticipantState> participants)
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
        return connected(_that.room, _that.participants);
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
    TResult? Function(Room room, Map<String, ParticipantState> participants)?
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
        return connected(_that.room, _that.participants);
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
      {required this.room,
      required final Map<String, ParticipantState> participants})
      : _participants = participants;

  final Room room;
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
            (identical(other.room, room) || other.room == room) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, room, const DeepCollectionEquality().hash(_participants));

  @override
  String toString() {
    return 'RoomState.connected(room: $room, participants: $participants)';
  }
}

/// @nodoc
abstract mixin class _$ConnectedCopyWith<$Res>
    implements $RoomStateCopyWith<$Res> {
  factory _$ConnectedCopyWith(
          _Connected value, $Res Function(_Connected) _then) =
      __$ConnectedCopyWithImpl;
  @useResult
  $Res call({Room room, Map<String, ParticipantState> participants});
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
    Object? room = null,
    Object? participants = null,
  }) {
    return _then(_Connected(
      room: null == room
          ? _self.room
          : room // ignore: cast_nullable_to_non_nullable
              as Room,
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
