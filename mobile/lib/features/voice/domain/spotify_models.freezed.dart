// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spotify_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpotifySession {
  /// Encrypted session cookies from Spotify WebView login
  Map<String, String> get cookies;

  /// When the session was established
  DateTime get connectedAt;

  /// Optional display name of the connected Spotify account
  String? get displayName;

  /// Optional Spotify user ID
  String? get spotifyUserId;

  /// Create a copy of SpotifySession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotifySessionCopyWith<SpotifySession> get copyWith =>
      _$SpotifySessionCopyWithImpl<SpotifySession>(
          this as SpotifySession, _$identity);

  /// Serializes this SpotifySession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotifySession &&
            const DeepCollectionEquality().equals(other.cookies, cookies) &&
            (identical(other.connectedAt, connectedAt) ||
                other.connectedAt == connectedAt) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.spotifyUserId, spotifyUserId) ||
                other.spotifyUserId == spotifyUserId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(cookies),
      connectedAt,
      displayName,
      spotifyUserId);

  @override
  String toString() {
    return 'SpotifySession(cookies: $cookies, connectedAt: $connectedAt, displayName: $displayName, spotifyUserId: $spotifyUserId)';
  }
}

/// @nodoc
abstract mixin class $SpotifySessionCopyWith<$Res> {
  factory $SpotifySessionCopyWith(
          SpotifySession value, $Res Function(SpotifySession) _then) =
      _$SpotifySessionCopyWithImpl;
  @useResult
  $Res call(
      {Map<String, String> cookies,
      DateTime connectedAt,
      String? displayName,
      String? spotifyUserId});
}

