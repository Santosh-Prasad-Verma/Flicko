// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dm_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DMConversation {
  String get id; // The other user's ID
  UserModel get participant;
  String get lastMessage;
  DateTime get lastMessageAt;
  int get unreadCount;
  bool get isPinned;
  bool get isMuted;
  bool get isTyping;

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DMConversationCopyWith<DMConversation> get copyWith =>
      _$DMConversationCopyWithImpl<DMConversation>(
          this as DMConversation, _$identity);

  /// Serializes this DMConversation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DMConversation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.participant, participant) ||
                other.participant == participant) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isTyping, isTyping) ||
                other.isTyping == isTyping));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, participant, lastMessage,
      lastMessageAt, unreadCount, isPinned, isMuted, isTyping);

  @override
  String toString() {
    return 'DMConversation(id: $id, participant: $participant, lastMessage: $lastMessage, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, isPinned: $isPinned, isMuted: $isMuted, isTyping: $isTyping)';
  }
}

/// @nodoc
abstract mixin class $DMConversationCopyWith<$Res> {
  factory $DMConversationCopyWith(
          DMConversation value, $Res Function(DMConversation) _then) =
      _$DMConversationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      UserModel participant,
      String lastMessage,
      DateTime lastMessageAt,
      int unreadCount,
      bool isPinned,
      bool isMuted,
      bool isTyping});

  $UserModelCopyWith<$Res> get participant;
}

/// @nodoc
class _$DMConversationCopyWithImpl<$Res>
    implements $DMConversationCopyWith<$Res> {
  _$DMConversationCopyWithImpl(this._self, this._then);

  final DMConversation _self;
  final $Res Function(DMConversation) _then;

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? participant = null,
    Object? lastMessage = null,
    Object? lastMessageAt = null,
    Object? unreadCount = null,
    Object? isPinned = null,
    Object? isMuted = null,
    Object? isTyping = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      participant: null == participant
          ? _self.participant
          : participant // ignore: cast_nullable_to_non_nullable
              as UserModel,
      lastMessage: null == lastMessage
          ? _self.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String,
      lastMessageAt: null == lastMessageAt
          ? _self.lastMessageAt
          : lastMessageAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      unreadCount: null == unreadCount
          ? _self.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPinned: null == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isTyping: null == isTyping
          ? _self.isTyping
          : isTyping // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res> get participant {
    return $UserModelCopyWith<$Res>(_self.participant, (value) {
      return _then(_self.copyWith(participant: value));
    });
  }
}

/// Adds pattern-matching-related methods to [DMConversation].
extension DMConversationPatterns on DMConversation {
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
    TResult Function(_DMConversation value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMConversation() when $default != null:
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
    TResult Function(_DMConversation value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMConversation():
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
    TResult? Function(_DMConversation value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMConversation() when $default != null:
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
            UserModel participant,
            String lastMessage,
            DateTime lastMessageAt,
            int unreadCount,
            bool isPinned,
            bool isMuted,
            bool isTyping)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMConversation() when $default != null:
        return $default(
            _that.id,
            _that.participant,
            _that.lastMessage,
            _that.lastMessageAt,
            _that.unreadCount,
            _that.isPinned,
            _that.isMuted,
            _that.isTyping);
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
            UserModel participant,
            String lastMessage,
            DateTime lastMessageAt,
            int unreadCount,
            bool isPinned,
            bool isMuted,
            bool isTyping)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMConversation():
        return $default(
            _that.id,
            _that.participant,
            _that.lastMessage,
            _that.lastMessageAt,
            _that.unreadCount,
            _that.isPinned,
            _that.isMuted,
            _that.isTyping);
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
            UserModel participant,
            String lastMessage,
            DateTime lastMessageAt,
            int unreadCount,
            bool isPinned,
            bool isMuted,
            bool isTyping)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMConversation() when $default != null:
        return $default(
            _that.id,
            _that.participant,
            _that.lastMessage,
            _that.lastMessageAt,
            _that.unreadCount,
            _that.isPinned,
            _that.isMuted,
            _that.isTyping);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DMConversation implements DMConversation {
  const _DMConversation(
      {required this.id,
      required this.participant,
      required this.lastMessage,
      required this.lastMessageAt,
      this.unreadCount = 0,
      this.isPinned = false,
      this.isMuted = false,
      this.isTyping = false});
  factory _DMConversation.fromJson(Map<String, dynamic> json) =>
      _$DMConversationFromJson(json);

  @override
  final String id;
// The other user's ID
  @override
  final UserModel participant;
  @override
  final String lastMessage;
  @override
  final DateTime lastMessageAt;
  @override
  @JsonKey()
  final int unreadCount;
  @override
  @JsonKey()
  final bool isPinned;
  @override
  @JsonKey()
  final bool isMuted;
  @override
  @JsonKey()
  final bool isTyping;

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DMConversationCopyWith<_DMConversation> get copyWith =>
      __$DMConversationCopyWithImpl<_DMConversation>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DMConversationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DMConversation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.participant, participant) ||
                other.participant == participant) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isTyping, isTyping) ||
                other.isTyping == isTyping));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, participant, lastMessage,
      lastMessageAt, unreadCount, isPinned, isMuted, isTyping);

  @override
  String toString() {
    return 'DMConversation(id: $id, participant: $participant, lastMessage: $lastMessage, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, isPinned: $isPinned, isMuted: $isMuted, isTyping: $isTyping)';
  }
}

