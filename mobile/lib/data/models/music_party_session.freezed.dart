// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'music_party_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MusicPartySettings {
  @JsonKey(name: 'vote_skip_threshold')
  double get voteSkipThreshold;
  @JsonKey(name: 'max_listeners')
  int get maxListeners;
  @JsonKey(name: 'allow_dupes')
  bool get allowDupes;

  /// Create a copy of MusicPartySettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicPartySettingsCopyWith<MusicPartySettings> get copyWith =>
      _$MusicPartySettingsCopyWithImpl<MusicPartySettings>(
          this as MusicPartySettings, _$identity);

  /// Serializes this MusicPartySettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicPartySettings &&
            (identical(other.voteSkipThreshold, voteSkipThreshold) ||
                other.voteSkipThreshold == voteSkipThreshold) &&
            (identical(other.maxListeners, maxListeners) ||
                other.maxListeners == maxListeners) &&
            (identical(other.allowDupes, allowDupes) ||
                other.allowDupes == allowDupes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, voteSkipThreshold, maxListeners, allowDupes);

  @override
  String toString() {
    return 'MusicPartySettings(voteSkipThreshold: $voteSkipThreshold, maxListeners: $maxListeners, allowDupes: $allowDupes)';
  }
}

/// @nodoc
abstract mixin class $MusicPartySettingsCopyWith<$Res> {
  factory $MusicPartySettingsCopyWith(
          MusicPartySettings value, $Res Function(MusicPartySettings) _then) =
      _$MusicPartySettingsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'vote_skip_threshold') double voteSkipThreshold,
      @JsonKey(name: 'max_listeners') int maxListeners,
      @JsonKey(name: 'allow_dupes') bool allowDupes});
}