/// @nodoc
class _$SpotifySessionCopyWithImpl<$Res>
    implements $SpotifySessionCopyWith<$Res> {
  _$SpotifySessionCopyWithImpl(this._self, this._then);

  final SpotifySession _self;
  final $Res Function(SpotifySession) _then;

  /// Create a copy of SpotifySession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cookies = null,
    Object? connectedAt = null,
    Object? displayName = freezed,
    Object? spotifyUserId = freezed,
  }) {
    return _then(_self.copyWith(
      cookies: null == cookies
          ? _self.cookies
          : cookies // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      connectedAt: null == connectedAt
          ? _self.connectedAt
          : connectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      spotifyUserId: freezed == spotifyUserId
          ? _self.spotifyUserId
          : spotifyUserId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SpotifySession].
extension SpotifySessionPatterns on SpotifySession {
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
    TResult Function(_SpotifySession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifySession() when $default != null:
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
    TResult Function(_SpotifySession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifySession():
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
    TResult? Function(_SpotifySession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifySession() when $default != null:
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
    TResult Function(Map<String, String> cookies, DateTime connectedAt,
            String? displayName, String? spotifyUserId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifySession() when $default != null:
        return $default(_that.cookies, _that.connectedAt, _that.displayName,
            _that.spotifyUserId);
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
    TResult Function(Map<String, String> cookies, DateTime connectedAt,
            String? displayName, String? spotifyUserId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifySession():
        return $default(_that.cookies, _that.connectedAt, _that.displayName,
            _that.spotifyUserId);
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
    TResult? Function(Map<String, String> cookies, DateTime connectedAt,
            String? displayName, String? spotifyUserId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifySession() when $default != null:
        return $default(_that.cookies, _that.connectedAt, _that.displayName,
            _that.spotifyUserId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SpotifySession implements SpotifySession {
  const _SpotifySession(
      {required final Map<String, String> cookies,
      required this.connectedAt,
      this.displayName,
      this.spotifyUserId})
      : _cookies = cookies;
  factory _SpotifySession.fromJson(Map<String, dynamic> json) =>
      _$SpotifySessionFromJson(json);

  /// Encrypted session cookies from Spotify WebView login
  final Map<String, String> _cookies;

  /// Encrypted session cookies from Spotify WebView login
  @override
  Map<String, String> get cookies {
    if (_cookies is EqualUnmodifiableMapView) return _cookies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_cookies);
  }

  /// When the session was established
  @override
  final DateTime connectedAt;

  /// Optional display name of the connected Spotify account
  @override
  final String? displayName;

  /// Optional Spotify user ID
  @override
  final String? spotifyUserId;

  /// Create a copy of SpotifySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SpotifySessionCopyWith<_SpotifySession> get copyWith =>
      __$SpotifySessionCopyWithImpl<_SpotifySession>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SpotifySessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SpotifySession &&
            const DeepCollectionEquality().equals(other._cookies, _cookies) &&
            (identical(other.connectedAt, connectedAt) ||
                other.connectedAt == connectedAt) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.spotifyUserId, spotifyUserId) ||
                other.spotifyUserId == spotifyUserId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_cookies),
      connectedAt,
      displayName,
      spotifyUserId);

  @override
  String toString() {
    return 'SpotifySession(cookies: $cookies, connectedAt: $connectedAt, displayName: $displayName, spotifyUserId: $spotifyUserId)';
  }
}

/// @nodoc
abstract mixin class _$SpotifySessionCopyWith<$Res>
    implements $SpotifySessionCopyWith<$Res> {
  factory _$SpotifySessionCopyWith(
          _SpotifySession value, $Res Function(_SpotifySession) _then) =
      __$SpotifySessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Map<String, String> cookies,
      DateTime connectedAt,
      String? displayName,
      String? spotifyUserId});
}

/// @nodoc
class __$SpotifySessionCopyWithImpl<$Res>
    implements _$SpotifySessionCopyWith<$Res> {
  __$SpotifySessionCopyWithImpl(this._self, this._then);

  final _SpotifySession _self;
  final $Res Function(_SpotifySession) _then;

  /// Create a copy of SpotifySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? cookies = null,
    Object? connectedAt = null,
    Object? displayName = freezed,
    Object? spotifyUserId = freezed,
  }) {
    return _then(_SpotifySession(
      cookies: null == cookies
          ? _self._cookies
          : cookies // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      connectedAt: null == connectedAt
          ? _self.connectedAt
          : connectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      spotifyUserId: freezed == spotifyUserId
          ? _self.spotifyUserId
          : spotifyUserId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$SpotifyTrack {
  /// Spotify track ID (e.g. "6l8GvAyoUZwFDuSbsxDpSR")
  String get id;

  /// Track display name
  String get name;

  /// Primary artist name
  String get artistName;

  /// Album name, if available
  String? get albumName;

  /// Track duration in milliseconds
  int get durationMs;

  /// Album artwork URL (300x300 preferred)
  String? get imageUrl;

  /// Spotify deep-link URL
  String? get externalUrl;

  /// URI used for playback (e.g. "spotify:track:6l8GvAyoUZwFDuSbsxDpSR")
  String? get uri;

  /// Create a copy of SpotifyTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotifyTrackCopyWith<SpotifyTrack> get copyWith =>
      _$SpotifyTrackCopyWithImpl<SpotifyTrack>(
          this as SpotifyTrack, _$identity);

  /// Serializes this SpotifyTrack to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotifyTrack &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.artistName, artistName) ||
                other.artistName == artistName) &&
            (identical(other.albumName, albumName) ||
                other.albumName == albumName) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl) &&
            (identical(other.uri, uri) || other.uri == uri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, artistName, albumName,
      durationMs, imageUrl, externalUrl, uri);

  @override
  String toString() {
    return 'SpotifyTrack(id: $id, name: $name, artistName: $artistName, albumName: $albumName, durationMs: $durationMs, imageUrl: $imageUrl, externalUrl: $externalUrl, uri: $uri)';
  }
}

/// @nodoc
abstract mixin class $SpotifyTrackCopyWith<$Res> {
  factory $SpotifyTrackCopyWith(
          SpotifyTrack value, $Res Function(SpotifyTrack) _then) =
      _$SpotifyTrackCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String artistName,
      String? albumName,
      int durationMs,
      String? imageUrl,
      String? externalUrl,
      String? uri});
}

/// @nodoc
class _$SpotifyTrackCopyWithImpl<$Res> implements $SpotifyTrackCopyWith<$Res> {
  _$SpotifyTrackCopyWithImpl(this._self, this._then);

  final SpotifyTrack _self;
  final $Res Function(SpotifyTrack) _then;

  /// Create a copy of SpotifyTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artistName = null,
    Object? albumName = freezed,
    Object? durationMs = null,
    Object? imageUrl = freezed,
    Object? externalUrl = freezed,
    Object? uri = freezed,
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
      artistName: null == artistName
          ? _self.artistName
          : artistName // ignore: cast_nullable_to_non_nullable
              as String,
      albumName: freezed == albumName
          ? _self.albumName
          : albumName // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: null == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      uri: freezed == uri
          ? _self.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SpotifyTrack].
extension SpotifyTrackPatterns on SpotifyTrack {
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
    TResult Function(_SpotifyTrack value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack() when $default != null:
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
    TResult Function(_SpotifyTrack value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack():
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
    TResult? Function(_SpotifyTrack value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack() when $default != null:
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
            String artistName,
            String? albumName,
            int durationMs,
            String? imageUrl,
            String? externalUrl,
            String? uri)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack() when $default != null:
        return $default(_that.id, _that.name, _that.artistName, _that.albumName,
            _that.durationMs, _that.imageUrl, _that.externalUrl, _that.uri);
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
            String artistName,
            String? albumName,
            int durationMs,
            String? imageUrl,
            String? externalUrl,
            String? uri)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack():
        return $default(_that.id, _that.name, _that.artistName, _that.albumName,
            _that.durationMs, _that.imageUrl, _that.externalUrl, _that.uri);
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
            String artistName,
            String? albumName,
            int durationMs,
            String? imageUrl,
            String? externalUrl,
            String? uri)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyTrack() when $default != null:
        return $default(_that.id, _that.name, _that.artistName, _that.albumName,
            _that.durationMs, _that.imageUrl, _that.externalUrl, _that.uri);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SpotifyTrack implements SpotifyTrack {
  const _SpotifyTrack(
      {required this.id,
      required this.name,
      required this.artistName,
      this.albumName,
      this.durationMs = 0,
      this.imageUrl,
      this.externalUrl,
      this.uri});
  factory _SpotifyTrack.fromJson(Map<String, dynamic> json) =>
      _$SpotifyTrackFromJson(json);

  /// Spotify track ID (e.g. "6l8GvAyoUZwFDuSbsxDpSR")
  @override
  final String id;

  /// Track display name
  @override
  final String name;

  /// Primary artist name
  @override
  final String artistName;

  /// Album name, if available
  @override
  final String? albumName;

  /// Track duration in milliseconds
  @override
  @JsonKey()
  final int durationMs;

  /// Album artwork URL (300x300 preferred)
  @override
  final String? imageUrl;

  /// Spotify deep-link URL
  @override
  final String? externalUrl;

  /// URI used for playback (e.g. "spotify:track:6l8GvAyoUZwFDuSbsxDpSR")
  @override
  final String? uri;

  /// Create a copy of SpotifyTrack
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SpotifyTrackCopyWith<_SpotifyTrack> get copyWith =>
      __$SpotifyTrackCopyWithImpl<_SpotifyTrack>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SpotifyTrackToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SpotifyTrack &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.artistName, artistName) ||
                other.artistName == artistName) &&
            (identical(other.albumName, albumName) ||
                other.albumName == albumName) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl) &&
            (identical(other.uri, uri) || other.uri == uri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, artistName, albumName,
      durationMs, imageUrl, externalUrl, uri);

  @override
  String toString() {
    return 'SpotifyTrack(id: $id, name: $name, artistName: $artistName, albumName: $albumName, durationMs: $durationMs, imageUrl: $imageUrl, externalUrl: $externalUrl, uri: $uri)';
  }
}

