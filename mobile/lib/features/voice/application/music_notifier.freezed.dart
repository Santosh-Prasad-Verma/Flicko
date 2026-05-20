// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'music_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MusicState {
  List<MusicItem> get searchResults;
  List<MusicItem> get queue;
  MusicItem? get nowPlaying;
  bool get isPaused;
  bool get isLoading;
  double get volume;
  String? get error;

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MusicStateCopyWith<MusicState> get copyWith =>
      _$MusicStateCopyWithImpl<MusicState>(this as MusicState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MusicState &&
            const DeepCollectionEquality()
                .equals(other.searchResults, searchResults) &&
            const DeepCollectionEquality().equals(other.queue, queue) &&
            (identical(other.nowPlaying, nowPlaying) ||
                other.nowPlaying == nowPlaying) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.volume, volume) || other.volume == volume) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(searchResults),
      const DeepCollectionEquality().hash(queue),
      nowPlaying,
      isPaused,
      isLoading,
      volume,
      error);

  @override
  String toString() {
    return 'MusicState(searchResults: $searchResults, queue: $queue, nowPlaying: $nowPlaying, isPaused: $isPaused, isLoading: $isLoading, volume: $volume, error: $error)';
  }
}

/// @nodoc
abstract mixin class $MusicStateCopyWith<$Res> {
  factory $MusicStateCopyWith(
          MusicState value, $Res Function(MusicState) _then) =
      _$MusicStateCopyWithImpl;
  @useResult
  $Res call(
      {List<MusicItem> searchResults,
      List<MusicItem> queue,
      MusicItem? nowPlaying,
      bool isPaused,
      bool isLoading,
      double volume,
      String? error});

  $MusicItemCopyWith<$Res>? get nowPlaying;
}

/// @nodoc
class _$MusicStateCopyWithImpl<$Res> implements $MusicStateCopyWith<$Res> {
  _$MusicStateCopyWithImpl(this._self, this._then);

