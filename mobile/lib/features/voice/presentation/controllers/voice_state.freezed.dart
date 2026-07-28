// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceState {
  Room? get room;
  bool get isConnected;
  bool get isConnecting;
  bool get isMuted;
  bool get isDeafened;
  List<Participant> get participants;
  Set<String> get speakingParticipants; // Set of sids who are speaking
  Map<String, double>
      get participantVolumes; // Map of sid/identity -> volume (0.0 to 2.0)
  int get trackVersion;
  List<Map<String, String>> get chatMessages;
  String? get error;
  String? get activeChannelId;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VoiceStateCopyWith<VoiceState> get copyWith =>
      _$VoiceStateCopyWithImpl<VoiceState>(this as VoiceState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VoiceState &&
            (identical(other.room, room) || other.room == room) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.isConnecting, isConnecting) ||
                other.isConnecting == isConnecting) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isDeafened, isDeafened) ||
                other.isDeafened == isDeafened) &&
            const DeepCollectionEquality()
                .equals(other.participants, participants) &&
            const DeepCollectionEquality()
                .equals(other.speakingParticipants, speakingParticipants) &&
            const DeepCollectionEquality()
                .equals(other.participantVolumes, participantVolumes) &&
            (identical(other.trackVersion, trackVersion) ||
                other.trackVersion == trackVersion) &&
            const DeepCollectionEquality()
                .equals(other.chatMessages, chatMessages) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.activeChannelId, activeChannelId) ||
                other.activeChannelId == activeChannelId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      room,
      isConnected,
      isConnecting,
      isMuted,
      isDeafened,
      const DeepCollectionEquality().hash(participants),
      const DeepCollectionEquality().hash(speakingParticipants),
      const DeepCollectionEquality().hash(participantVolumes),
      trackVersion,
      const DeepCollectionEquality().hash(chatMessages),
      error,
      activeChannelId);

  @override
  String toString() {
    return 'VoiceState(room: $room, isConnected: $isConnected, isConnecting: $isConnecting, isMuted: $isMuted, isDeafened: $isDeafened, participants: $participants, speakingParticipants: $speakingParticipants, participantVolumes: $participantVolumes, trackVersion: $trackVersion, chatMessages: $chatMessages, error: $error, activeChannelId: $activeChannelId)';
  }
}

/// @nodoc
abstract mixin class $VoiceStateCopyWith<$Res> {
  factory $VoiceStateCopyWith(
          VoiceState value, $Res Function(VoiceState) _then) =
      _$VoiceStateCopyWithImpl;
  @useResult
  $Res call(
      {Room? room,
      bool isConnected,
      bool isConnecting,
      bool isMuted,
      bool isDeafened,
      List<Participant> participants,
      Set<String> speakingParticipants,
      Map<String, double> participantVolumes,
      int trackVersion,
      List<Map<String, String>> chatMessages,
      String? error,
      String? activeChannelId});
}

/// @nodoc
class _$VoiceStateCopyWithImpl<$Res> implements $VoiceStateCopyWith<$Res> {
  _$VoiceStateCopyWithImpl(this._self, this._then);