/// @nodoc
abstract mixin class _$SpotifyTrackCopyWith<$Res>
    implements $SpotifyTrackCopyWith<$Res> {
  factory _$SpotifyTrackCopyWith(
          _SpotifyTrack value, $Res Function(_SpotifyTrack) _then) =
      __$SpotifyTrackCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String artistName,
      String? albumName,
      int durationMs,
      String? imageUrl,
      String? externalUrl,
      String? uri});
}

/// @nodoc
class __$SpotifyTrackCopyWithImpl<$Res>
    implements _$SpotifyTrackCopyWith<$Res> {
  __$SpotifyTrackCopyWithImpl(this._self, this._then);

  final _SpotifyTrack _self;
  final $Res Function(_SpotifyTrack) _then;

  /// Create a copy of SpotifyTrack
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artistName = null,
    Object? albumName = freezed,
    Object? durationMs = null,
    Object? imageUrl = freezed,
    Object? externalUrl = freezed,
    Object? uri = freezed,
  }) {
    return _then(_SpotifyTrack(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      artistName: null == artistName
          ? _self.artistName
          : artistName // ignore: cast_nullable_to_non_nullable
              as String,
      albumName: freezed == albumName
          ? _self.albumName
          : albumName // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: null == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      uri: freezed == uri
          ? _self.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$PlaybackState {
  /// Whether music is currently playing
  bool get isPlaying;

  /// Current playback position in milliseconds
  int get positionMs;

  /// Total track duration in milliseconds
  int get durationMs;

  /// The track currently playing (null if nothing is playing)
  SpotifyTrack? get currentTrack;

  /// Name of the active playback device
  String? get deviceName;

  /// Current volume level (0–100)
  int get volumePercent;

  /// Whether shuffle is enabled
  bool get shuffleState;

  /// Repeat mode: "off", "track", "context"
  String get repeatState;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlaybackStateCopyWith<PlaybackState> get copyWith =>
      _$PlaybackStateCopyWithImpl<PlaybackState>(
          this as PlaybackState, _$identity);

  /// Serializes this PlaybackState to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlaybackState &&
            (identical(other.isPlaying, isPlaying) ||
                other.isPlaying == isPlaying) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.currentTrack, currentTrack) ||
                other.currentTrack == currentTrack) &&
            (identical(other.deviceName, deviceName) ||
                other.deviceName == deviceName) &&
            (identical(other.volumePercent, volumePercent) ||
                other.volumePercent == volumePercent) &&
            (identical(other.shuffleState, shuffleState) ||
                other.shuffleState == shuffleState) &&
            (identical(other.repeatState, repeatState) ||
                other.repeatState == repeatState));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      isPlaying,
      positionMs,
      durationMs,
      currentTrack,
      deviceName,
      volumePercent,
      shuffleState,
      repeatState);

  @override
  String toString() {
    return 'PlaybackState(isPlaying: $isPlaying, positionMs: $positionMs, durationMs: $durationMs, currentTrack: $currentTrack, deviceName: $deviceName, volumePercent: $volumePercent, shuffleState: $shuffleState, repeatState: $repeatState)';
  }
}