/// @nodoc
class _$MusicPartySettingsCopyWithImpl<$Res>
    implements $MusicPartySettingsCopyWith<$Res> {
  _$MusicPartySettingsCopyWithImpl(this._self, this._then);

  final MusicPartySettings _self;
  final $Res Function(MusicPartySettings) _then;

  /// Create a copy of MusicPartySettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? voteSkipThreshold = null,
    Object? maxListeners = null,
    Object? allowDupes = null,
  }) {
    return _then(_self.copyWith(
      voteSkipThreshold: null == voteSkipThreshold
          ? _self.voteSkipThreshold
          : voteSkipThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      maxListeners: null == maxListeners
          ? _self.maxListeners
          : maxListeners // ignore: cast_nullable_to_non_nullable
              as int,
      allowDupes: null == allowDupes
          ? _self.allowDupes
          : allowDupes // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [MusicPartySettings].
extension MusicPartySettingsPatterns on MusicPartySettings {
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
    TResult Function(_MusicPartySettings value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings() when $default != null:
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
    TResult Function(_MusicPartySettings value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings():
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
    TResult? Function(_MusicPartySettings value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings() when $default != null:
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
            @JsonKey(name: 'vote_skip_threshold') double voteSkipThreshold,
            @JsonKey(name: 'max_listeners') int maxListeners,
            @JsonKey(name: 'allow_dupes') bool allowDupes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings() when $default != null:
        return $default(
            _that.voteSkipThreshold, _that.maxListeners, _that.allowDupes);
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
            @JsonKey(name: 'vote_skip_threshold') double voteSkipThreshold,
            @JsonKey(name: 'max_listeners') int maxListeners,
            @JsonKey(name: 'allow_dupes') bool allowDupes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings():
        return $default(
            _that.voteSkipThreshold, _that.maxListeners, _that.allowDupes);
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
            @JsonKey(name: 'vote_skip_threshold') double voteSkipThreshold,
            @JsonKey(name: 'max_listeners') int maxListeners,
            @JsonKey(name: 'allow_dupes') bool allowDupes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySettings() when $default != null:
        return $default(
            _that.voteSkipThreshold, _that.maxListeners, _that.allowDupes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicPartySettings implements MusicPartySettings {
  const _MusicPartySettings(
      {@JsonKey(name: 'vote_skip_threshold') this.voteSkipThreshold = 0.5,
      @JsonKey(name: 'max_listeners') this.maxListeners = 25,
      @JsonKey(name: 'allow_dupes') this.allowDupes = true});
  factory _MusicPartySettings.fromJson(Map<String, dynamic> json) =>
      _$MusicPartySettingsFromJson(json);

  @override
  @JsonKey(name: 'vote_skip_threshold')
  final double voteSkipThreshold;
  @override
  @JsonKey(name: 'max_listeners')
  final int maxListeners;
  @override
  @JsonKey(name: 'allow_dupes')
  final bool allowDupes;

  /// Create a copy of MusicPartySettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicPartySettingsCopyWith<_MusicPartySettings> get copyWith =>
      __$MusicPartySettingsCopyWithImpl<_MusicPartySettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicPartySettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicPartySettings &&
            (identical(other.voteSkipThreshold, voteSkipThreshold) ||
                other.voteSkipThreshold == voteSkipThreshold) &&
            (identical(other.maxListeners, maxListeners) ||
                other.maxListeners == maxListeners) &&
            (identical(other.allowDupes, allowDupes) ||
                other.allowDupes == allowDupes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, voteSkipThreshold, maxListeners, allowDupes);

  @override
  String toString() {
    return 'MusicPartySettings(voteSkipThreshold: $voteSkipThreshold, maxListeners: $maxListeners, allowDupes: $allowDupes)';
  }
}

/// @nodoc
abstract mixin class _$MusicPartySettingsCopyWith<$Res>
    implements $MusicPartySettingsCopyWith<$Res> {
  factory _$MusicPartySettingsCopyWith(
          _MusicPartySettings value, $Res Function(_MusicPartySettings) _then) =
      __$MusicPartySettingsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'vote_skip_threshold') double voteSkipThreshold,
      @JsonKey(name: 'max_listeners') int maxListeners,
      @JsonKey(name: 'allow_dupes') bool allowDupes});
}

/// @nodoc
class __$MusicPartySettingsCopyWithImpl<$Res>
    implements _$MusicPartySettingsCopyWith<$Res> {
  __$MusicPartySettingsCopyWithImpl(this._self, this._then);

  final _MusicPartySettings _self;
  final $Res Function(_MusicPartySettings) _then;

  /// Create a copy of MusicPartySettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? voteSkipThreshold = null,
    Object? maxListeners = null,
    Object? allowDupes = null,
  }) {
    return _then(_MusicPartySettings(
      voteSkipThreshold: null == voteSkipThreshold
          ? _self.voteSkipThreshold
          : voteSkipThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      maxListeners: null == maxListeners
          ? _self.maxListeners
          : maxListeners // ignore: cast_nullable_to_non_nullable
              as int,
      allowDupes: null == allowDupes
          ? _self.allowDupes
          : allowDupes // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$MusicPartySession {
  String get id;
  @JsonKey(name: 'room_id')
  String get roomId;
  @JsonKey(name: 'dj_user_id')
  String get djUserId;
  @JsonKey(name: 'next_dj_user_id')
  String? get nextDjUserId;
  @JsonKey(name: 'rotation_mode')
  String get rotationMode;
  String get state;
  @JsonKey(name: 'current_track_uri')
  String? get currentTrackUri;
  @JsonKey(name: 'current_position_ms')
  int get currentPositionMs;
  @JsonKey(name: 'anchor_wall_ms')
  int get anchorWallMs;
  int get seq;
  MusicPartySettings get settings;

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicPartySessionCopyWith<MusicPartySession> get copyWith =>
      _$MusicPartySessionCopyWithImpl<MusicPartySession>(
          this as MusicPartySession, _$identity);

  /// Serializes this MusicPartySession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicPartySession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.djUserId, djUserId) ||
                other.djUserId == djUserId) &&
            (identical(other.nextDjUserId, nextDjUserId) ||
                other.nextDjUserId == nextDjUserId) &&
            (identical(other.rotationMode, rotationMode) ||
                other.rotationMode == rotationMode) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.currentTrackUri, currentTrackUri) ||
                other.currentTrackUri == currentTrackUri) &&
            (identical(other.currentPositionMs, currentPositionMs) ||
                other.currentPositionMs == currentPositionMs) &&
            (identical(other.anchorWallMs, anchorWallMs) ||
                other.anchorWallMs == anchorWallMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.settings, settings) ||
                other.settings == settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomId,
      djUserId,
      nextDjUserId,
      rotationMode,
      state,
      currentTrackUri,
      currentPositionMs,
      anchorWallMs,
      seq,
      settings);

  @override
  String toString() {
    return 'MusicPartySession(id: $id, roomId: $roomId, djUserId: $djUserId, nextDjUserId: $nextDjUserId, rotationMode: $rotationMode, state: $state, currentTrackUri: $currentTrackUri, currentPositionMs: $currentPositionMs, anchorWallMs: $anchorWallMs, seq: $seq, settings: $settings)';
  }
}

/// @nodoc
abstract mixin class $MusicPartySessionCopyWith<$Res> {
  factory $MusicPartySessionCopyWith(
          MusicPartySession value, $Res Function(MusicPartySession) _then) =
      _$MusicPartySessionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'dj_user_id') String djUserId,
      @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
      @JsonKey(name: 'rotation_mode') String rotationMode,
      String state,
      @JsonKey(name: 'current_track_uri') String? currentTrackUri,
      @JsonKey(name: 'current_position_ms') int currentPositionMs,
      @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
      int seq,
      MusicPartySettings settings});

  $MusicPartySettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$MusicPartySessionCopyWithImpl<$Res>
    implements $MusicPartySessionCopyWith<$Res> {
  _$MusicPartySessionCopyWithImpl(this._self, this._then);

  final MusicPartySession _self;
  final $Res Function(MusicPartySession) _then;

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? djUserId = null,
    Object? nextDjUserId = freezed,
    Object? rotationMode = null,
    Object? state = null,
    Object? currentTrackUri = freezed,
    Object? currentPositionMs = null,
    Object? anchorWallMs = null,
    Object? seq = null,
    Object? settings = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      djUserId: null == djUserId
          ? _self.djUserId
          : djUserId // ignore: cast_nullable_to_non_nullable
              as String,
      nextDjUserId: freezed == nextDjUserId
          ? _self.nextDjUserId
          : nextDjUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      rotationMode: null == rotationMode
          ? _self.rotationMode
          : rotationMode // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      currentTrackUri: freezed == currentTrackUri
          ? _self.currentTrackUri
          : currentTrackUri // ignore: cast_nullable_to_non_nullable
              as String?,
      currentPositionMs: null == currentPositionMs
          ? _self.currentPositionMs
          : currentPositionMs // ignore: cast_nullable_to_non_nullable
              as int,
      anchorWallMs: null == anchorWallMs
          ? _self.anchorWallMs
          : anchorWallMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      settings: null == settings
          ? _self.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as MusicPartySettings,
    ));
  }

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartySettingsCopyWith<$Res> get settings {
    return $MusicPartySettingsCopyWith<$Res>(_self.settings, (value) {
      return _then(_self.copyWith(settings: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MusicPartySession].
extension MusicPartySessionPatterns on MusicPartySession {
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
    TResult Function(_MusicPartySession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession() when $default != null:
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
    TResult Function(_MusicPartySession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession():
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
    TResult? Function(_MusicPartySession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession() when $default != null:
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
            @JsonKey(name: 'room_id') String roomId,
            @JsonKey(name: 'dj_user_id') String djUserId,
            @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
            @JsonKey(name: 'rotation_mode') String rotationMode,
            String state,
            @JsonKey(name: 'current_track_uri') String? currentTrackUri,
            @JsonKey(name: 'current_position_ms') int currentPositionMs,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            MusicPartySettings settings)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession() when $default != null:
        return $default(
            _that.id,
            _that.roomId,
            _that.djUserId,
            _that.nextDjUserId,
            _that.rotationMode,
            _that.state,
            _that.currentTrackUri,
            _that.currentPositionMs,
            _that.anchorWallMs,
            _that.seq,
            _that.settings);
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
            @JsonKey(name: 'room_id') String roomId,
            @JsonKey(name: 'dj_user_id') String djUserId,
            @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
            @JsonKey(name: 'rotation_mode') String rotationMode,
            String state,
            @JsonKey(name: 'current_track_uri') String? currentTrackUri,
            @JsonKey(name: 'current_position_ms') int currentPositionMs,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            MusicPartySettings settings)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession():
        return $default(
            _that.id,
            _that.roomId,
            _that.djUserId,
            _that.nextDjUserId,
            _that.rotationMode,
            _that.state,
            _that.currentTrackUri,
            _that.currentPositionMs,
            _that.anchorWallMs,
            _that.seq,
            _that.settings);
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
            @JsonKey(name: 'room_id') String roomId,
            @JsonKey(name: 'dj_user_id') String djUserId,
            @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
            @JsonKey(name: 'rotation_mode') String rotationMode,
            String state,
            @JsonKey(name: 'current_track_uri') String? currentTrackUri,
            @JsonKey(name: 'current_position_ms') int currentPositionMs,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            MusicPartySettings settings)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartySession() when $default != null:
        return $default(
            _that.id,
            _that.roomId,
            _that.djUserId,
            _that.nextDjUserId,
            _that.rotationMode,
            _that.state,
            _that.currentTrackUri,
            _that.currentPositionMs,
            _that.anchorWallMs,
            _that.seq,
            _that.settings);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicPartySession implements MusicPartySession {
  const _MusicPartySession(
      {required this.id,
      @JsonKey(name: 'room_id') required this.roomId,
      @JsonKey(name: 'dj_user_id') required this.djUserId,
      @JsonKey(name: 'next_dj_user_id') this.nextDjUserId,
      @JsonKey(name: 'rotation_mode') this.rotationMode = 'manual',
      required this.state,
      @JsonKey(name: 'current_track_uri') this.currentTrackUri,
      @JsonKey(name: 'current_position_ms') this.currentPositionMs = 0,
      @JsonKey(name: 'anchor_wall_ms') this.anchorWallMs = 0,
      this.seq = 0,
      required this.settings});
  factory _MusicPartySession.fromJson(Map<String, dynamic> json) =>
      _$MusicPartySessionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'room_id')
  final String roomId;
  @override
  @JsonKey(name: 'dj_user_id')
  final String djUserId;
  @override
  @JsonKey(name: 'next_dj_user_id')
  final String? nextDjUserId;
  @override
  @JsonKey(name: 'rotation_mode')
  final String rotationMode;
  @override
  final String state;
  @override
  @JsonKey(name: 'current_track_uri')
  final String? currentTrackUri;
  @override
  @JsonKey(name: 'current_position_ms')
  final int currentPositionMs;
  @override
  @JsonKey(name: 'anchor_wall_ms')
  final int anchorWallMs;
  @override
  @JsonKey()
  final int seq;
  @override
  final MusicPartySettings settings;

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicPartySessionCopyWith<_MusicPartySession> get copyWith =>
      __$MusicPartySessionCopyWithImpl<_MusicPartySession>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicPartySessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicPartySession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.djUserId, djUserId) ||
                other.djUserId == djUserId) &&
            (identical(other.nextDjUserId, nextDjUserId) ||
                other.nextDjUserId == nextDjUserId) &&
            (identical(other.rotationMode, rotationMode) ||
                other.rotationMode == rotationMode) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.currentTrackUri, currentTrackUri) ||
                other.currentTrackUri == currentTrackUri) &&
            (identical(other.currentPositionMs, currentPositionMs) ||
                other.currentPositionMs == currentPositionMs) &&
            (identical(other.anchorWallMs, anchorWallMs) ||
                other.anchorWallMs == anchorWallMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.settings, settings) ||
                other.settings == settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomId,
      djUserId,
      nextDjUserId,
      rotationMode,
      state,
      currentTrackUri,
      currentPositionMs,
      anchorWallMs,
      seq,
      settings);

  @override
  String toString() {
    return 'MusicPartySession(id: $id, roomId: $roomId, djUserId: $djUserId, nextDjUserId: $nextDjUserId, rotationMode: $rotationMode, state: $state, currentTrackUri: $currentTrackUri, currentPositionMs: $currentPositionMs, anchorWallMs: $anchorWallMs, seq: $seq, settings: $settings)';
  }
}

