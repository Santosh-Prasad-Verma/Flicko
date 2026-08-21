// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watch_together_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WatchTogetherSettings {
  @JsonKey(name: 'max_viewers')
  int get maxViewers;
  @JsonKey(name: 'allow_seek_by_viewer')
  bool get allowSeekByViewer;

  /// Create a copy of WatchTogetherSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WatchTogetherSettingsCopyWith<WatchTogetherSettings> get copyWith =>
      _$WatchTogetherSettingsCopyWithImpl<WatchTogetherSettings>(
          this as WatchTogetherSettings, _$identity);

  /// Serializes this WatchTogetherSettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WatchTogetherSettings &&
            (identical(other.maxViewers, maxViewers) ||
                other.maxViewers == maxViewers) &&
            (identical(other.allowSeekByViewer, allowSeekByViewer) ||
                other.allowSeekByViewer == allowSeekByViewer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxViewers, allowSeekByViewer);

  @override
  String toString() {
    return 'WatchTogetherSettings(maxViewers: $maxViewers, allowSeekByViewer: $allowSeekByViewer)';
  }
}

/// @nodoc
abstract mixin class $WatchTogetherSettingsCopyWith<$Res> {
  factory $WatchTogetherSettingsCopyWith(WatchTogetherSettings value,
          $Res Function(WatchTogetherSettings) _then) =
      _$WatchTogetherSettingsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'max_viewers') int maxViewers,
      @JsonKey(name: 'allow_seek_by_viewer') bool allowSeekByViewer});
}