/// @nodoc
abstract mixin class $PlaybackStateCopyWith<$Res> {
  factory $PlaybackStateCopyWith(
          PlaybackState value, $Res Function(PlaybackState) _then) =
      _$PlaybackStateCopyWithImpl;
  @useResult
  $Res call(
      {bool isPlaying,
      int positionMs,
      int durationMs,
      SpotifyTrack? currentTrack,
      String? deviceName,
      int volumePercent,
      bool shuffleState,
      String repeatState});

  $SpotifyTrackCopyWith<$Res>? get currentTrack;
}

/// @nodoc
class _$PlaybackStateCopyWithImpl<$Res>
    implements $PlaybackStateCopyWith<$Res> {
  _$PlaybackStateCopyWithImpl(this._self, this._then);

  final PlaybackState _self;
  final $Res Function(PlaybackState) _then;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isPlaying = null,
    Object? positionMs = null,
    Object? durationMs = null,
    Object? currentTrack = freezed,
    Object? deviceName = freezed,
    Object? volumePercent = null,
    Object? shuffleState = null,
    Object? repeatState = null,
  }) {
    return _then(_self.copyWith(
      isPlaying: null == isPlaying
          ? _self.isPlaying
          : isPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      positionMs: null == positionMs
          ? _self.positionMs
          : positionMs // ignore: cast_nullable_to_non_nullable
              as int,
      durationMs: null == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      currentTrack: freezed == currentTrack
          ? _self.currentTrack
          : currentTrack // ignore: cast_nullable_to_non_nullable
              as SpotifyTrack?,
      deviceName: freezed == deviceName
          ? _self.deviceName
          : deviceName // ignore: cast_nullable_to_non_nullable
              as String?,
      volumePercent: null == volumePercent
          ? _self.volumePercent
          : volumePercent // ignore: cast_nullable_to_non_nullable
              as int,
      shuffleState: null == shuffleState
          ? _self.shuffleState
          : shuffleState // ignore: cast_nullable_to_non_nullable
              as bool,
      repeatState: null == repeatState
          ? _self.repeatState
          : repeatState // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SpotifyTrackCopyWith<$Res>? get currentTrack {
    if (_self.currentTrack == null) {
      return null;
    }

    return $SpotifyTrackCopyWith<$Res>(_self.currentTrack!, (value) {
      return _then(_self.copyWith(currentTrack: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PlaybackState].
extension PlaybackStatePatterns on PlaybackState {
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
    TResult Function(_PlaybackState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlaybackState() when $default != null:
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
    TResult Function(_PlaybackState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlaybackState():
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
    TResult? Function(_PlaybackState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlaybackState() when $default != null:
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
            bool isPlaying,
            int positionMs,
            int durationMs,
            SpotifyTrack? currentTrack,
            String? deviceName,
            int volumePercent,
            bool shuffleState,
            String repeatState)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlaybackState() when $default != null:
        return $default(
            _that.isPlaying,
            _that.positionMs,
            _that.durationMs,
            _that.currentTrack,
            _that.deviceName,
            _that.volumePercent,
            _that.shuffleState,
            _that.repeatState);
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
            bool isPlaying,
            int positionMs,
            int durationMs,
            SpotifyTrack? currentTrack,
            String? deviceName,
            int volumePercent,
            bool shuffleState,
            String repeatState)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlaybackState():
        return $default(
            _that.isPlaying,
            _that.positionMs,
            _that.durationMs,
            _that.currentTrack,
            _that.deviceName,
            _that.volumePercent,
            _that.shuffleState,
            _that.repeatState);
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
            bool isPlaying,
            int positionMs,
            int durationMs,
            SpotifyTrack? currentTrack,
            String? deviceName,
            int volumePercent,
            bool shuffleState,
            String repeatState)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlaybackState() when $default != null:
        return $default(
            _that.isPlaying,
            _that.positionMs,
            _that.durationMs,
            _that.currentTrack,
            _that.deviceName,
            _that.volumePercent,
            _that.shuffleState,
            _that.repeatState);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlaybackState implements PlaybackState {
  const _PlaybackState(
      {this.isPlaying = false,
      this.positionMs = 0,
      this.durationMs = 0,
      this.currentTrack,
      this.deviceName,
      this.volumePercent = 50,
      this.shuffleState = false,
      this.repeatState = 'off'});
  factory _PlaybackState.fromJson(Map<String, dynamic> json) =>
      _$PlaybackStateFromJson(json);

  /// Whether music is currently playing
  @override
  @JsonKey()
  final bool isPlaying;

  /// Current playback position in milliseconds
  @override
  @JsonKey()
  final int positionMs;

  /// Total track duration in milliseconds
  @override
  @JsonKey()
  final int durationMs;

  /// The track currently playing (null if nothing is playing)
  @override
  final SpotifyTrack? currentTrack;

  /// Name of the active playback device
  @override
  final String? deviceName;

  /// Current volume level (0–100)
  @override
  @JsonKey()
  final int volumePercent;

  /// Whether shuffle is enabled
  @override
  @JsonKey()
  final bool shuffleState;

  /// Repeat mode: "off", "track", "context"
  @override
  @JsonKey()
  final String repeatState;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlaybackStateCopyWith<_PlaybackState> get copyWith =>
      __$PlaybackStateCopyWithImpl<_PlaybackState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlaybackStateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlaybackState &&
            (identical(other.isPlaying, isPlaying) ||
                other.isPlaying == isPlaying) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.currentTrack, currentTrack) ||
                other.currentTrack == currentTrack) &&
            (identical(other.deviceName, deviceName) ||
                other.deviceName == deviceName) &&
            (identical(other.volumePercent, volumePercent) ||
                other.volumePercent == volumePercent) &&
            (identical(other.shuffleState, shuffleState) ||
                other.shuffleState == shuffleState) &&
            (identical(other.repeatState, repeatState) ||
                other.repeatState == repeatState));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      isPlaying,
      positionMs,
      durationMs,
      currentTrack,
      deviceName,
      volumePercent,
      shuffleState,
      repeatState);

  @override
  String toString() {
    return 'PlaybackState(isPlaying: $isPlaying, positionMs: $positionMs, durationMs: $durationMs, currentTrack: $currentTrack, deviceName: $deviceName, volumePercent: $volumePercent, shuffleState: $shuffleState, repeatState: $repeatState)';
  }
}

/// @nodoc
abstract mixin class _$PlaybackStateCopyWith<$Res>
    implements $PlaybackStateCopyWith<$Res> {
  factory _$PlaybackStateCopyWith(
          _PlaybackState value, $Res Function(_PlaybackState) _then) =
      __$PlaybackStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool isPlaying,
      int positionMs,
      int durationMs,
      SpotifyTrack? currentTrack,
      String? deviceName,
      int volumePercent,
      bool shuffleState,
      String repeatState});

  @override
  $SpotifyTrackCopyWith<$Res>? get currentTrack;
}

/// @nodoc
class __$PlaybackStateCopyWithImpl<$Res>
    implements _$PlaybackStateCopyWith<$Res> {
  __$PlaybackStateCopyWithImpl(this._self, this._then);

  final _PlaybackState _self;
  final $Res Function(_PlaybackState) _then;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isPlaying = null,
    Object? positionMs = null,
    Object? durationMs = null,
    Object? currentTrack = freezed,
    Object? deviceName = freezed,
    Object? volumePercent = null,
    Object? shuffleState = null,
    Object? repeatState = null,
  }) {
    return _then(_PlaybackState(
      isPlaying: null == isPlaying
          ? _self.isPlaying
          : isPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      positionMs: null == positionMs
          ? _self.positionMs
          : positionMs // ignore: cast_nullable_to_non_nullable
              as int,
      durationMs: null == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      currentTrack: freezed == currentTrack
          ? _self.currentTrack
          : currentTrack // ignore: cast_nullable_to_non_nullable
              as SpotifyTrack?,
      deviceName: freezed == deviceName
          ? _self.deviceName
          : deviceName // ignore: cast_nullable_to_non_nullable
              as String?,
      volumePercent: null == volumePercent
          ? _self.volumePercent
          : volumePercent // ignore: cast_nullable_to_non_nullable
              as int,
      shuffleState: null == shuffleState
          ? _self.shuffleState
          : shuffleState // ignore: cast_nullable_to_non_nullable
              as bool,
      repeatState: null == repeatState
          ? _self.repeatState
          : repeatState // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SpotifyTrackCopyWith<$Res>? get currentTrack {
    if (_self.currentTrack == null) {
      return null;
    }

    return $SpotifyTrackCopyWith<$Res>(_self.currentTrack!, (value) {
      return _then(_self.copyWith(currentTrack: value));
    });
  }
}

/// @nodoc
mixin _$SpotifyPlaylist {
  /// Playlist ID
  String get id;

  /// Playlist display name
  String get name;

  /// Optional description
  String? get description;

  /// Cover image URL
  String? get imageUrl;

  /// Number of tracks in the playlist
  int get trackCount;

  /// Whether this playlist is public
  bool get isPublic;

  /// Spotify deep-link URL
  String? get externalUrl;

  /// Create a copy of SpotifyPlaylist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotifyPlaylistCopyWith<SpotifyPlaylist> get copyWith =>
      _$SpotifyPlaylistCopyWithImpl<SpotifyPlaylist>(
          this as SpotifyPlaylist, _$identity);

  /// Serializes this SpotifyPlaylist to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotifyPlaylist &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.trackCount, trackCount) ||
                other.trackCount == trackCount) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description, imageUrl,
      trackCount, isPublic, externalUrl);

  @override
  String toString() {
    return 'SpotifyPlaylist(id: $id, name: $name, description: $description, imageUrl: $imageUrl, trackCount: $trackCount, isPublic: $isPublic, externalUrl: $externalUrl)';
  }
}

