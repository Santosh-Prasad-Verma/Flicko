// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatState {
  List<FlickoMessage> get messages;
  Set<String> get typingUsers;
  bool get isLoading;
  bool get isFetchingMore;
  bool get isSending;
  bool get hasMore;
  String? get errorMessage;
  String? get activeThreadId;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatStateCopyWith<ChatState> get copyWith =>
      _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatState &&
            const DeepCollectionEquality().equals(other.messages, messages) &&
            const DeepCollectionEquality()
                .equals(other.typingUsers, typingUsers) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isFetchingMore, isFetchingMore) ||
                other.isFetchingMore == isFetchingMore) &&
            (identical(other.isSending, isSending) ||
                other.isSending == isSending) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.activeThreadId, activeThreadId) ||
                other.activeThreadId == activeThreadId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(messages),
      const DeepCollectionEquality().hash(typingUsers),
      isLoading,
      isFetchingMore,
      isSending,
      hasMore,
      errorMessage,
      activeThreadId);

  @override
  String toString() {
    return 'ChatState(messages: $messages, typingUsers: $typingUsers, isLoading: $isLoading, isFetchingMore: $isFetchingMore, isSending: $isSending, hasMore: $hasMore, errorMessage: $errorMessage, activeThreadId: $activeThreadId)';
  }
}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) =
      _$ChatStateCopyWithImpl;
  @useResult
  $Res call(
      {List<FlickoMessage> messages,
      Set<String> typingUsers,
      bool isLoading,
      bool isFetchingMore,
      bool isSending,
      bool hasMore,
      String? errorMessage,
      String? activeThreadId});
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res> implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? typingUsers = null,
    Object? isLoading = null,
    Object? isFetchingMore = null,
    Object? isSending = null,
    Object? hasMore = null,
    Object? errorMessage = freezed,
    Object? activeThreadId = freezed,
  }) {
    return _then(_self.copyWith(
      messages: null == messages
          ? _self.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<FlickoMessage>,
      typingUsers: null == typingUsers
          ? _self.typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isFetchingMore: null == isFetchingMore
          ? _self.isFetchingMore
          : isFetchingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isSending: null == isSending
          ? _self.isSending
          : isSending // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMore: null == hasMore
          ? _self.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      activeThreadId: freezed == activeThreadId
          ? _self.activeThreadId
          : activeThreadId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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
    TResult Function(_ChatState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
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
    TResult Function(_ChatState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState():
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
    TResult? Function(_ChatState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
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
            List<FlickoMessage> messages,
            Set<String> typingUsers,
            bool isLoading,
            bool isFetchingMore,
            bool isSending,
            bool hasMore,
            String? errorMessage,
            String? activeThreadId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
        return $default(
            _that.messages,
            _that.typingUsers,
            _that.isLoading,
            _that.isFetchingMore,
            _that.isSending,
            _that.hasMore,
            _that.errorMessage,
            _that.activeThreadId);
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
            List<FlickoMessage> messages,
            Set<String> typingUsers,
            bool isLoading,
            bool isFetchingMore,
            bool isSending,
            bool hasMore,
            String? errorMessage,
            String? activeThreadId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState():
        return $default(
            _that.messages,
            _that.typingUsers,
            _that.isLoading,
            _that.isFetchingMore,
            _that.isSending,
            _that.hasMore,
            _that.errorMessage,
            _that.activeThreadId);
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
            List<FlickoMessage> messages,
            Set<String> typingUsers,
            bool isLoading,
            bool isFetchingMore,
            bool isSending,
            bool hasMore,
            String? errorMessage,
            String? activeThreadId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
        return $default(
            _that.messages,
            _that.typingUsers,
            _that.isLoading,
            _that.isFetchingMore,
            _that.isSending,
            _that.hasMore,
            _that.errorMessage,
            _that.activeThreadId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChatState implements ChatState {
  const _ChatState(
      {final List<FlickoMessage> messages = const [],
      final Set<String> typingUsers = const <String>{},
      this.isLoading = false,
      this.isFetchingMore = false,
      this.isSending = false,
      this.hasMore = true,
      this.errorMessage,
      this.activeThreadId})
      : _messages = messages,
        _typingUsers = typingUsers;

  final List<FlickoMessage> _messages;
  @override
  @JsonKey()
  List<FlickoMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  final Set<String> _typingUsers;
  @override
  @JsonKey()
  Set<String> get typingUsers {
    if (_typingUsers is EqualUnmodifiableSetView) return _typingUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_typingUsers);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isFetchingMore;
  @override
  @JsonKey()
  final bool isSending;
  @override
  @JsonKey()
  final bool hasMore;
  @override
  final String? errorMessage;
  @override
  final String? activeThreadId;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatStateCopyWith<_ChatState> get copyWith =>
      __$ChatStateCopyWithImpl<_ChatState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatState &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            const DeepCollectionEquality()
                .equals(other._typingUsers, _typingUsers) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isFetchingMore, isFetchingMore) ||
                other.isFetchingMore == isFetchingMore) &&
            (identical(other.isSending, isSending) ||
                other.isSending == isSending) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.activeThreadId, activeThreadId) ||
                other.activeThreadId == activeThreadId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_messages),
      const DeepCollectionEquality().hash(_typingUsers),
      isLoading,
      isFetchingMore,
      isSending,
      hasMore,
      errorMessage,
      activeThreadId);

  @override
  String toString() {
    return 'ChatState(messages: $messages, typingUsers: $typingUsers, isLoading: $isLoading, isFetchingMore: $isFetchingMore, isSending: $isSending, hasMore: $hasMore, errorMessage: $errorMessage, activeThreadId: $activeThreadId)';
  }
}

/// @nodoc
abstract mixin class _$ChatStateCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$ChatStateCopyWith(
          _ChatState value, $Res Function(_ChatState) _then) =
      __$ChatStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<FlickoMessage> messages,
      Set<String> typingUsers,
      bool isLoading,
      bool isFetchingMore,
      bool isSending,
      bool hasMore,
      String? errorMessage,
      String? activeThreadId});
}

/// @nodoc
class __$ChatStateCopyWithImpl<$Res> implements _$ChatStateCopyWith<$Res> {
  __$ChatStateCopyWithImpl(this._self, this._then);

  final _ChatState _self;
  final $Res Function(_ChatState) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? messages = null,
    Object? typingUsers = null,
    Object? isLoading = null,
    Object? isFetchingMore = null,
    Object? isSending = null,
    Object? hasMore = null,
    Object? errorMessage = freezed,
    Object? activeThreadId = freezed,
  }) {
    return _then(_ChatState(
      messages: null == messages
          ? _self._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<FlickoMessage>,
      typingUsers: null == typingUsers
          ? _self._typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isFetchingMore: null == isFetchingMore
          ? _self.isFetchingMore
          : isFetchingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isSending: null == isSending
          ? _self.isSending
          : isSending // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMore: null == hasMore
          ? _self.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      activeThreadId: freezed == activeThreadId
          ? _self.activeThreadId
          : activeThreadId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
