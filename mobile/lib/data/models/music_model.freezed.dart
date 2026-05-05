// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'music_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MusicItem {
  String get id;
  MusicType get type;
  String get name;
  String get artistName;
  String? get albumName;
  int? get durationMs;
  String? get imageUrl;
  String? get previewUrl;
  String? get externalUrl;
  String get source;

  /// Create a copy of MusicItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicItemCopyWith<MusicItem> get copyWith =>
      _$MusicItemCopyWithImpl<MusicItem>(this as MusicItem, _$identity);

  /// Serializes this MusicItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.artistName, artistName) ||
                other.artistName == artistName) &&
            (identical(other.albumName, albumName) ||
                other.albumName == albumName) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.previewUrl, previewUrl) ||
                other.previewUrl == previewUrl) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, name, artistName,
      albumName, durationMs, imageUrl, previewUrl, externalUrl, source);

  @override
  String toString() {
    return 'MusicItem(id: $id, type: $type, name: $name, artistName: $artistName, albumName: $albumName, durationMs: $durationMs, imageUrl: $imageUrl, previewUrl: $previewUrl, externalUrl: $externalUrl, source: $source)';
  }
}

/// @nodoc
abstract mixin class $MusicItemCopyWith<$Res> {
  factory $MusicItemCopyWith(MusicItem value, $Res Function(MusicItem) _then) =
      _$MusicItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      MusicType type,
      String name,
      String artistName,
      String? albumName,
      int? durationMs,
      String? imageUrl,
      String? previewUrl,
      String? externalUrl,
      String source});
}

/// @nodoc
class _$MusicItemCopyWithImpl<$Res> implements $MusicItemCopyWith<$Res> {
  _$MusicItemCopyWithImpl(this._self, this._then);

  final MusicItem _self;
  final $Res Function(MusicItem) _then;

  /// Create a copy of MusicItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? artistName = null,
    Object? albumName = freezed,
    Object? durationMs = freezed,
    Object? imageUrl = freezed,
    Object? previewUrl = freezed,
    Object? externalUrl = freezed,
    Object? source = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MusicType,
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
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      previewUrl: freezed == previewUrl
          ? _self.previewUrl
          : previewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MusicItem].
extension MusicItemPatterns on MusicItem {
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
    TResult Function(_MusicItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicItem() when $default != null:
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
    TResult Function(_MusicItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicItem():
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
    TResult? Function(_MusicItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicItem() when $default != null:
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
            MusicType type,
            String name,
            String artistName,
            String? albumName,
            int? durationMs,
            String? imageUrl,
            String? previewUrl,
            String? externalUrl,
            String source)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicItem() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.name,
            _that.artistName,
            _that.albumName,
            _that.durationMs,
            _that.imageUrl,
            _that.previewUrl,
            _that.externalUrl,
            _that.source);
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
            MusicType type,
            String name,
            String artistName,
            String? albumName,
            int? durationMs,
            String? imageUrl,
            String? previewUrl,
            String? externalUrl,
            String source)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicItem():
        return $default(
            _that.id,
            _that.type,
            _that.name,
            _that.artistName,
            _that.albumName,
            _that.durationMs,
            _that.imageUrl,
            _that.previewUrl,
            _that.externalUrl,
            _that.source);
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
            MusicType type,
            String name,
            String artistName,
            String? albumName,
            int? durationMs,
            String? imageUrl,
            String? previewUrl,
            String? externalUrl,
            String source)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicItem() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.name,
            _that.artistName,
            _that.albumName,
            _that.durationMs,
            _that.imageUrl,
            _that.previewUrl,
            _that.externalUrl,
            _that.source);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MusicItem implements MusicItem {
  const _MusicItem(
      {required this.id,
      required this.type,
      required this.name,
      required this.artistName,
      this.albumName,
      this.durationMs,
      this.imageUrl,
      this.previewUrl,
      this.externalUrl,
      this.source = 'appleMusic'});
  factory _MusicItem.fromJson(Map<String, dynamic> json) =>
      _$MusicItemFromJson(json);

  @override
  final String id;
  @override
  final MusicType type;
  @override
  final String name;
  @override
  final String artistName;
  @override
  final String? albumName;
  @override
  final int? durationMs;
  @override
  final String? imageUrl;
  @override
  final String? previewUrl;
  @override
  final String? externalUrl;
  @override
  @JsonKey()
  final String source;

  /// Create a copy of MusicItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicItemCopyWith<_MusicItem> get copyWith =>
      __$MusicItemCopyWithImpl<_MusicItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MusicItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.artistName, artistName) ||
                other.artistName == artistName) &&
            (identical(other.albumName, albumName) ||
                other.albumName == albumName) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.previewUrl, previewUrl) ||
                other.previewUrl == previewUrl) &&
            (identical(other.externalUrl, externalUrl) ||
                other.externalUrl == externalUrl) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, name, artistName,
      albumName, durationMs, imageUrl, previewUrl, externalUrl, source);

  @override
  String toString() {
    return 'MusicItem(id: $id, type: $type, name: $name, artistName: $artistName, albumName: $albumName, durationMs: $durationMs, imageUrl: $imageUrl, previewUrl: $previewUrl, externalUrl: $externalUrl, source: $source)';
  }
}

/// @nodoc
abstract mixin class _$MusicItemCopyWith<$Res>
    implements $MusicItemCopyWith<$Res> {
  factory _$MusicItemCopyWith(
          _MusicItem value, $Res Function(_MusicItem) _then) =
      __$MusicItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      MusicType type,
      String name,
      String artistName,
      String? albumName,
      int? durationMs,
      String? imageUrl,
      String? previewUrl,
      String? externalUrl,
      String source});
}

/// @nodoc
class __$MusicItemCopyWithImpl<$Res> implements _$MusicItemCopyWith<$Res> {
  __$MusicItemCopyWithImpl(this._self, this._then);

  final _MusicItem _self;
  final $Res Function(_MusicItem) _then;

  /// Create a copy of MusicItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? artistName = null,
    Object? albumName = freezed,
    Object? durationMs = freezed,
    Object? imageUrl = freezed,
    Object? previewUrl = freezed,
    Object? externalUrl = freezed,
    Object? source = null,
  }) {
    return _then(_MusicItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MusicType,
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
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      previewUrl: freezed == previewUrl
          ? _self.previewUrl
          : previewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUrl: freezed == externalUrl
          ? _self.externalUrl
          : externalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