/// @nodoc
abstract mixin class $SpotifyPlaylistCopyWith<$Res> {
  factory $SpotifyPlaylistCopyWith(
          SpotifyPlaylist value, $Res Function(SpotifyPlaylist) _then) =
      _$SpotifyPlaylistCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String? imageUrl,
      int trackCount,
      bool isPublic,
      String? externalUrl});
}

/// @nodoc
class _$SpotifyPlaylistCopyWithImpl<$Res>
    implements $SpotifyPlaylistCopyWith<$Res> {
  _$SpotifyPlaylistCopyWithImpl(this._self, this._then);

  final SpotifyPlaylist _self;
  final $Res Function(SpotifyPlaylist) _then;

  /// Create a copy of SpotifyPlaylist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? imageUrl = freezed,
    Object? trackCount = null,
    Object? isPublic = null,
    Object? externalUrl = freezed,
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      trackCount: null == trackCount
          ? _self.trackCount
          : trackCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPublic: null == isPublic
          ? _self.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SpotifyPlaylist].
extension SpotifyPlaylistPatterns on SpotifyPlaylist {
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
    TResult Function(_SpotifyPlaylist value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist() when $default != null:
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
    TResult Function(_SpotifyPlaylist value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist():
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
    TResult? Function(_SpotifyPlaylist value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist() when $default != null:
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
            String? description,
            String? imageUrl,
            int trackCount,
            bool isPublic,
            String? externalUrl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist() when $default != null:
        return $default(_that.id, _that.name, _that.description, _that.imageUrl,
            _that.trackCount, _that.isPublic, _that.externalUrl);
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
            String? description,
            String? imageUrl,
            int trackCount,
            bool isPublic,
            String? externalUrl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist():
        return $default(_that.id, _that.name, _that.description, _that.imageUrl,
            _that.trackCount, _that.isPublic, _that.externalUrl);
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
            String? description,
            String? imageUrl,
            int trackCount,
            bool isPublic,
            String? externalUrl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyPlaylist() when $default != null:
        return $default(_that.id, _that.name, _that.description, _that.imageUrl,
            _that.trackCount, _that.isPublic, _that.externalUrl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SpotifyPlaylist implements SpotifyPlaylist {
  const _SpotifyPlaylist(
      {required this.id,
      required this.name,
      this.description,
      this.imageUrl,
      this.trackCount = 0,
      this.isPublic = false,
      this.externalUrl});
  factory _SpotifyPlaylist.fromJson(Map<String, dynamic> json) =>
      _$SpotifyPlaylistFromJson(json);

  /// Playlist ID
  @override
  final String id;

  /// Playlist display name
  @override
  final String name;

  /// Optional description
  @override
  final String? description;

  /// Cover image URL
  @override
  final String? imageUrl;

  /// Number of tracks in the playlist
  @override
  @JsonKey()
  final int trackCount;

  /// Whether this playlist is public
  @override
  @JsonKey()
  final bool isPublic;

  /// Spotify deep-link URL
  @override
  final String? externalUrl;

  /// Create a copy of SpotifyPlaylist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SpotifyPlaylistCopyWith<_SpotifyPlaylist> get copyWith =>
      __$SpotifyPlaylistCopyWithImpl<_SpotifyPlaylist>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SpotifyPlaylistToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SpotifyPlaylist &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.trackCount, trackCount) ||
                other.trackCount == trackCount) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description, imageUrl,
      trackCount, isPublic, externalUrl);

  @override
  String toString() {
    return 'SpotifyPlaylist(id: $id, name: $name, description: $description, imageUrl: $imageUrl, trackCount: $trackCount, isPublic: $isPublic, externalUrl: $externalUrl)';
  }
}

/// @nodoc
abstract mixin class _$SpotifyPlaylistCopyWith<$Res>
    implements $SpotifyPlaylistCopyWith<$Res> {
  factory _$SpotifyPlaylistCopyWith(
          _SpotifyPlaylist value, $Res Function(_SpotifyPlaylist) _then) =
      __$SpotifyPlaylistCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String? imageUrl,
      int trackCount,
      bool isPublic,
      String? externalUrl});
}