/// @nodoc
abstract mixin class _$MusicPartySessionCopyWith<$Res>
    implements $MusicPartySessionCopyWith<$Res> {
  factory _$MusicPartySessionCopyWith(
          _MusicPartySession value, $Res Function(_MusicPartySession) _then) =
      __$MusicPartySessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'dj_user_id') String djUserId,
      @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
      @JsonKey(name: 'rotation_mode') String rotationMode,
      String state,
      @JsonKey(name: 'current_track_uri') String? currentTrackUri,
      @JsonKey(name: 'current_position_ms') int currentPositionMs,
      @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
      int seq,
      MusicPartySettings settings});

  @override
  $MusicPartySettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$MusicPartySessionCopyWithImpl<$Res>
    implements _$MusicPartySessionCopyWith<$Res> {
  __$MusicPartySessionCopyWithImpl(this._self, this._then);

  final _MusicPartySession _self;
  final $Res Function(_MusicPartySession) _then;

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? djUserId = null,
    Object? nextDjUserId = freezed,
    Object? rotationMode = null,
    Object? state = null,
    Object? currentTrackUri = freezed,
    Object? currentPositionMs = null,
    Object? anchorWallMs = null,
    Object? seq = null,
    Object? settings = null,
  }) {
    return _then(_MusicPartySession(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      djUserId: null == djUserId
          ? _self.djUserId
          : djUserId // ignore: cast_nullable_to_non_nullable
              as String,
      nextDjUserId: freezed == nextDjUserId
          ? _self.nextDjUserId
          : nextDjUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      rotationMode: null == rotationMode
          ? _self.rotationMode
          : rotationMode // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      currentTrackUri: freezed == currentTrackUri
          ? _self.currentTrackUri
          : currentTrackUri // ignore: cast_nullable_to_non_nullable
              as String?,
      currentPositionMs: null == currentPositionMs
          ? _self.currentPositionMs
          : currentPositionMs // ignore: cast_nullable_to_non_nullable
              as int,
      anchorWallMs: null == anchorWallMs
          ? _self.anchorWallMs
          : anchorWallMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      settings: null == settings
          ? _self.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as MusicPartySettings,
    ));
  }

  /// Create a copy of MusicPartySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartySettingsCopyWith<$Res> get settings {
    return $MusicPartySettingsCopyWith<$Res>(_self.settings, (value) {
      return _then(_self.copyWith(settings: value));
    });
  }
}