/// @nodoc
class _$WatchTogetherSettingsCopyWithImpl<$Res>
    implements $WatchTogetherSettingsCopyWith<$Res> {
  _$WatchTogetherSettingsCopyWithImpl(this._self, this._then);

  final WatchTogetherSettings _self;
  final $Res Function(WatchTogetherSettings) _then;

  /// Create a copy of WatchTogetherSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxViewers = null,
    Object? allowSeekByViewer = null,
  }) {
    return _then(_self.copyWith(
      maxViewers: null == maxViewers
          ? _self.maxViewers
          : maxViewers // ignore: cast_nullable_to_non_nullable
              as int,
      allowSeekByViewer: null == allowSeekByViewer
          ? _self.allowSeekByViewer
          : allowSeekByViewer // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [WatchTogetherSettings].
extension WatchTogetherSettingsPatterns on WatchTogetherSettings {
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
    TResult Function(_WatchTogetherSettings value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings() when $default != null:
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
    TResult Function(_WatchTogetherSettings value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings():
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
    TResult? Function(_WatchTogetherSettings value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings() when $default != null:
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
    TResult Function(@JsonKey(name: 'max_viewers') int maxViewers,
            @JsonKey(name: 'allow_seek_by_viewer') bool allowSeekByViewer)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings() when $default != null:
        return $default(_that.maxViewers, _that.allowSeekByViewer);
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
    TResult Function(@JsonKey(name: 'max_viewers') int maxViewers,
            @JsonKey(name: 'allow_seek_by_viewer') bool allowSeekByViewer)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings():
        return $default(_that.maxViewers, _that.allowSeekByViewer);
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
    TResult? Function(@JsonKey(name: 'max_viewers') int maxViewers,
            @JsonKey(name: 'allow_seek_by_viewer') bool allowSeekByViewer)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSettings() when $default != null:
        return $default(_that.maxViewers, _that.allowSeekByViewer);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WatchTogetherSettings implements WatchTogetherSettings {
  const _WatchTogetherSettings(
      {@JsonKey(name: 'max_viewers') this.maxViewers = 12,
      @JsonKey(name: 'allow_seek_by_viewer') this.allowSeekByViewer = true});
  factory _WatchTogetherSettings.fromJson(Map<String, dynamic> json) =>
      _$WatchTogetherSettingsFromJson(json);

  @override
  @JsonKey(name: 'max_viewers')
  final int maxViewers;
  @override
  @JsonKey(name: 'allow_seek_by_viewer')
  final bool allowSeekByViewer;

  /// Create a copy of WatchTogetherSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WatchTogetherSettingsCopyWith<_WatchTogetherSettings> get copyWith =>
      __$WatchTogetherSettingsCopyWithImpl<_WatchTogetherSettings>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WatchTogetherSettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WatchTogetherSettings &&
            (identical(other.maxViewers, maxViewers) ||
                other.maxViewers == maxViewers) &&
            (identical(other.allowSeekByViewer, allowSeekByViewer) ||
                other.allowSeekByViewer == allowSeekByViewer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxViewers, allowSeekByViewer);

  @override
  String toString() {
    return 'WatchTogetherSettings(maxViewers: $maxViewers, allowSeekByViewer: $allowSeekByViewer)';
  }
}

/// @nodoc
abstract mixin class _$WatchTogetherSettingsCopyWith<$Res>
    implements $WatchTogetherSettingsCopyWith<$Res> {
  factory _$WatchTogetherSettingsCopyWith(_WatchTogetherSettings value,
          $Res Function(_WatchTogetherSettings) _then) =
      __$WatchTogetherSettingsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'max_viewers') int maxViewers,
      @JsonKey(name: 'allow_seek_by_viewer') bool allowSeekByViewer});
}

/// @nodoc
class __$WatchTogetherSettingsCopyWithImpl<$Res>
    implements _$WatchTogetherSettingsCopyWith<$Res> {
  __$WatchTogetherSettingsCopyWithImpl(this._self, this._then);

  final _WatchTogetherSettings _self;
  final $Res Function(_WatchTogetherSettings) _then;

  /// Create a copy of WatchTogetherSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? maxViewers = null,
    Object? allowSeekByViewer = null,
  }) {
    return _then(_WatchTogetherSettings(
      maxViewers: null == maxViewers
          ? _self.maxViewers
          : maxViewers // ignore: cast_nullable_to_non_nullable
              as int,
      allowSeekByViewer: null == allowSeekByViewer
          ? _self.allowSeekByViewer
          : allowSeekByViewer // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$WatchTogetherSession {
  String get id;
  @JsonKey(name: 'room_id')
  String get roomId;
  @JsonKey(name: 'host_user_id')
  String get hostUserId;
  @JsonKey(name: 'media_kind')
  String get mediaKind;
  @JsonKey(name: 'media_url')
  String get mediaUrl;
  @JsonKey(name: 'media_title')
  String? get mediaTitle;
  @JsonKey(name: 'media_duration_ms')
  int? get mediaDurationMs;
  String get state;
  @JsonKey(name: 'settings')
  WatchTogetherSettings get settings;
  @JsonKey(name: 'anchor_position_ms')
  int get anchorPositionMs;
  @JsonKey(name: 'anchor_playing')
  bool get anchorPlaying;
  @JsonKey(name: 'anchor_rate')
  double get anchorRate;
  @JsonKey(name: 'anchor_wall_ms')
  int get anchorWallMs;
  int get seq;
  @JsonKey(name: 'is_standalone')
  bool get isStandalone;
  @JsonKey(name: 'is_public')
  bool get isPublic;
  @JsonKey(name: 'lobby_name')
  String? get lobbyName;

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WatchTogetherSessionCopyWith<WatchTogetherSession> get copyWith =>
      _$WatchTogetherSessionCopyWithImpl<WatchTogetherSession>(
          this as WatchTogetherSession, _$identity);

  /// Serializes this WatchTogetherSession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WatchTogetherSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.hostUserId, hostUserId) ||
                other.hostUserId == hostUserId) &&
            (identical(other.mediaKind, mediaKind) ||
                other.mediaKind == mediaKind) &&
            (identical(other.mediaUrl, mediaUrl) ||
                other.mediaUrl == mediaUrl) &&
            (identical(other.mediaTitle, mediaTitle) ||
                other.mediaTitle == mediaTitle) &&
            (identical(other.mediaDurationMs, mediaDurationMs) ||
                other.mediaDurationMs == mediaDurationMs) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.anchorPositionMs, anchorPositionMs) ||
                other.anchorPositionMs == anchorPositionMs) &&
            (identical(other.anchorPlaying, anchorPlaying) ||
                other.anchorPlaying == anchorPlaying) &&
            (identical(other.anchorRate, anchorRate) ||
                other.anchorRate == anchorRate) &&
            (identical(other.anchorWallMs, anchorWallMs) ||
                other.anchorWallMs == anchorWallMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.isStandalone, isStandalone) ||
                other.isStandalone == isStandalone) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.lobbyName, lobbyName) ||
                other.lobbyName == lobbyName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomId,
      hostUserId,
      mediaKind,
      mediaUrl,
      mediaTitle,
      mediaDurationMs,
      state,
      settings,
      anchorPositionMs,
      anchorPlaying,
      anchorRate,
      anchorWallMs,
      seq,
      isStandalone,
      isPublic,
      lobbyName);

  @override
  String toString() {
    return 'WatchTogetherSession(id: $id, roomId: $roomId, hostUserId: $hostUserId, mediaKind: $mediaKind, mediaUrl: $mediaUrl, mediaTitle: $mediaTitle, mediaDurationMs: $mediaDurationMs, state: $state, settings: $settings, anchorPositionMs: $anchorPositionMs, anchorPlaying: $anchorPlaying, anchorRate: $anchorRate, anchorWallMs: $anchorWallMs, seq: $seq, isStandalone: $isStandalone, isPublic: $isPublic, lobbyName: $lobbyName)';
  }
}