/// @nodoc
class __$SpotifyPlaylistCopyWithImpl<$Res>
    implements _$SpotifyPlaylistCopyWith<$Res> {
  __$SpotifyPlaylistCopyWithImpl(this._self, this._then);

  final _SpotifyPlaylist _self;
  final $Res Function(_SpotifyPlaylist) _then;

  /// Create a copy of SpotifyPlaylist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? imageUrl = freezed,
    Object? trackCount = null,
    Object? isPublic = null,
    Object? externalUrl = freezed,
  }) {
    return _then(_SpotifyPlaylist(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      trackCount: null == trackCount
          ? _self.trackCount
          : trackCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPublic: null == isPublic
          ? _self.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$SpotifyDevice {
  /// Device ID
  String get id;

  /// Human-readable device name (e.g. "iPhone 15 Pro")
  String get name;

  /// Device type: "Computer", "Smartphone", "Speaker", etc.
  String get type;

  /// Whether this is the currently active device
  bool get isActive;

  /// Current volume (0–100)
  int get volumePercent;

  /// Create a copy of SpotifyDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotifyDeviceCopyWith<SpotifyDevice> get copyWith =>
      _$SpotifyDeviceCopyWithImpl<SpotifyDevice>(
          this as SpotifyDevice, _$identity);

  /// Serializes this SpotifyDevice to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotifyDevice &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.volumePercent, volumePercent) ||
                other.volumePercent == volumePercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, type, isActive, volumePercent);

  @override
  String toString() {
    return 'SpotifyDevice(id: $id, name: $name, type: $type, isActive: $isActive, volumePercent: $volumePercent)';
  }
}

/// @nodoc
abstract mixin class $SpotifyDeviceCopyWith<$Res> {
  factory $SpotifyDeviceCopyWith(
          SpotifyDevice value, $Res Function(SpotifyDevice) _then) =
      _$SpotifyDeviceCopyWithImpl;
  @useResult
  $Res call(
      {String id, String name, String type, bool isActive, int volumePercent});
}

/// @nodoc
class _$SpotifyDeviceCopyWithImpl<$Res>
    implements $SpotifyDeviceCopyWith<$Res> {
  _$SpotifyDeviceCopyWithImpl(this._self, this._then);

  final SpotifyDevice _self;
  final $Res Function(SpotifyDevice) _then;

  /// Create a copy of SpotifyDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? isActive = null,
    Object? volumePercent = null,
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
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      volumePercent: null == volumePercent
          ? _self.volumePercent
          : volumePercent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [SpotifyDevice].
extension SpotifyDevicePatterns on SpotifyDevice {
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
    TResult Function(_SpotifyDevice value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice() when $default != null:
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
    TResult Function(_SpotifyDevice value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice():
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
    TResult? Function(_SpotifyDevice value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice() when $default != null:
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
    TResult Function(String id, String name, String type, bool isActive,
            int volumePercent)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice() when $default != null:
        return $default(_that.id, _that.name, _that.type, _that.isActive,
            _that.volumePercent);
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
    TResult Function(String id, String name, String type, bool isActive,
            int volumePercent)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice():
        return $default(_that.id, _that.name, _that.type, _that.isActive,
            _that.volumePercent);
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
    TResult? Function(String id, String name, String type, bool isActive,
            int volumePercent)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotifyDevice() when $default != null:
        return $default(_that.id, _that.name, _that.type, _that.isActive,
            _that.volumePercent);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SpotifyDevice implements SpotifyDevice {
  const _SpotifyDevice(
      {required this.id,
      required this.name,
      required this.type,
      this.isActive = false,
      this.volumePercent = 50});
  factory _SpotifyDevice.fromJson(Map<String, dynamic> json) =>
      _$SpotifyDeviceFromJson(json);

  /// Device ID
  @override
  final String id;

  /// Human-readable device name (e.g. "iPhone 15 Pro")
  @override
  final String name;

  /// Device type: "Computer", "Smartphone", "Speaker", etc.
  @override
  final String type;

  /// Whether this is the currently active device
  @override
  @JsonKey()
  final bool isActive;

  /// Current volume (0–100)
  @override
  @JsonKey()
  final int volumePercent;

  /// Create a copy of SpotifyDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SpotifyDeviceCopyWith<_SpotifyDevice> get copyWith =>
      __$SpotifyDeviceCopyWithImpl<_SpotifyDevice>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SpotifyDeviceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SpotifyDevice &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.volumePercent, volumePercent) ||
                other.volumePercent == volumePercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, type, isActive, volumePercent);

  @override
  String toString() {
    return 'SpotifyDevice(id: $id, name: $name, type: $type, isActive: $isActive, volumePercent: $volumePercent)';
  }
}

/// @nodoc
abstract mixin class _$SpotifyDeviceCopyWith<$Res>
    implements $SpotifyDeviceCopyWith<$Res> {
  factory _$SpotifyDeviceCopyWith(
          _SpotifyDevice value, $Res Function(_SpotifyDevice) _then) =
      __$SpotifyDeviceCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id, String name, String type, bool isActive, int volumePercent});
}

/// @nodoc
class __$SpotifyDeviceCopyWithImpl<$Res>
    implements _$SpotifyDeviceCopyWith<$Res> {
  __$SpotifyDeviceCopyWithImpl(this._self, this._then);

  final _SpotifyDevice _self;
  final $Res Function(_SpotifyDevice) _then;

  /// Create a copy of SpotifyDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? isActive = null,
    Object? volumePercent = null,
  }) {
    return _then(_SpotifyDevice(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      volumePercent: null == volumePercent
          ? _self.volumePercent
          : volumePercent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