/// @nodoc
mixin _$MusicPartyQueueItem {
  String get id;
  @JsonKey(name: 'session_id')
  String get sessionId;
  @JsonKey(name: 'spotify_uri')
  String get spotifyUri;
  String? get title;
  String? get artist;
  @JsonKey(name: 'duration_ms')
  int? get durationMs;
  @JsonKey(name: 'album_art_url')
  String? get albumArtUrl;
  @JsonKey(name: 'preview_url')
  String? get previewUrl;
  @JsonKey(name: 'added_by_user_id')
  String get addedByUserId;
  double get position;
  String get state;

  /// Create a copy of MusicPartyQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicPartyQueueItemCopyWith<MusicPartyQueueItem> get copyWith =>
      _$MusicPartyQueueItemCopyWithImpl<MusicPartyQueueItem>(
          this as MusicPartyQueueItem, _$identity);

  /// Serializes this MusicPartyQueueItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicPartyQueueItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.spotifyUri, spotifyUri) ||
                other.spotifyUri == spotifyUri) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.albumArtUrl, albumArtUrl) ||
                other.albumArtUrl == albumArtUrl) &&
            (identical(other.previewUrl, previewUrl) ||
                other.previewUrl == previewUrl) &&
            (identical(other.addedByUserId, addedByUserId) ||
                other.addedByUserId == addedByUserId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      sessionId,
      spotifyUri,
      title,
      artist,
      durationMs,
      albumArtUrl,
      previewUrl,
      addedByUserId,
      position,
      state);

  @override
  String toString() {
    return 'MusicPartyQueueItem(id: $id, sessionId: $sessionId, spotifyUri: $spotifyUri, title: $title, artist: $artist, durationMs: $durationMs, albumArtUrl: $albumArtUrl, previewUrl: $previewUrl, addedByUserId: $addedByUserId, position: $position, state: $state)';
  }
}

/// @nodoc
abstract mixin class $MusicPartyQueueItemCopyWith<$Res> {
  factory $MusicPartyQueueItemCopyWith(
          MusicPartyQueueItem value, $Res Function(MusicPartyQueueItem) _then) =
      _$MusicPartyQueueItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'session_id') String sessionId,
      @JsonKey(name: 'spotify_uri') String spotifyUri,
      String? title,
      String? artist,
      @JsonKey(name: 'duration_ms') int? durationMs,
      @JsonKey(name: 'album_art_url') String? albumArtUrl,
      @JsonKey(name: 'preview_url') String? previewUrl,
      @JsonKey(name: 'added_by_user_id') String addedByUserId,
      double position,
      String state});
}

/// @nodoc
class _$MusicPartyQueueItemCopyWithImpl<$Res>
    implements $MusicPartyQueueItemCopyWith<$Res> {
  _$MusicPartyQueueItemCopyWithImpl(this._self, this._then);

  final MusicPartyQueueItem _self;
  final $Res Function(MusicPartyQueueItem) _then;

  /// Create a copy of MusicPartyQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? spotifyUri = null,
    Object? title = freezed,
    Object? artist = freezed,
    Object? durationMs = freezed,
    Object? albumArtUrl = freezed,
    Object? previewUrl = freezed,
    Object? addedByUserId = null,
    Object? position = null,
    Object? state = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      spotifyUri: null == spotifyUri
          ? _self.spotifyUri
          : spotifyUri // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      artist: freezed == artist
          ? _self.artist
          : artist // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      albumArtUrl: freezed == albumArtUrl
          ? _self.albumArtUrl
          : albumArtUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      previewUrl: freezed == previewUrl
          ? _self.previewUrl
          : previewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      addedByUserId: null == addedByUserId
          ? _self.addedByUserId
          : addedByUserId // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as double,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MusicPartyQueueItem].
extension MusicPartyQueueItemPatterns on MusicPartyQueueItem {
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
    TResult Function(_MusicPartyQueueItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem() when $default != null:
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
    TResult Function(_MusicPartyQueueItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem():
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
    TResult? Function(_MusicPartyQueueItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem() when $default != null:
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
            @JsonKey(name: 'session_id') String sessionId,
            @JsonKey(name: 'spotify_uri') String spotifyUri,
            String? title,
            String? artist,
            @JsonKey(name: 'duration_ms') int? durationMs,
            @JsonKey(name: 'album_art_url') String? albumArtUrl,
            @JsonKey(name: 'preview_url') String? previewUrl,
            @JsonKey(name: 'added_by_user_id') String addedByUserId,
            double position,
            String state)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem() when $default != null:
        return $default(
            _that.id,
            _that.sessionId,
            _that.spotifyUri,
            _that.title,
            _that.artist,
            _that.durationMs,
            _that.albumArtUrl,
            _that.previewUrl,
            _that.addedByUserId,
            _that.position,
            _that.state);
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
            @JsonKey(name: 'session_id') String sessionId,
            @JsonKey(name: 'spotify_uri') String spotifyUri,
            String? title,
            String? artist,
            @JsonKey(name: 'duration_ms') int? durationMs,
            @JsonKey(name: 'album_art_url') String? albumArtUrl,
            @JsonKey(name: 'preview_url') String? previewUrl,
            @JsonKey(name: 'added_by_user_id') String addedByUserId,
            double position,
            String state)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem():
        return $default(
            _that.id,
            _that.sessionId,
            _that.spotifyUri,
            _that.title,
            _that.artist,
            _that.durationMs,
            _that.albumArtUrl,
            _that.previewUrl,
            _that.addedByUserId,
            _that.position,
            _that.state);
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
            @JsonKey(name: 'session_id') String sessionId,
            @JsonKey(name: 'spotify_uri') String spotifyUri,
            String? title,
            String? artist,
            @JsonKey(name: 'duration_ms') int? durationMs,
            @JsonKey(name: 'album_art_url') String? albumArtUrl,
            @JsonKey(name: 'preview_url') String? previewUrl,
            @JsonKey(name: 'added_by_user_id') String addedByUserId,
            double position,
            String state)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyQueueItem() when $default != null:
        return $default(
            _that.id,
            _that.sessionId,
            _that.spotifyUri,
            _that.title,
            _that.artist,
            _that.durationMs,
            _that.albumArtUrl,
            _that.previewUrl,
            _that.addedByUserId,
            _that.position,
            _that.state);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicPartyQueueItem implements MusicPartyQueueItem {
  const _MusicPartyQueueItem(
      {required this.id,
      @JsonKey(name: 'session_id') required this.sessionId,
      @JsonKey(name: 'spotify_uri') required this.spotifyUri,
      this.title,
      this.artist,
      @JsonKey(name: 'duration_ms') this.durationMs,
      @JsonKey(name: 'album_art_url') this.albumArtUrl,
      @JsonKey(name: 'preview_url') this.previewUrl,
      @JsonKey(name: 'added_by_user_id') required this.addedByUserId,
      required this.position,
      this.state = 'queued'});
  factory _MusicPartyQueueItem.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyQueueItemFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'session_id')
  final String sessionId;
  @override
  @JsonKey(name: 'spotify_uri')
  final String spotifyUri;
  @override
  final String? title;
  @override
  final String? artist;
  @override
  @JsonKey(name: 'duration_ms')
  final int? durationMs;
  @override
  @JsonKey(name: 'album_art_url')
  final String? albumArtUrl;
  @override
  @JsonKey(name: 'preview_url')
  final String? previewUrl;
  @override
  @JsonKey(name: 'added_by_user_id')
  final String addedByUserId;
  @override
  final double position;
  @override
  @JsonKey()
  final String state;

  /// Create a copy of MusicPartyQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicPartyQueueItemCopyWith<_MusicPartyQueueItem> get copyWith =>
      __$MusicPartyQueueItemCopyWithImpl<_MusicPartyQueueItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicPartyQueueItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicPartyQueueItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.spotifyUri, spotifyUri) ||
                other.spotifyUri == spotifyUri) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.albumArtUrl, albumArtUrl) ||
                other.albumArtUrl == albumArtUrl) &&
            (identical(other.previewUrl, previewUrl) ||
                other.previewUrl == previewUrl) &&
            (identical(other.addedByUserId, addedByUserId) ||
                other.addedByUserId == addedByUserId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      sessionId,
      spotifyUri,
      title,
      artist,
      durationMs,
      albumArtUrl,
      previewUrl,
      addedByUserId,
      position,
      state);

  @override
  String toString() {
    return 'MusicPartyQueueItem(id: $id, sessionId: $sessionId, spotifyUri: $spotifyUri, title: $title, artist: $artist, durationMs: $durationMs, albumArtUrl: $albumArtUrl, previewUrl: $previewUrl, addedByUserId: $addedByUserId, position: $position, state: $state)';
  }
}