  final VoiceState _self;
  final $Res Function(VoiceState) _then;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? room = freezed,
    Object? isConnected = null,
    Object? isConnecting = null,
    Object? isMuted = null,
    Object? isDeafened = null,
    Object? participants = null,
    Object? speakingParticipants = null,
    Object? participantVolumes = null,
    Object? trackVersion = null,
    Object? chatMessages = null,
    Object? error = freezed,
    Object? activeChannelId = freezed,
  }) {
    return _then(_self.copyWith(
      room: freezed == room
          ? _self.room
          : room // ignore: cast_nullable_to_non_nullable
              as Room?,
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnecting: null == isConnecting
          ? _self.isConnecting
          : isConnecting // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeafened: null == isDeafened
          ? _self.isDeafened
          : isDeafened // ignore: cast_nullable_to_non_nullable
              as bool,
      participants: null == participants
          ? _self.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<Participant>,
      speakingParticipants: null == speakingParticipants
          ? _self.speakingParticipants
          : speakingParticipants // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      participantVolumes: null == participantVolumes
          ? _self.participantVolumes
          : participantVolumes // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      trackVersion: null == trackVersion
          ? _self.trackVersion
          : trackVersion // ignore: cast_nullable_to_non_nullable
              as int,
      chatMessages: null == chatMessages
          ? _self.chatMessages
          : chatMessages // ignore: cast_nullable_to_non_nullable
              as List<Map<String, String>>,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      activeChannelId: freezed == activeChannelId
          ? _self.activeChannelId
          : activeChannelId // ignore: cast_nullable_to_non_nullable
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_VoiceState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VoiceState() when $default != null:
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
    TResult Function(_VoiceState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VoiceState():
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
    TResult? Function(_VoiceState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VoiceState() when $default != null:
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
            Room? room,
            bool isConnected,
            bool isConnecting,
            bool isMuted,
            bool isDeafened,
            List<Participant> participants,
            Set<String> speakingParticipants,
            Map<String, double> participantVolumes,
            int trackVersion,
            List<Map<String, String>> chatMessages,
            String? error,
            String? activeChannelId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VoiceState() when $default != null:
        return $default(
            _that.room,
            _that.isConnected,
            _that.isConnecting,
            _that.isMuted,
            _that.isDeafened,
            _that.participants,
            _that.speakingParticipants,
            _that.participantVolumes,
            _that.trackVersion,
            _that.chatMessages,
            _that.error,
            _that.activeChannelId);
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
            Room? room,
            bool isConnected,
            bool isConnecting,
            bool isMuted,
            bool isDeafened,
            List<Participant> participants,
            Set<String> speakingParticipants,
            Map<String, double> participantVolumes,
            int trackVersion,
            List<Map<String, String>> chatMessages,
            String? error,
            String? activeChannelId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VoiceState():
        return $default(
            _that.room,
            _that.isConnected,
            _that.isConnecting,
            _that.isMuted,
            _that.isDeafened,
            _that.participants,
            _that.speakingParticipants,
            _that.participantVolumes,
            _that.trackVersion,
            _that.chatMessages,
            _that.error,
            _that.activeChannelId);
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
            Room? room,
            bool isConnected,
            bool isConnecting,
            bool isMuted,
            bool isDeafened,
            List<Participant> participants,
            Set<String> speakingParticipants,
            Map<String, double> participantVolumes,
            int trackVersion,
            List<Map<String, String>> chatMessages,
            String? error,
            String? activeChannelId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VoiceState() when $default != null:
        return $default(
            _that.room,
            _that.isConnected,
            _that.isConnecting,
            _that.isMuted,
            _that.isDeafened,
            _that.participants,
            _that.speakingParticipants,
            _that.participantVolumes,
            _that.trackVersion,
            _that.chatMessages,
            _that.error,
            _that.activeChannelId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _VoiceState implements VoiceState {
  const _VoiceState(
      {this.room,
      this.isConnected = false,
      this.isConnecting = false,
      this.isMuted = false,
      this.isDeafened = false,
      final List<Participant> participants = const [],
      final Set<String> speakingParticipants = const {},
      final Map<String, double> participantVolumes = const {},
      this.trackVersion = 0,
      final List<Map<String, String>> chatMessages = const [],
      this.error,
      this.activeChannelId})
      : _participants = participants,
        _speakingParticipants = speakingParticipants,
        _participantVolumes = participantVolumes,
        _chatMessages = chatMessages;

  @override
  final Room? room;
  @override
  @JsonKey()
  final bool isConnected;
  @override
  @JsonKey()
  final bool isConnecting;
  @override
  @JsonKey()
  final bool isMuted;
  @override
  @JsonKey()
  final bool isDeafened;
  final List<Participant> _participants;
  @override
  @JsonKey()
  List<Participant> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  final Set<String> _speakingParticipants;
  @override
  @JsonKey()
  Set<String> get speakingParticipants {
    if (_speakingParticipants is EqualUnmodifiableSetView)
      return _speakingParticipants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_speakingParticipants);
  }

// Set of sids who are speaking
  final Map<String, double> _participantVolumes;
// Set of sids who are speaking
  @override
  @JsonKey()
  Map<String, double> get participantVolumes {
    if (_participantVolumes is EqualUnmodifiableMapView)
      return _participantVolumes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_participantVolumes);
  }

// Map of sid/identity -> volume (0.0 to 2.0)
  @override
  @JsonKey()
  final int trackVersion;
  final List<Map<String, String>> _chatMessages;
  @override
  @JsonKey()
  List<Map<String, String>> get chatMessages {
    if (_chatMessages is EqualUnmodifiableListView) return _chatMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chatMessages);
  }

  @override
  final String? error;
  @override
  final String? activeChannelId;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VoiceStateCopyWith<_VoiceState> get copyWith =>
      __$VoiceStateCopyWithImpl<_VoiceState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VoiceState &&
            (identical(other.room, room) || other.room == room) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.isConnecting, isConnecting) ||
                other.isConnecting == isConnecting) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isDeafened, isDeafened) ||
                other.isDeafened == isDeafened) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            const DeepCollectionEquality()
                .equals(other._speakingParticipants, _speakingParticipants) &&
            const DeepCollectionEquality()
                .equals(other._participantVolumes, _participantVolumes) &&
            (identical(other.trackVersion, trackVersion) ||
                other.trackVersion == trackVersion) &&
            const DeepCollectionEquality()
                .equals(other._chatMessages, _chatMessages) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.activeChannelId, activeChannelId) ||
                other.activeChannelId == activeChannelId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      room,
      isConnected,
      isConnecting,
      isMuted,
      isDeafened,
      const DeepCollectionEquality().hash(_participants),
      const DeepCollectionEquality().hash(_speakingParticipants),
      const DeepCollectionEquality().hash(_participantVolumes),
      trackVersion,
      const DeepCollectionEquality().hash(_chatMessages),
      error,
      activeChannelId);

  @override
  String toString() {
    return 'VoiceState(room: $room, isConnected: $isConnected, isConnecting: $isConnecting, isMuted: $isMuted, isDeafened: $isDeafened, participants: $participants, speakingParticipants: $speakingParticipants, participantVolumes: $participantVolumes, trackVersion: $trackVersion, chatMessages: $chatMessages, error: $error, activeChannelId: $activeChannelId)';
  }
}