/// @nodoc
abstract mixin class $WatchTogetherSessionCopyWith<$Res> {
  factory $WatchTogetherSessionCopyWith(WatchTogetherSession value,
          $Res Function(WatchTogetherSession) _then) =
      _$WatchTogetherSessionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'host_user_id') String hostUserId,
      @JsonKey(name: 'media_kind') String mediaKind,
      @JsonKey(name: 'media_url') String mediaUrl,
      @JsonKey(name: 'media_title') String? mediaTitle,
      @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
      String state,
      @JsonKey(name: 'settings') WatchTogetherSettings settings,
      @JsonKey(name: 'anchor_position_ms') int anchorPositionMs,
      @JsonKey(name: 'anchor_playing') bool anchorPlaying,
      @JsonKey(name: 'anchor_rate') double anchorRate,
      @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
      int seq,
      @JsonKey(name: 'is_standalone') bool isStandalone,
      @JsonKey(name: 'is_public') bool isPublic,
      @JsonKey(name: 'lobby_name') String? lobbyName});

  $WatchTogetherSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$WatchTogetherSessionCopyWithImpl<$Res>
    implements $WatchTogetherSessionCopyWith<$Res> {
  _$WatchTogetherSessionCopyWithImpl(this._self, this._then);

  final WatchTogetherSession _self;
  final $Res Function(WatchTogetherSession) _then;

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? hostUserId = null,
    Object? mediaKind = null,
    Object? mediaUrl = null,
    Object? mediaTitle = freezed,
    Object? mediaDurationMs = freezed,
    Object? state = null,
    Object? settings = null,
    Object? anchorPositionMs = null,
    Object? anchorPlaying = null,
    Object? anchorRate = null,
    Object? anchorWallMs = null,
    Object? seq = null,
    Object? isStandalone = null,
    Object? isPublic = null,
    Object? lobbyName = freezed,
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
      hostUserId: null == hostUserId
          ? _self.hostUserId
          : hostUserId // ignore: cast_nullable_to_non_nullable
              as String,
      mediaKind: null == mediaKind
          ? _self.mediaKind
          : mediaKind // ignore: cast_nullable_to_non_nullable
              as String,
      mediaUrl: null == mediaUrl
          ? _self.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String,
      mediaTitle: freezed == mediaTitle
          ? _self.mediaTitle
          : mediaTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaDurationMs: freezed == mediaDurationMs
          ? _self.mediaDurationMs
          : mediaDurationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      settings: null == settings
          ? _self.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WatchTogetherSettings,
      anchorPositionMs: null == anchorPositionMs
          ? _self.anchorPositionMs
          : anchorPositionMs // ignore: cast_nullable_to_non_nullable
              as int,
      anchorPlaying: null == anchorPlaying
          ? _self.anchorPlaying
          : anchorPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      anchorRate: null == anchorRate
          ? _self.anchorRate
          : anchorRate // ignore: cast_nullable_to_non_nullable
              as double,
      anchorWallMs: null == anchorWallMs
          ? _self.anchorWallMs
          : anchorWallMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      isStandalone: null == isStandalone
          ? _self.isStandalone
          : isStandalone // ignore: cast_nullable_to_non_nullable
              as bool,
      isPublic: null == isPublic
          ? _self.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      lobbyName: freezed == lobbyName
          ? _self.lobbyName
          : lobbyName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WatchTogetherSettingsCopyWith<$Res> get settings {
    return $WatchTogetherSettingsCopyWith<$Res>(_self.settings, (value) {
      return _then(_self.copyWith(settings: value));
    });
  }
}