/// @nodoc
abstract mixin class _$DMConversationCopyWith<$Res>
    implements $DMConversationCopyWith<$Res> {
  factory _$DMConversationCopyWith(
          _DMConversation value, $Res Function(_DMConversation) _then) =
      __$DMConversationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      UserModel participant,
      String lastMessage,
      DateTime lastMessageAt,
      int unreadCount,
      bool isPinned,
      bool isMuted,
      bool isTyping});

  @override
  $UserModelCopyWith<$Res> get participant;
}

/// @nodoc
class __$DMConversationCopyWithImpl<$Res>
    implements _$DMConversationCopyWith<$Res> {
  __$DMConversationCopyWithImpl(this._self, this._then);

  final _DMConversation _self;
  final $Res Function(_DMConversation) _then;

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? participant = null,
    Object? lastMessage = null,
    Object? lastMessageAt = null,
    Object? unreadCount = null,
    Object? isPinned = null,
    Object? isMuted = null,
    Object? isTyping = null,
  }) {
    return _then(_DMConversation(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      participant: null == participant
          ? _self.participant
          : participant // ignore: cast_nullable_to_non_nullable
              as UserModel,
      lastMessage: null == lastMessage
          ? _self.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String,
      lastMessageAt: null == lastMessageAt
          ? _self.lastMessageAt
          : lastMessageAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      unreadCount: null == unreadCount
          ? _self.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPinned: null == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _self.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isTyping: null == isTyping
          ? _self.isTyping
          : isTyping // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of DMConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res> get participant {
    return $UserModelCopyWith<$Res>(_self.participant, (value) {
      return _then(_self.copyWith(participant: value));
    });
  }
}

/// @nodoc
mixin _$DMAttachment {
  String get url;
  String get type;
  String? get name;
  int? get size;
  int? get width;
  int? get height;

  /// Create a copy of DMAttachment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DMAttachmentCopyWith<DMAttachment> get copyWith =>
      _$DMAttachmentCopyWithImpl<DMAttachment>(
          this as DMAttachment, _$identity);

  /// Serializes this DMAttachment to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DMAttachment &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, url, type, name, size, width, height);

  @override
  String toString() {
    return 'DMAttachment(url: $url, type: $type, name: $name, size: $size, width: $width, height: $height)';
  }
}

/// @nodoc
abstract mixin class $DMAttachmentCopyWith<$Res> {
  factory $DMAttachmentCopyWith(
          DMAttachment value, $Res Function(DMAttachment) _then) =
      _$DMAttachmentCopyWithImpl;
  @useResult
  $Res call(
      {String url,
      String type,
      String? name,
      int? size,
      int? width,
      int? height});
}

/// @nodoc
class _$DMAttachmentCopyWithImpl<$Res> implements $DMAttachmentCopyWith<$Res> {
  _$DMAttachmentCopyWithImpl(this._self, this._then);

  final DMAttachment _self;
  final $Res Function(DMAttachment) _then;

  /// Create a copy of DMAttachment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? type = null,
    Object? name = freezed,
    Object? size = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_self.copyWith(
      url: null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
      width: freezed == width
          ? _self.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _self.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [DMAttachment].
extension DMAttachmentPatterns on DMAttachment {
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
    TResult Function(_DMAttachment value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMAttachment() when $default != null:
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
    TResult Function(_DMAttachment value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMAttachment():
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
    TResult? Function(_DMAttachment value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMAttachment() when $default != null:
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
    TResult Function(String url, String type, String? name, int? size,
            int? width, int? height)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMAttachment() when $default != null:
        return $default(_that.url, _that.type, _that.name, _that.size,
            _that.width, _that.height);
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
    TResult Function(String url, String type, String? name, int? size,
            int? width, int? height)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMAttachment():
        return $default(_that.url, _that.type, _that.name, _that.size,
            _that.width, _that.height);
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
    TResult? Function(String url, String type, String? name, int? size,
            int? width, int? height)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMAttachment() when $default != null:
        return $default(_that.url, _that.type, _that.name, _that.size,
            _that.width, _that.height);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DMAttachment implements DMAttachment {
  const _DMAttachment(
      {required this.url,
      required this.type,
      this.name,
      this.size,
      this.width,
      this.height});
  factory _DMAttachment.fromJson(Map<String, dynamic> json) =>
      _$DMAttachmentFromJson(json);

  @override
  final String url;
  @override
  final String type;
  @override
  final String? name;
  @override
  final int? size;
  @override
  final int? width;
  @override
  final int? height;

  /// Create a copy of DMAttachment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DMAttachmentCopyWith<_DMAttachment> get copyWith =>
      __$DMAttachmentCopyWithImpl<_DMAttachment>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DMAttachmentToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DMAttachment &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, url, type, name, size, width, height);

  @override
  String toString() {
    return 'DMAttachment(url: $url, type: $type, name: $name, size: $size, width: $width, height: $height)';
  }
}

/// @nodoc
abstract mixin class _$DMAttachmentCopyWith<$Res>
    implements $DMAttachmentCopyWith<$Res> {
  factory _$DMAttachmentCopyWith(
          _DMAttachment value, $Res Function(_DMAttachment) _then) =
      __$DMAttachmentCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String url,
      String type,
      String? name,
      int? size,
      int? width,
      int? height});
}

/// @nodoc
class __$DMAttachmentCopyWithImpl<$Res>
    implements _$DMAttachmentCopyWith<$Res> {
  __$DMAttachmentCopyWithImpl(this._self, this._then);

  final _DMAttachment _self;
  final $Res Function(_DMAttachment) _then;

  /// Create a copy of DMAttachment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? url = null,
    Object? type = null,
    Object? name = freezed,
    Object? size = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_DMAttachment(
      url: null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
      width: freezed == width
          ? _self.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _self.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
mixin _$DMMessage {
  String get id;
  @JsonKey(name: 'sender_id')
  String get senderId;
  @JsonKey(name: 'recipient_id')
  String get recipientId;
  String get content;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  UserModel? get sender;
  UserModel? get recipient;
  List<DMAttachment>? get attachments;

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DMMessageCopyWith<DMMessage> get copyWith =>
      _$DMMessageCopyWithImpl<DMMessage>(this as DMMessage, _$identity);

  /// Serializes this DMMessage to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DMMessage &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.recipient, recipient) ||
                other.recipient == recipient) &&
            const DeepCollectionEquality()
                .equals(other.attachments, attachments));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      senderId,
      recipientId,
      content,
      createdAt,
      sender,
      recipient,
      const DeepCollectionEquality().hash(attachments));

  @override
  String toString() {
    return 'DMMessage(id: $id, senderId: $senderId, recipientId: $recipientId, content: $content, createdAt: $createdAt, sender: $sender, recipient: $recipient, attachments: $attachments)';
  }
}

/// @nodoc
abstract mixin class $DMMessageCopyWith<$Res> {
  factory $DMMessageCopyWith(DMMessage value, $Res Function(DMMessage) _then) =
      _$DMMessageCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'sender_id') String senderId,
      @JsonKey(name: 'recipient_id') String recipientId,
      String content,
      @JsonKey(name: 'created_at') DateTime createdAt,
      UserModel? sender,
      UserModel? recipient,
      List<DMAttachment>? attachments});

  $UserModelCopyWith<$Res>? get sender;
  $UserModelCopyWith<$Res>? get recipient;
}