/// @nodoc
abstract mixin class _$MusicPartyQueueItemCopyWith<$Res>
    implements $MusicPartyQueueItemCopyWith<$Res> {
  factory _$MusicPartyQueueItemCopyWith(_MusicPartyQueueItem value,
          $Res Function(_MusicPartyQueueItem) _then) =
      __$MusicPartyQueueItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'session_id') String sessionId,
      @JsonKey(name: 'spotify_uri') String spotifyUri,
      String? title,
      String? artist,
      @JsonKey(name: 'duration_ms') int? durationMs,
      @JsonKey(name: 'album_art_url') String? albumArtUrl,
      @JsonKey(name: 'preview_url') String? previewUrl,
      @JsonKey(name: 'added_by_user_id') String addedByUserId,
      double position,
      String state});
}

/// @nodoc
class __$MusicPartyQueueItemCopyWithImpl<$Res>
    implements _$MusicPartyQueueItemCopyWith<$Res> {
  __$MusicPartyQueueItemCopyWithImpl(this._self, this._then);

  final _MusicPartyQueueItem _self;
  final $Res Function(_MusicPartyQueueItem) _then;

  /// Create a copy of MusicPartyQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? spotifyUri = null,
    Object? title = freezed,
    Object? artist = freezed,
    Object? durationMs = freezed,
    Object? albumArtUrl = freezed,
    Object? previewUrl = freezed,
    Object? addedByUserId = null,
    Object? position = null,
    Object? state = null,
  }) {
    return _then(_MusicPartyQueueItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      spotifyUri: null == spotifyUri
          ? _self.spotifyUri
          : spotifyUri // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      artist: freezed == artist
          ? _self.artist
          : artist // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      albumArtUrl: freezed == albumArtUrl
          ? _self.albumArtUrl
          : albumArtUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      previewUrl: freezed == previewUrl
          ? _self.previewUrl
          : previewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      addedByUserId: null == addedByUserId
          ? _self.addedByUserId
          : addedByUserId // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as double,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$MusicPartyAnchor {
  @JsonKey(name: 'track_uri')
  String get trackUri;
  @JsonKey(name: 'position_ms')
  int get positionMs;
  bool get playing;
  @JsonKey(name: 'wall_clock_ms')
  int get wallClockMs;
  int get seq;
  @JsonKey(name: 'dj_id')
  String get djId;

  /// Create a copy of MusicPartyAnchor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicPartyAnchorCopyWith<MusicPartyAnchor> get copyWith =>
      _$MusicPartyAnchorCopyWithImpl<MusicPartyAnchor>(
          this as MusicPartyAnchor, _$identity);

  /// Serializes this MusicPartyAnchor to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicPartyAnchor &&
            (identical(other.trackUri, trackUri) ||
                other.trackUri == trackUri) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.playing, playing) || other.playing == playing) &&
            (identical(other.wallClockMs, wallClockMs) ||
                other.wallClockMs == wallClockMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.djId, djId) || other.djId == djId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, trackUri, positionMs, playing, wallClockMs, seq, djId);

  @override
  String toString() {
    return 'MusicPartyAnchor(trackUri: $trackUri, positionMs: $positionMs, playing: $playing, wallClockMs: $wallClockMs, seq: $seq, djId: $djId)';
  }
}

/// @nodoc
abstract mixin class $MusicPartyAnchorCopyWith<$Res> {
  factory $MusicPartyAnchorCopyWith(
          MusicPartyAnchor value, $Res Function(MusicPartyAnchor) _then) =
      _$MusicPartyAnchorCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'track_uri') String trackUri,
      @JsonKey(name: 'position_ms') int positionMs,
      bool playing,
      @JsonKey(name: 'wall_clock_ms') int wallClockMs,
      int seq,
      @JsonKey(name: 'dj_id') String djId});
}