  final MusicState _self;
  final $Res Function(MusicState) _then;

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchResults = null,
    Object? queue = null,
    Object? nowPlaying = freezed,
    Object? isPaused = null,
    Object? isLoading = null,
    Object? volume = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      searchResults: null == searchResults
          ? _self.searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<MusicItem>,
      queue: null == queue
          ? _self.queue
          : queue // ignore: cast_nullable_to_non_nullable
              as List<MusicItem>,
      nowPlaying: freezed == nowPlaying
          ? _self.nowPlaying
          : nowPlaying // ignore: cast_nullable_to_non_nullable
              as MusicItem?,
      isPaused: null == isPaused
          ? _self.isPaused
          : isPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      volume: null == volume
          ? _self.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicItemCopyWith<$Res>? get nowPlaying {
    if (_self.nowPlaying == null) {
      return null;
    }

    return $MusicItemCopyWith<$Res>(_self.nowPlaying!, (value) {
      return _then(_self.copyWith(nowPlaying: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MusicState].
extension MusicStatePatterns on MusicState {
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
    TResult Function(_MusicState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicState() when $default != null:
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
    TResult Function(_MusicState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicState():
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
    TResult? Function(_MusicState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicState() when $default != null:
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
            List<MusicItem> searchResults,
            List<MusicItem> queue,
            MusicItem? nowPlaying,
            bool isPaused,
            bool isLoading,
            double volume,
            String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MusicState() when $default != null:
        return $default(_that.searchResults, _that.queue, _that.nowPlaying,
            _that.isPaused, _that.isLoading, _that.volume, _that.error);
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
            List<MusicItem> searchResults,
            List<MusicItem> queue,
            MusicItem? nowPlaying,
            bool isPaused,
            bool isLoading,
            double volume,
            String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicState():
        return $default(_that.searchResults, _that.queue, _that.nowPlaying,
            _that.isPaused, _that.isLoading, _that.volume, _that.error);
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
            List<MusicItem> searchResults,
            List<MusicItem> queue,
            MusicItem? nowPlaying,
            bool isPaused,
            bool isLoading,
            double volume,
            String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MusicState() when $default != null:
        return $default(_that.searchResults, _that.queue, _that.nowPlaying,
            _that.isPaused, _that.isLoading, _that.volume, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _MusicState implements MusicState {
  const _MusicState(
      {final List<MusicItem> searchResults = const [],
      final List<MusicItem> queue = const [],
      this.nowPlaying,
      this.isPaused = false,
      this.isLoading = false,
      this.volume = 0.5,
      this.error})
      : _searchResults = searchResults,
        _queue = queue;

  final List<MusicItem> _searchResults;
  @override
  @JsonKey()
  List<MusicItem> get searchResults {
    if (_searchResults is EqualUnmodifiableListView) return _searchResults;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_searchResults);
  }

  final List<MusicItem> _queue;
  @override
  @JsonKey()
  List<MusicItem> get queue {
    if (_queue is EqualUnmodifiableListView) return _queue;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_queue);
  }

  @override
  final MusicItem? nowPlaying;
  @override
  @JsonKey()
  final bool isPaused;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final double volume;
  @override
  final String? error;

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MusicStateCopyWith<_MusicState> get copyWith =>
      __$MusicStateCopyWithImpl<_MusicState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MusicState &&
            const DeepCollectionEquality()
                .equals(other._searchResults, _searchResults) &&
            const DeepCollectionEquality().equals(other._queue, _queue) &&
            (identical(other.nowPlaying, nowPlaying) ||
                other.nowPlaying == nowPlaying) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.volume, volume) || other.volume == volume) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_searchResults),
      const DeepCollectionEquality().hash(_queue),
      nowPlaying,
      isPaused,
      isLoading,
      volume,
      error);

  @override
  String toString() {
    return 'MusicState(searchResults: $searchResults, queue: $queue, nowPlaying: $nowPlaying, isPaused: $isPaused, isLoading: $isLoading, volume: $volume, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$MusicStateCopyWith<$Res>
    implements $MusicStateCopyWith<$Res> {
  factory _$MusicStateCopyWith(
          _MusicState value, $Res Function(_MusicState) _then) =
      __$MusicStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<MusicItem> searchResults,
      List<MusicItem> queue,
      MusicItem? nowPlaying,
      bool isPaused,
      bool isLoading,
      double volume,
      String? error});

  @override
  $MusicItemCopyWith<$Res>? get nowPlaying;
}

/// @nodoc
class __$MusicStateCopyWithImpl<$Res> implements _$MusicStateCopyWith<$Res> {
  __$MusicStateCopyWithImpl(this._self, this._then);

  final _MusicState _self;
  final $Res Function(_MusicState) _then;

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? searchResults = null,
    Object? queue = null,
    Object? nowPlaying = freezed,
    Object? isPaused = null,
    Object? isLoading = null,
    Object? volume = null,
    Object? error = freezed,
  }) {
    return _then(_MusicState(
      searchResults: null == searchResults
          ? _self._searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<MusicItem>,
      queue: null == queue
          ? _self._queue
          : queue // ignore: cast_nullable_to_non_nullable
              as List<MusicItem>,
      nowPlaying: freezed == nowPlaying
          ? _self.nowPlaying
          : nowPlaying // ignore: cast_nullable_to_non_nullable
              as MusicItem?,
      isPaused: null == isPaused
          ? _self.isPaused
          : isPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      volume: null == volume
          ? _self.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of MusicState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MusicItemCopyWith<$Res>? get nowPlaying {
    if (_self.nowPlaying == null) {
      return null;
    }

    return $MusicItemCopyWith<$Res>(_self.nowPlaying!, (value) {
      return _then(_self.copyWith(nowPlaying: value));
    });
  }
}

// dart format on