/// @nodoc
abstract mixin class _$VoiceStateCopyWith<$Res>
    implements $VoiceStateCopyWith<$Res> {
  factory _$VoiceStateCopyWith(
          _VoiceState value, $Res Function(_VoiceState) _then) =
      __$VoiceStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Room? room,
      bool isConnected,
      bool isConnecting,
      bool isMuted,
      bool isDeafened,
      List<Participant> participants,
      Set<String> speakingParticipants,
      Map<String, double> participantVolumes,
      int trackVersion,
      List<Map<String, String>> chatMessages,
      String? error,
      String? activeChannelId});
}

/// @nodoc
class __$VoiceStateCopyWithImpl<$Res> implements _$VoiceStateCopyWith<$Res> {
  __$VoiceStateCopyWithImpl(this._self, this._then);

  final _VoiceState _self;
  final $Res Function(_VoiceState) _then;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? room = freezed,
    Object? isConnected = null,
    Object? isConnecting = null,
    Object? isMuted = null,
    Object? isDeafened = null,
    Object? participants = null,
    Object? speakingParticipants = null,
    Object? participantVolumes = null,
    Object? trackVersion = null,
    Object? chatMessages = null,
    Object? error = freezed,
    Object? activeChannelId = freezed,
  }) {
    return _then(_VoiceState(
      room: freezed == room
          ? _self.room
          : room // ignore: cast_nullable_to_non_nullable
              as Room?,
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnecting: null == isConnecting
          ? _self.isConnecting
          : isConnecting // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeafened: null == isDeafened
          ? _self.isDeafened
          : isDeafened // ignore: cast_nullable_to_non_nullable
              as bool,
      participants: null == participants
          ? _self._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<Participant>,
      speakingParticipants: null == speakingParticipants
          ? _self._speakingParticipants
          : speakingParticipants // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      participantVolumes: null == participantVolumes
          ? _self._participantVolumes
          : participantVolumes // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      trackVersion: null == trackVersion
          ? _self.trackVersion
          : trackVersion // ignore: cast_nullable_to_non_nullable
              as int,
      chatMessages: null == chatMessages
          ? _self._chatMessages
          : chatMessages // ignore: cast_nullable_to_non_nullable
              as List<Map<String, String>>,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      activeChannelId: freezed == activeChannelId
          ? _self.activeChannelId
          : activeChannelId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