/// Adds pattern-matching-related methods to [WatchTogetherSession].
extension WatchTogetherSessionPatterns on WatchTogetherSession {
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
    TResult Function(_WatchTogetherSession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession() when $default != null:
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
    TResult Function(_WatchTogetherSession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession():
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
    TResult? Function(_WatchTogetherSession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession() when $default != null:
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
            @JsonKey(name: 'host_user_id') String hostUserId,
            @JsonKey(name: 'media_kind') String mediaKind,
            @JsonKey(name: 'media_url') String mediaUrl,
            @JsonKey(name: 'media_title') String? mediaTitle,
            @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
            String state,
            @JsonKey(name: 'settings') WatchTogetherSettings settings,
            @JsonKey(name: 'anchor_position_ms') int anchorPositionMs,
            @JsonKey(name: 'anchor_playing') bool anchorPlaying,
            @JsonKey(name: 'anchor_rate') double anchorRate,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            @JsonKey(name: 'is_standalone') bool isStandalone,
            @JsonKey(name: 'is_public') bool isPublic,
            @JsonKey(name: 'lobby_name') String? lobbyName)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession() when $default != null:
        return $default(
            _that.id,
            _that.roomId,
            _that.hostUserId,
            _that.mediaKind,
            _that.mediaUrl,
            _that.mediaTitle,
            _that.mediaDurationMs,
            _that.state,
            _that.settings,
            _that.anchorPositionMs,
            _that.anchorPlaying,
            _that.anchorRate,
            _that.anchorWallMs,
            _that.seq,
            _that.isStandalone,
            _that.isPublic,
            _that.lobbyName);
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
            @JsonKey(name: 'host_user_id') String hostUserId,
            @JsonKey(name: 'media_kind') String mediaKind,
            @JsonKey(name: 'media_url') String mediaUrl,
            @JsonKey(name: 'media_title') String? mediaTitle,
            @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
            String state,
            @JsonKey(name: 'settings') WatchTogetherSettings settings,
            @JsonKey(name: 'anchor_position_ms') int anchorPositionMs,
            @JsonKey(name: 'anchor_playing') bool anchorPlaying,
            @JsonKey(name: 'anchor_rate') double anchorRate,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            @JsonKey(name: 'is_standalone') bool isStandalone,
            @JsonKey(name: 'is_public') bool isPublic,
            @JsonKey(name: 'lobby_name') String? lobbyName)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession():
        return $default(
            _that.id,
            _that.roomId,
            _that.hostUserId,
            _that.mediaKind,
            _that.mediaUrl,
            _that.mediaTitle,
            _that.mediaDurationMs,
            _that.state,
            _that.settings,
            _that.anchorPositionMs,
            _that.anchorPlaying,
            _that.anchorRate,
            _that.anchorWallMs,
            _that.seq,
            _that.isStandalone,
            _that.isPublic,
            _that.lobbyName);
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
            @JsonKey(name: 'host_user_id') String hostUserId,
            @JsonKey(name: 'media_kind') String mediaKind,
            @JsonKey(name: 'media_url') String mediaUrl,
            @JsonKey(name: 'media_title') String? mediaTitle,
            @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
            String state,
            @JsonKey(name: 'settings') WatchTogetherSettings settings,
            @JsonKey(name: 'anchor_position_ms') int anchorPositionMs,
            @JsonKey(name: 'anchor_playing') bool anchorPlaying,
            @JsonKey(name: 'anchor_rate') double anchorRate,
            @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
            int seq,
            @JsonKey(name: 'is_standalone') bool isStandalone,
            @JsonKey(name: 'is_public') bool isPublic,
            @JsonKey(name: 'lobby_name') String? lobbyName)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherSession() when $default != null:
        return $default(
            _that.id,
            _that.roomId,
            _that.hostUserId,
            _that.mediaKind,
            _that.mediaUrl,
            _that.mediaTitle,
            _that.mediaDurationMs,
            _that.state,
            _that.settings,
            _that.anchorPositionMs,
            _that.anchorPlaying,
            _that.anchorRate,
            _that.anchorWallMs,
            _that.seq,
            _that.isStandalone,
            _that.isPublic,
            _that.lobbyName);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WatchTogetherSession implements WatchTogetherSession {
  const _WatchTogetherSession(
      {required this.id,
      @JsonKey(name: 'room_id') required this.roomId,
      @JsonKey(name: 'host_user_id') required this.hostUserId,
      @JsonKey(name: 'media_kind') required this.mediaKind,
      @JsonKey(name: 'media_url') required this.mediaUrl,
      @JsonKey(name: 'media_title') this.mediaTitle,
      @JsonKey(name: 'media_duration_ms') this.mediaDurationMs,
      required this.state,
      @JsonKey(name: 'settings') required this.settings,
      @JsonKey(name: 'anchor_position_ms') this.anchorPositionMs = 0,
      @JsonKey(name: 'anchor_playing') this.anchorPlaying = false,
      @JsonKey(name: 'anchor_rate') this.anchorRate = 1.0,
      @JsonKey(name: 'anchor_wall_ms') this.anchorWallMs = 0,
      this.seq = 0,
      @JsonKey(name: 'is_standalone') this.isStandalone = false,
      @JsonKey(name: 'is_public') this.isPublic = false,
      @JsonKey(name: 'lobby_name') this.lobbyName});
  factory _WatchTogetherSession.fromJson(Map<String, dynamic> json) =>
      _$WatchTogetherSessionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'room_id')
  final String roomId;
  @override
  @JsonKey(name: 'host_user_id')
  final String hostUserId;
  @override
  @JsonKey(name: 'media_kind')
  final String mediaKind;
  @override
  @JsonKey(name: 'media_url')
  final String mediaUrl;
  @override
  @JsonKey(name: 'media_title')
  final String? mediaTitle;
  @override
  @JsonKey(name: 'media_duration_ms')
  final int? mediaDurationMs;
  @override
  final String state;
  @override
  @JsonKey(name: 'settings')
  final WatchTogetherSettings settings;
  @override
  @JsonKey(name: 'anchor_position_ms')
  final int anchorPositionMs;
  @override
  @JsonKey(name: 'anchor_playing')
  final bool anchorPlaying;
  @override
  @JsonKey(name: 'anchor_rate')
  final double anchorRate;
  @override
  @JsonKey(name: 'anchor_wall_ms')
  final int anchorWallMs;
  @override
  @JsonKey()
  final int seq;
  @override
  @JsonKey(name: 'is_standalone')
  final bool isStandalone;
  @override
  @JsonKey(name: 'is_public')
  final bool isPublic;
  @override
  @JsonKey(name: 'lobby_name')
  final String? lobbyName;

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WatchTogetherSessionCopyWith<_WatchTogetherSession> get copyWith =>
      __$WatchTogetherSessionCopyWithImpl<_WatchTogetherSession>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WatchTogetherSessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WatchTogetherSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.hostUserId, hostUserId) ||
                other.hostUserId == hostUserId) &&
            (identical(other.mediaKind, mediaKind) ||
                other.mediaKind == mediaKind) &&
            (identical(other.mediaUrl, mediaUrl) ||
                other.mediaUrl == mediaUrl) &&
            (identical(other.mediaTitle, mediaTitle) ||
                other.mediaTitle == mediaTitle) &&
            (identical(other.mediaDurationMs, mediaDurationMs) ||
                other.mediaDurationMs == mediaDurationMs) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.anchorPositionMs, anchorPositionMs) ||
                other.anchorPositionMs == anchorPositionMs) &&
            (identical(other.anchorPlaying, anchorPlaying) ||
                other.anchorPlaying == anchorPlaying) &&
            (identical(other.anchorRate, anchorRate) ||
                other.anchorRate == anchorRate) &&
            (identical(other.anchorWallMs, anchorWallMs) ||
                other.anchorWallMs == anchorWallMs) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.isStandalone, isStandalone) ||
                other.isStandalone == isStandalone) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.lobbyName, lobbyName) ||
                other.lobbyName == lobbyName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomId,
      hostUserId,
      mediaKind,
      mediaUrl,
      mediaTitle,
      mediaDurationMs,
      state,
      settings,
      anchorPositionMs,
      anchorPlaying,
      anchorRate,
      anchorWallMs,
      seq,
      isStandalone,
      isPublic,
      lobbyName);

  @override
  String toString() {
    return 'WatchTogetherSession(id: $id, roomId: $roomId, hostUserId: $hostUserId, mediaKind: $mediaKind, mediaUrl: $mediaUrl, mediaTitle: $mediaTitle, mediaDurationMs: $mediaDurationMs, state: $state, settings: $settings, anchorPositionMs: $anchorPositionMs, anchorPlaying: $anchorPlaying, anchorRate: $anchorRate, anchorWallMs: $anchorWallMs, seq: $seq, isStandalone: $isStandalone, isPublic: $isPublic, lobbyName: $lobbyName)';
  }
}