/// @nodoc
class _$MusicPartyAnchorCopyWithImpl<$Res>
    implements $MusicPartyAnchorCopyWith<$Res> {
  _$MusicPartyAnchorCopyWithImpl(this._self, this._then);

  final MusicPartyAnchor _self;
  final $Res Function(MusicPartyAnchor) _then;

  /// Create a copy of MusicPartyAnchor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackUri = null,
    Object? positionMs = null,
    Object? playing = null,
    Object? wallClockMs = null,
    Object? seq = null,
    Object? djId = null,
  }) {
    return _then(_self.copyWith(
      trackUri: null == trackUri
          ? _self.trackUri
          : trackUri // ignore: cast_nullable_to_non_nullable
              as String,
      positionMs: null == positionMs
          ? _self.positionMs
          : positionMs // ignore: cast_nullable_to_non_nullable
              as int,
      playing: null == playing
          ? _self.playing
          : playing // ignore: cast_nullable_to_non_nullable
              as bool,
      wallClockMs: null == wallClockMs
          ? _self.wallClockMs
          : wallClockMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      djId: null == djId
          ? _self.djId
          : djId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MusicPartyAnchor].
extension MusicPartyAnchorPatterns on MusicPartyAnchor {
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
    TResult Function(_MusicPartyAnchor value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor() when $default != null:
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
    TResult Function(_MusicPartyAnchor value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor():
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
    TResult? Function(_MusicPartyAnchor value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor() when $default != null:
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
            @JsonKey(name: 'track_uri') String trackUri,
            @JsonKey(name: 'position_ms') int positionMs,
            bool playing,
            @JsonKey(name: 'wall_clock_ms') int wallClockMs,
            int seq,
            @JsonKey(name: 'dj_id') String djId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor() when $default != null:
        return $default(_that.trackUri, _that.positionMs, _that.playing,
            _that.wallClockMs, _that.seq, _that.djId);
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
            @JsonKey(name: 'track_uri') String trackUri,
            @JsonKey(name: 'position_ms') int positionMs,
            bool playing,
            @JsonKey(name: 'wall_clock_ms') int wallClockMs,
            int seq,
            @JsonKey(name: 'dj_id') String djId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor():
        return $default(_that.trackUri, _that.positionMs, _that.playing,
            _that.wallClockMs, _that.seq, _that.djId);
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
            @JsonKey(name: 'track_uri') String trackUri,
            @JsonKey(name: 'position_ms') int positionMs,
            bool playing,
            @JsonKey(name: 'wall_clock_ms') int wallClockMs,
            int seq,
            @JsonKey(name: 'dj_id') String djId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyAnchor() when $default != null:
        return $default(_that.trackUri, _that.positionMs, _that.playing,
            _that.wallClockMs, _that.seq, _that.djId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicPartyAnchor implements MusicPartyAnchor {
  const _MusicPartyAnchor(
      {@JsonKey(name: 'track_uri') required this.trackUri,
      @JsonKey(name: 'position_ms') this.positionMs = 0,
      this.playing = false,
      @JsonKey(name: 'wall_clock_ms') this.wallClockMs = 0,
      this.seq = 0,
      @JsonKey(name: 'dj_id') required this.djId});
  factory _MusicPartyAnchor.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyAnchorFromJson(json);

  @override
  @JsonKey(name: 'track_uri')
  final String trackUri;
  @override
  @JsonKey(name: 'position_ms')
  final int positionMs;
  @override
  @JsonKey()
  final bool playing;
  @override
  @JsonKey(name: 'wall_clock_ms')
  final int wallClockMs;
  @override
  @JsonKey()
  final int seq;
  @override
  @JsonKey(name: 'dj_id')
  final String djId;

  /// Create a copy of MusicPartyAnchor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicPartyAnchorCopyWith<_MusicPartyAnchor> get copyWith =>
      __$MusicPartyAnchorCopyWithImpl<_MusicPartyAnchor>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicPartyAnchorToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicPartyAnchor &&
            (identical(other.trackUri, trackUri) ||
                other.trackUri == trackUri) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.playing, playing) || other.playing == playing) &&
            (identical(other.wallClockMs, wallClockMs) ||
                other.wallClockMs == wallClockMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.djId, djId) || other.djId == djId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, trackUri, positionMs, playing, wallClockMs, seq, djId);

  @override
  String toString() {
    return 'MusicPartyAnchor(trackUri: $trackUri, positionMs: $positionMs, playing: $playing, wallClockMs: $wallClockMs, seq: $seq, djId: $djId)';
  }
}

/// @nodoc
abstract mixin class _$MusicPartyAnchorCopyWith<$Res>
    implements $MusicPartyAnchorCopyWith<$Res> {
  factory _$MusicPartyAnchorCopyWith(
          _MusicPartyAnchor value, $Res Function(_MusicPartyAnchor) _then) =
      __$MusicPartyAnchorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'track_uri') String trackUri,
      @JsonKey(name: 'position_ms') int positionMs,
      bool playing,
      @JsonKey(name: 'wall_clock_ms') int wallClockMs,
      int seq,
      @JsonKey(name: 'dj_id') String djId});
}

/// @nodoc
class __$MusicPartyAnchorCopyWithImpl<$Res>
    implements _$MusicPartyAnchorCopyWith<$Res> {
  __$MusicPartyAnchorCopyWithImpl(this._self, this._then);

  final _MusicPartyAnchor _self;
  final $Res Function(_MusicPartyAnchor) _then;

  /// Create a copy of MusicPartyAnchor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? trackUri = null,
    Object? positionMs = null,
    Object? playing = null,
    Object? wallClockMs = null,
    Object? seq = null,
    Object? djId = null,
  }) {
    return _then(_MusicPartyAnchor(
      trackUri: null == trackUri
          ? _self.trackUri
          : trackUri // ignore: cast_nullable_to_non_nullable
              as String,
      positionMs: null == positionMs
          ? _self.positionMs
          : positionMs // ignore: cast_nullable_to_non_nullable
              as int,
      playing: null == playing
          ? _self.playing
          : playing // ignore: cast_nullable_to_non_nullable
              as bool,
      wallClockMs: null == wallClockMs
          ? _self.wallClockMs
          : wallClockMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      djId: null == djId
          ? _self.djId
          : djId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$MusicPartyJoinResponse {
  MusicPartySession get session;
  List<MusicPartyQueueItem> get queue;
  MusicPartyAnchor? get anchor;
  @JsonKey(name: 'voice_token', defaultValue: '')
  String get voiceToken;

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicPartyJoinResponseCopyWith<MusicPartyJoinResponse> get copyWith =>
      _$MusicPartyJoinResponseCopyWithImpl<MusicPartyJoinResponse>(
          this as MusicPartyJoinResponse, _$identity);

  /// Serializes this MusicPartyJoinResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicPartyJoinResponse &&
            (identical(other.session, session) || other.session == session) &&
            const DeepCollectionEquality().equals(other.queue, queue) &&
            (identical(other.anchor, anchor) || other.anchor == anchor) &&
            (identical(other.voiceToken, voiceToken) ||
                other.voiceToken == voiceToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, session,
      const DeepCollectionEquality().hash(queue), anchor, voiceToken);

  @override
  String toString() {
    return 'MusicPartyJoinResponse(session: $session, queue: $queue, anchor: $anchor, voiceToken: $voiceToken)';
  }
}

/// @nodoc
abstract mixin class $MusicPartyJoinResponseCopyWith<$Res> {
  factory $MusicPartyJoinResponseCopyWith(MusicPartyJoinResponse value,
          $Res Function(MusicPartyJoinResponse) _then) =
      _$MusicPartyJoinResponseCopyWithImpl;
  @useResult
  $Res call(
      {MusicPartySession session,
      List<MusicPartyQueueItem> queue,
      MusicPartyAnchor? anchor,
      @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken});

  $MusicPartySessionCopyWith<$Res> get session;
  $MusicPartyAnchorCopyWith<$Res>? get anchor;
}

/// @nodoc
class _$MusicPartyJoinResponseCopyWithImpl<$Res>
    implements $MusicPartyJoinResponseCopyWith<$Res> {
  _$MusicPartyJoinResponseCopyWithImpl(this._self, this._then);

  final MusicPartyJoinResponse _self;
  final $Res Function(MusicPartyJoinResponse) _then;

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? queue = null,
    Object? anchor = freezed,
    Object? voiceToken = null,
  }) {
    return _then(_self.copyWith(
      session: null == session
          ? _self.session
          : session // ignore: cast_nullable_to_non_nullable
              as MusicPartySession,
      queue: null == queue
          ? _self.queue
          : queue // ignore: cast_nullable_to_non_nullable
              as List<MusicPartyQueueItem>,
      anchor: freezed == anchor
          ? _self.anchor
          : anchor // ignore: cast_nullable_to_non_nullable
              as MusicPartyAnchor?,
      voiceToken: null == voiceToken
          ? _self.voiceToken
          : voiceToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartySessionCopyWith<$Res> get session {
    return $MusicPartySessionCopyWith<$Res>(_self.session, (value) {
      return _then(_self.copyWith(session: value));
    });
  }

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartyAnchorCopyWith<$Res>? get anchor {
    if (_self.anchor == null) {
      return null;
    }

    return $MusicPartyAnchorCopyWith<$Res>(_self.anchor!, (value) {
      return _then(_self.copyWith(anchor: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MusicPartyJoinResponse].
extension MusicPartyJoinResponsePatterns on MusicPartyJoinResponse {
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
    TResult Function(_MusicPartyJoinResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse() when $default != null:
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
    TResult Function(_MusicPartyJoinResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse():
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
    TResult? Function(_MusicPartyJoinResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse() when $default != null:
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
            MusicPartySession session,
            List<MusicPartyQueueItem> queue,
            MusicPartyAnchor? anchor,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse() when $default != null:
        return $default(
            _that.session, _that.queue, _that.anchor, _that.voiceToken);
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
            MusicPartySession session,
            List<MusicPartyQueueItem> queue,
            MusicPartyAnchor? anchor,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse():
        return $default(
            _that.session, _that.queue, _that.anchor, _that.voiceToken);
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
            MusicPartySession session,
            List<MusicPartyQueueItem> queue,
            MusicPartyAnchor? anchor,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicPartyJoinResponse() when $default != null:
        return $default(
            _that.session, _that.queue, _that.anchor, _that.voiceToken);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicPartyJoinResponse implements MusicPartyJoinResponse {
  const _MusicPartyJoinResponse(
      {required this.session,
      final List<MusicPartyQueueItem> queue = const [],
      this.anchor,
      @JsonKey(name: 'voice_token', defaultValue: '') this.voiceToken = ''})
      : _queue = queue;
  factory _MusicPartyJoinResponse.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyJoinResponseFromJson(json);

  @override
  final MusicPartySession session;
  final List<MusicPartyQueueItem> _queue;
  @override
  @JsonKey()
  List<MusicPartyQueueItem> get queue {
    if (_queue is EqualUnmodifiableListView) return _queue;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_queue);
  }

  @override
  final MusicPartyAnchor? anchor;
  @override
  @JsonKey(name: 'voice_token', defaultValue: '')
  final String voiceToken;

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicPartyJoinResponseCopyWith<_MusicPartyJoinResponse> get copyWith =>
      __$MusicPartyJoinResponseCopyWithImpl<_MusicPartyJoinResponse>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicPartyJoinResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicPartyJoinResponse &&
            (identical(other.session, session) || other.session == session) &&
            const DeepCollectionEquality().equals(other._queue, _queue) &&
            (identical(other.anchor, anchor) || other.anchor == anchor) &&
            (identical(other.voiceToken, voiceToken) ||
                other.voiceToken == voiceToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, session,
      const DeepCollectionEquality().hash(_queue), anchor, voiceToken);

  @override
  String toString() {
    return 'MusicPartyJoinResponse(session: $session, queue: $queue, anchor: $anchor, voiceToken: $voiceToken)';
  }
}

/// @nodoc
abstract mixin class _$MusicPartyJoinResponseCopyWith<$Res>
    implements $MusicPartyJoinResponseCopyWith<$Res> {
  factory _$MusicPartyJoinResponseCopyWith(_MusicPartyJoinResponse value,
          $Res Function(_MusicPartyJoinResponse) _then) =
      __$MusicPartyJoinResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {MusicPartySession session,
      List<MusicPartyQueueItem> queue,
      MusicPartyAnchor? anchor,
      @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken});

  @override
  $MusicPartySessionCopyWith<$Res> get session;
  @override
  $MusicPartyAnchorCopyWith<$Res>? get anchor;
}

/// @nodoc
class __$MusicPartyJoinResponseCopyWithImpl<$Res>
    implements _$MusicPartyJoinResponseCopyWith<$Res> {
  __$MusicPartyJoinResponseCopyWithImpl(this._self, this._then);

  final _MusicPartyJoinResponse _self;
  final $Res Function(_MusicPartyJoinResponse) _then;

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? session = null,
    Object? queue = null,
    Object? anchor = freezed,
    Object? voiceToken = null,
  }) {
    return _then(_MusicPartyJoinResponse(
      session: null == session
          ? _self.session
          : session // ignore: cast_nullable_to_non_nullable
              as MusicPartySession,
      queue: null == queue
          ? _self._queue
          : queue // ignore: cast_nullable_to_non_nullable
              as List<MusicPartyQueueItem>,
      anchor: freezed == anchor
          ? _self.anchor
          : anchor // ignore: cast_nullable_to_non_nullable
              as MusicPartyAnchor?,
      voiceToken: null == voiceToken
          ? _self.voiceToken
          : voiceToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartySessionCopyWith<$Res> get session {
    return $MusicPartySessionCopyWith<$Res>(_self.session, (value) {
      return _then(_self.copyWith(session: value));
    });
  }

  /// Create a copy of MusicPartyJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicPartyAnchorCopyWith<$Res>? get anchor {
    if (_self.anchor == null) {
      return null;
    }

    return $MusicPartyAnchorCopyWith<$Res>(_self.anchor!, (value) {
      return _then(_self.copyWith(anchor: value));
    });
  }
}

/// @nodoc
mixin _$SkipVoteStatus {
  @JsonKey(name: 'current_votes')
  int get currentVotes;
  double get threshold;
  @JsonKey(name: 'total_voters')
  int get totalVoters;
  bool get reached;

  /// Create a copy of SkipVoteStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SkipVoteStatusCopyWith<SkipVoteStatus> get copyWith =>
      _$SkipVoteStatusCopyWithImpl<SkipVoteStatus>(
          this as SkipVoteStatus, _$identity);

  /// Serializes this SkipVoteStatus to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SkipVoteStatus &&
            (identical(other.currentVotes, currentVotes) ||
                other.currentVotes == currentVotes) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.totalVoters, totalVoters) ||
                other.totalVoters == totalVoters) &&
            (identical(other.reached, reached) || other.reached == reached));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, currentVotes, threshold, totalVoters, reached);

  @override
  String toString() {
    return 'SkipVoteStatus(currentVotes: $currentVotes, threshold: $threshold, totalVoters: $totalVoters, reached: $reached)';
  }
}

/// @nodoc
abstract mixin class $SkipVoteStatusCopyWith<$Res> {
  factory $SkipVoteStatusCopyWith(
          SkipVoteStatus value, $Res Function(SkipVoteStatus) _then) =
      _$SkipVoteStatusCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'current_votes') int currentVotes,
      double threshold,
      @JsonKey(name: 'total_voters') int totalVoters,
      bool reached});
}

/// @nodoc
class _$SkipVoteStatusCopyWithImpl<$Res>
    implements $SkipVoteStatusCopyWith<$Res> {
  _$SkipVoteStatusCopyWithImpl(this._self, this._then);

  final SkipVoteStatus _self;
  final $Res Function(SkipVoteStatus) _then;

  /// Create a copy of SkipVoteStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentVotes = null,
    Object? threshold = null,
    Object? totalVoters = null,
    Object? reached = null,
  }) {
    return _then(_self.copyWith(
      currentVotes: null == currentVotes
          ? _self.currentVotes
          : currentVotes // ignore: cast_nullable_to_non_nullable
              as int,
      threshold: null == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      totalVoters: null == totalVoters
          ? _self.totalVoters
          : totalVoters // ignore: cast_nullable_to_non_nullable
              as int,
      reached: null == reached
          ? _self.reached
          : reached // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [SkipVoteStatus].
extension SkipVoteStatusPatterns on SkipVoteStatus {
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
    TResult Function(_SkipVoteStatus value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus() when $default != null:
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
    TResult Function(_SkipVoteStatus value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus():
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
    TResult? Function(_SkipVoteStatus value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus() when $default != null:
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
            @JsonKey(name: 'current_votes') int currentVotes,
            double threshold,
            @JsonKey(name: 'total_voters') int totalVoters,
            bool reached)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus() when $default != null:
        return $default(_that.currentVotes, _that.threshold, _that.totalVoters,
            _that.reached);
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
            @JsonKey(name: 'current_votes') int currentVotes,
            double threshold,
            @JsonKey(name: 'total_voters') int totalVoters,
            bool reached)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus():
        return $default(_that.currentVotes, _that.threshold, _that.totalVoters,
            _that.reached);
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
            @JsonKey(name: 'current_votes') int currentVotes,
            double threshold,
            @JsonKey(name: 'total_voters') int totalVoters,
            bool reached)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SkipVoteStatus() when $default != null:
        return $default(_that.currentVotes, _that.threshold, _that.totalVoters,
            _that.reached);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SkipVoteStatus implements SkipVoteStatus {
  const _SkipVoteStatus(
      {@JsonKey(name: 'current_votes') this.currentVotes = 0,
      this.threshold = 0.5,
      @JsonKey(name: 'total_voters') this.totalVoters = 0,
      this.reached = false});
  factory _SkipVoteStatus.fromJson(Map<String, dynamic> json) =>
      _$SkipVoteStatusFromJson(json);

  @override
  @JsonKey(name: 'current_votes')
  final int currentVotes;
  @override
  @JsonKey()
  final double threshold;
  @override
  @JsonKey(name: 'total_voters')
  final int totalVoters;
  @override
  @JsonKey()
  final bool reached;

  /// Create a copy of SkipVoteStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SkipVoteStatusCopyWith<_SkipVoteStatus> get copyWith =>
      __$SkipVoteStatusCopyWithImpl<_SkipVoteStatus>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SkipVoteStatusToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SkipVoteStatus &&
            (identical(other.currentVotes, currentVotes) ||
                other.currentVotes == currentVotes) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.totalVoters, totalVoters) ||
                other.totalVoters == totalVoters) &&
            (identical(other.reached, reached) || other.reached == reached));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, currentVotes, threshold, totalVoters, reached);

  @override
  String toString() {
    return 'SkipVoteStatus(currentVotes: $currentVotes, threshold: $threshold, totalVoters: $totalVoters, reached: $reached)';
  }
}

/// @nodoc
abstract mixin class _$SkipVoteStatusCopyWith<$Res>
    implements $SkipVoteStatusCopyWith<$Res> {
  factory _$SkipVoteStatusCopyWith(
          _SkipVoteStatus value, $Res Function(_SkipVoteStatus) _then) =
      __$SkipVoteStatusCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'current_votes') int currentVotes,
      double threshold,
      @JsonKey(name: 'total_voters') int totalVoters,
      bool reached});
}

/// @nodoc
class __$SkipVoteStatusCopyWithImpl<$Res>
    implements _$SkipVoteStatusCopyWith<$Res> {
  __$SkipVoteStatusCopyWithImpl(this._self, this._then);

  final _SkipVoteStatus _self;
  final $Res Function(_SkipVoteStatus) _then;

  /// Create a copy of SkipVoteStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? currentVotes = null,
    Object? threshold = null,
    Object? totalVoters = null,
    Object? reached = null,
  }) {
    return _then(_SkipVoteStatus(
      currentVotes: null == currentVotes
          ? _self.currentVotes
          : currentVotes // ignore: cast_nullable_to_non_nullable
              as int,
      threshold: null == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      totalVoters: null == totalVoters
          ? _self.totalVoters
          : totalVoters // ignore: cast_nullable_to_non_nullable
              as int,
      reached: null == reached
          ? _self.reached
          : reached // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