/// @nodoc
class _$DMMessageCopyWithImpl<$Res> implements $DMMessageCopyWith<$Res> {
  _$DMMessageCopyWithImpl(this._self, this._then);

  final DMMessage _self;
  final $Res Function(DMMessage) _then;

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? recipientId = null,
    Object? content = null,
    Object? createdAt = null,
    Object? sender = freezed,
    Object? recipient = freezed,
    Object? attachments = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _self.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _self.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sender: freezed == sender
          ? _self.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      recipient: freezed == recipient
          ? _self.recipient
          : recipient // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      attachments: freezed == attachments
          ? _self.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<DMAttachment>?,
    ));
  }

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get sender {
    if (_self.sender == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.sender!, (value) {
      return _then(_self.copyWith(sender: value));
    });
  }

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get recipient {
    if (_self.recipient == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.recipient!, (value) {
      return _then(_self.copyWith(recipient: value));
    });
  }
}

/// Adds pattern-matching-related methods to [DMMessage].
extension DMMessagePatterns on DMMessage {
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
    TResult Function(_DMMessage value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMMessage() when $default != null:
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
    TResult Function(_DMMessage value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMMessage():
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
    TResult? Function(_DMMessage value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMMessage() when $default != null:
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
            @JsonKey(name: 'sender_id') String senderId,
            @JsonKey(name: 'recipient_id') String recipientId,
            String content,
            @JsonKey(name: 'created_at') DateTime createdAt,
            UserModel? sender,
            UserModel? recipient,
            List<DMAttachment>? attachments)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DMMessage() when $default != null:
        return $default(
            _that.id,
            _that.senderId,
            _that.recipientId,
            _that.content,
            _that.createdAt,
            _that.sender,
            _that.recipient,
            _that.attachments);
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
            @JsonKey(name: 'sender_id') String senderId,
            @JsonKey(name: 'recipient_id') String recipientId,
            String content,
            @JsonKey(name: 'created_at') DateTime createdAt,
            UserModel? sender,
            UserModel? recipient,
            List<DMAttachment>? attachments)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMMessage():
        return $default(
            _that.id,
            _that.senderId,
            _that.recipientId,
            _that.content,
            _that.createdAt,
            _that.sender,
            _that.recipient,
            _that.attachments);
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
            @JsonKey(name: 'sender_id') String senderId,
            @JsonKey(name: 'recipient_id') String recipientId,
            String content,
            @JsonKey(name: 'created_at') DateTime createdAt,
            UserModel? sender,
            UserModel? recipient,
            List<DMAttachment>? attachments)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DMMessage() when $default != null:
        return $default(
            _that.id,
            _that.senderId,
            _that.recipientId,
            _that.content,
            _that.createdAt,
            _that.sender,
            _that.recipient,
            _that.attachments);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DMMessage implements DMMessage {
  const _DMMessage(
      {required this.id,
      @JsonKey(name: 'sender_id') required this.senderId,
      @JsonKey(name: 'recipient_id') required this.recipientId,
      required this.content,
      @JsonKey(name: 'created_at') required this.createdAt,
      this.sender,
      this.recipient,
      final List<DMAttachment>? attachments})
      : _attachments = attachments;
  factory _DMMessage.fromJson(Map<String, dynamic> json) =>
      _$DMMessageFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'sender_id')
  final String senderId;
  @override
  @JsonKey(name: 'recipient_id')
  final String recipientId;
  @override
  final String content;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  final UserModel? sender;
  @override
  final UserModel? recipient;
  final List<DMAttachment>? _attachments;
  @override
  List<DMAttachment>? get attachments {
    final value = _attachments;
    if (value == null) return null;
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DMMessageCopyWith<_DMMessage> get copyWith =>
      __$DMMessageCopyWithImpl<_DMMessage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DMMessageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DMMessage &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.recipient, recipient) ||
                other.recipient == recipient) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      senderId,
      recipientId,
      content,
      createdAt,
      sender,
      recipient,
      const DeepCollectionEquality().hash(_attachments));

  @override
  String toString() {
    return 'DMMessage(id: $id, senderId: $senderId, recipientId: $recipientId, content: $content, createdAt: $createdAt, sender: $sender, recipient: $recipient, attachments: $attachments)';
  }
}