/// @nodoc
abstract mixin class _$WatchTogetherSessionCopyWith<$Res>
    implements $WatchTogetherSessionCopyWith<$Res> {
  factory _$WatchTogetherSessionCopyWith(_WatchTogetherSession value,
          $Res Function(_WatchTogetherSession) _then) =
      __$WatchTogetherSessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'host_user_id') String hostUserId,
      @JsonKey(name: 'media_kind') String mediaKind,
      @JsonKey(name: 'media_url') String mediaUrl,
      @JsonKey(name: 'media_title') String? mediaTitle,
      @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
      String state,
      @JsonKey(name: 'settings') WatchTogetherSettings settings,
      @JsonKey(name: 'anchor_position_ms') int anchorPositionMs,
      @JsonKey(name: 'anchor_playing') bool anchorPlaying,
      @JsonKey(name: 'anchor_rate') double anchorRate,
      @JsonKey(name: 'anchor_wall_ms') int anchorWallMs,
      int seq,
      @JsonKey(name: 'is_standalone') bool isStandalone,
      @JsonKey(name: 'is_public') bool isPublic,
      @JsonKey(name: 'lobby_name') String? lobbyName});

  @override
  $WatchTogetherSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$WatchTogetherSessionCopyWithImpl<$Res>
    implements _$WatchTogetherSessionCopyWith<$Res> {
  __$WatchTogetherSessionCopyWithImpl(this._self, this._then);

  final _WatchTogetherSession _self;
  final $Res Function(_WatchTogetherSession) _then;

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? hostUserId = null,
    Object? mediaKind = null,
    Object? mediaUrl = null,
    Object? mediaTitle = freezed,
    Object? mediaDurationMs = freezed,
    Object? state = null,
    Object? settings = null,
    Object? anchorPositionMs = null,
    Object? anchorPlaying = null,
    Object? anchorRate = null,
    Object? anchorWallMs = null,
    Object? seq = null,
    Object? isStandalone = null,
    Object? isPublic = null,
    Object? lobbyName = freezed,
  }) {
    return _then(_WatchTogetherSession(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      hostUserId: null == hostUserId
          ? _self.hostUserId
          : hostUserId // ignore: cast_nullable_to_non_nullable
              as String,
      mediaKind: null == mediaKind
          ? _self.mediaKind
          : mediaKind // ignore: cast_nullable_to_non_nullable
              as String,
      mediaUrl: null == mediaUrl
          ? _self.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String,
      mediaTitle: freezed == mediaTitle
          ? _self.mediaTitle
          : mediaTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaDurationMs: freezed == mediaDurationMs
          ? _self.mediaDurationMs
          : mediaDurationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      settings: null == settings
          ? _self.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WatchTogetherSettings,
      anchorPositionMs: null == anchorPositionMs
          ? _self.anchorPositionMs
          : anchorPositionMs // ignore: cast_nullable_to_non_nullable
              as int,
      anchorPlaying: null == anchorPlaying
          ? _self.anchorPlaying
          : anchorPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      anchorRate: null == anchorRate
          ? _self.anchorRate
          : anchorRate // ignore: cast_nullable_to_non_nullable
              as double,
      anchorWallMs: null == anchorWallMs
          ? _self.anchorWallMs
          : anchorWallMs // ignore: cast_nullable_to_non_nullable
              as int,
      seq: null == seq
          ? _self.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      isStandalone: null == isStandalone
          ? _self.isStandalone
          : isStandalone // ignore: cast_nullable_to_non_nullable
              as bool,
      isPublic: null == isPublic
          ? _self.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      lobbyName: freezed == lobbyName
          ? _self.lobbyName
          : lobbyName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of WatchTogetherSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WatchTogetherSettingsCopyWith<$Res> get settings {
    return $WatchTogetherSettingsCopyWith<$Res>(_self.settings, (value) {
      return _then(_self.copyWith(settings: value));
    });
  }
}

/// @nodoc
mixin _$WatchTogetherJoinResponse {
  WatchTogetherSession get session;
  @JsonKey(name: 'voice_token', defaultValue: '')
  String get voiceToken;

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WatchTogetherJoinResponseCopyWith<WatchTogetherJoinResponse> get copyWith =>
      _$WatchTogetherJoinResponseCopyWithImpl<WatchTogetherJoinResponse>(
          this as WatchTogetherJoinResponse, _$identity);

  /// Serializes this WatchTogetherJoinResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WatchTogetherJoinResponse &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.voiceToken, voiceToken) ||
                other.voiceToken == voiceToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, session, voiceToken);

  @override
  String toString() {
    return 'WatchTogetherJoinResponse(session: $session, voiceToken: $voiceToken)';
  }
}

/// @nodoc
abstract mixin class $WatchTogetherJoinResponseCopyWith<$Res> {
  factory $WatchTogetherJoinResponseCopyWith(WatchTogetherJoinResponse value,
          $Res Function(WatchTogetherJoinResponse) _then) =
      _$WatchTogetherJoinResponseCopyWithImpl;
  @useResult
  $Res call(
      {WatchTogetherSession session,
      @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken});

  $WatchTogetherSessionCopyWith<$Res> get session;
}

/// @nodoc
class _$WatchTogetherJoinResponseCopyWithImpl<$Res>
    implements $WatchTogetherJoinResponseCopyWith<$Res> {
  _$WatchTogetherJoinResponseCopyWithImpl(this._self, this._then);

  final WatchTogetherJoinResponse _self;
  final $Res Function(WatchTogetherJoinResponse) _then;

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? voiceToken = null,
  }) {
    return _then(_self.copyWith(
      session: null == session
          ? _self.session
          : session // ignore: cast_nullable_to_non_nullable
              as WatchTogetherSession,
      voiceToken: null == voiceToken
          ? _self.voiceToken
          : voiceToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WatchTogetherSessionCopyWith<$Res> get session {
    return $WatchTogetherSessionCopyWith<$Res>(_self.session, (value) {
      return _then(_self.copyWith(session: value));
    });
  }
}

/// Adds pattern-matching-related methods to [WatchTogetherJoinResponse].
extension WatchTogetherJoinResponsePatterns on WatchTogetherJoinResponse {
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
    TResult Function(_WatchTogetherJoinResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse() when $default != null:
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
    TResult Function(_WatchTogetherJoinResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse():
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
    TResult? Function(_WatchTogetherJoinResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse() when $default != null:
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
    TResult Function(WatchTogetherSession session,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse() when $default != null:
        return $default(_that.session, _that.voiceToken);
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
    TResult Function(WatchTogetherSession session,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse():
        return $default(_that.session, _that.voiceToken);
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
    TResult? Function(WatchTogetherSession session,
            @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WatchTogetherJoinResponse() when $default != null:
        return $default(_that.session, _that.voiceToken);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WatchTogetherJoinResponse implements WatchTogetherJoinResponse {
  const _WatchTogetherJoinResponse(
      {required this.session,
      @JsonKey(name: 'voice_token', defaultValue: '') this.voiceToken = ''});
  factory _WatchTogetherJoinResponse.fromJson(Map<String, dynamic> json) =>
      _$WatchTogetherJoinResponseFromJson(json);

  @override
  final WatchTogetherSession session;
  @override
  @JsonKey(name: 'voice_token', defaultValue: '')
  final String voiceToken;

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WatchTogetherJoinResponseCopyWith<_WatchTogetherJoinResponse>
      get copyWith =>
          __$WatchTogetherJoinResponseCopyWithImpl<_WatchTogetherJoinResponse>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WatchTogetherJoinResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WatchTogetherJoinResponse &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.voiceToken, voiceToken) ||
                other.voiceToken == voiceToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, session, voiceToken);

  @override
  String toString() {
    return 'WatchTogetherJoinResponse(session: $session, voiceToken: $voiceToken)';
  }
}

/// @nodoc
abstract mixin class _$WatchTogetherJoinResponseCopyWith<$Res>
    implements $WatchTogetherJoinResponseCopyWith<$Res> {
  factory _$WatchTogetherJoinResponseCopyWith(_WatchTogetherJoinResponse value,
          $Res Function(_WatchTogetherJoinResponse) _then) =
      __$WatchTogetherJoinResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {WatchTogetherSession session,
      @JsonKey(name: 'voice_token', defaultValue: '') String voiceToken});

  @override
  $WatchTogetherSessionCopyWith<$Res> get session;
}

/// @nodoc
class __$WatchTogetherJoinResponseCopyWithImpl<$Res>
    implements _$WatchTogetherJoinResponseCopyWith<$Res> {
  __$WatchTogetherJoinResponseCopyWithImpl(this._self, this._then);

  final _WatchTogetherJoinResponse _self;
  final $Res Function(_WatchTogetherJoinResponse) _then;

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? session = null,
    Object? voiceToken = null,
  }) {
    return _then(_WatchTogetherJoinResponse(
      session: null == session
          ? _self.session
          : session // ignore: cast_nullable_to_non_nullable
              as WatchTogetherSession,
      voiceToken: null == voiceToken
          ? _self.voiceToken
          : voiceToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of WatchTogetherJoinResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WatchTogetherSessionCopyWith<$Res> get session {
    return $WatchTogetherSessionCopyWith<$Res>(_self.session, (value) {
      return _then(_self.copyWith(session: value));
    });
  }
}

// dart format on