/// @nodoc
abstract mixin class _$DMMessageCopyWith<$Res>
    implements $DMMessageCopyWith<$Res> {
  factory _$DMMessageCopyWith(
          _DMMessage value, $Res Function(_DMMessage) _then) =
      __$DMMessageCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'sender_id') String senderId,
      @JsonKey(name: 'recipient_id') String recipientId,
      String content,
      @JsonKey(name: 'created_at') DateTime createdAt,
      UserModel? sender,
      UserModel? recipient,
      List<DMAttachment>? attachments});

  @override
  $UserModelCopyWith<$Res>? get sender;
  @override
  $UserModelCopyWith<$Res>? get recipient;
}

/// @nodoc
class __$DMMessageCopyWithImpl<$Res> implements _$DMMessageCopyWith<$Res> {
  __$DMMessageCopyWithImpl(this._self, this._then);

  final _DMMessage _self;
  final $Res Function(_DMMessage) _then;

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? recipientId = null,
    Object? content = null,
    Object? createdAt = null,
    Object? sender = freezed,
    Object? recipient = freezed,
    Object? attachments = freezed,
  }) {
    return _then(_DMMessage(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _self.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _self.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sender: freezed == sender
          ? _self.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      recipient: freezed == recipient
          ? _self.recipient
          : recipient // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      attachments: freezed == attachments
          ? _self._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<DMAttachment>?,
    ));
  }

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get sender {
    if (_self.sender == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.sender!, (value) {
      return _then(_self.copyWith(sender: value));
    });
  }

  /// Create a copy of DMMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get recipient {
    if (_self.recipient == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.recipient!, (value) {
      return _then(_self.copyWith(recipient: value));
    });
  }
}

// dart format on
