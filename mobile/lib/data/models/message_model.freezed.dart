// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageModel {
  String get id;
  @JsonKey(name: 'channel_id')
  String get channelId;
  @JsonKey(name: 'author_id')
  String get authorId;
  String get content;
  String get type;
  @JsonKey(name: 'reply_to_id')
  String? get replyToId;
  @JsonKey(name: 'thread_id')
  String? get threadId;
  List<AttachmentModel> get attachments;
  List<ReactionModel> get reactions;
  bool get pinned;
  bool get edited;
  @JsonKey(name: 'edited_at')
  DateTime? get editedAt;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt; // Joined data
  UserModel? get author;
  MessageModel? get replyTo;

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageModelCopyWith<MessageModel> get copyWith =>
      _$MessageModelCopyWithImpl<MessageModel>(
          this as MessageModel, _$identity);

  /// Serializes this MessageModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessageModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.replyToId, replyToId) ||
                other.replyToId == replyToId) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            const DeepCollectionEquality()
                .equals(other.attachments, attachments) &&
            const DeepCollectionEquality().equals(other.reactions, reactions) &&
            (identical(other.pinned, pinned) || other.pinned == pinned) &&
            (identical(other.edited, edited) || other.edited == edited) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.replyTo, replyTo) || other.replyTo == replyTo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      channelId,
      authorId,
      content,
      type,
      replyToId,
      threadId,
      const DeepCollectionEquality().hash(attachments),
      const DeepCollectionEquality().hash(reactions),
      pinned,
      edited,
      editedAt,
      createdAt,
      updatedAt,
      author,
      replyTo);

  @override
  String toString() {
    return 'MessageModel(id: $id, channelId: $channelId, authorId: $authorId, content: $content, type: $type, replyToId: $replyToId, threadId: $threadId, attachments: $attachments, reactions: $reactions, pinned: $pinned, edited: $edited, editedAt: $editedAt, createdAt: $createdAt, updatedAt: $updatedAt, author: $author, replyTo: $replyTo)';
  }
}

/// @nodoc
abstract mixin class $MessageModelCopyWith<$Res> {
  factory $MessageModelCopyWith(
          MessageModel value, $Res Function(MessageModel) _then) =
      _$MessageModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'channel_id') String channelId,
      @JsonKey(name: 'author_id') String authorId,
      String content,
      String type,
      @JsonKey(name: 'reply_to_id') String? replyToId,
      @JsonKey(name: 'thread_id') String? threadId,
      List<AttachmentModel> attachments,
      List<ReactionModel> reactions,
      bool pinned,
      bool edited,
      @JsonKey(name: 'edited_at') DateTime? editedAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      UserModel? author,
      MessageModel? replyTo});

  $UserModelCopyWith<$Res>? get author;
  $MessageModelCopyWith<$Res>? get replyTo;
}

/// @nodoc
class _$MessageModelCopyWithImpl<$Res> implements $MessageModelCopyWith<$Res> {
  _$MessageModelCopyWithImpl(this._self, this._then);

  final MessageModel _self;
  final $Res Function(MessageModel) _then;

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? authorId = null,
    Object? content = null,
    Object? type = null,
    Object? replyToId = freezed,
    Object? threadId = freezed,
    Object? attachments = null,
    Object? reactions = null,
    Object? pinned = null,
    Object? edited = null,
    Object? editedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? author = freezed,
    Object? replyTo = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _self.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _self.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      replyToId: freezed == replyToId
          ? _self.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      threadId: freezed == threadId
          ? _self.threadId
          : threadId // ignore: cast_nullable_to_non_nullable
              as String?,
      attachments: null == attachments
          ? _self.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<AttachmentModel>,
      reactions: null == reactions
          ? _self.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as List<ReactionModel>,
      pinned: null == pinned
          ? _self.pinned
          : pinned // ignore: cast_nullable_to_non_nullable
              as bool,
      edited: null == edited
          ? _self.edited
          : edited // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _self.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      author: freezed == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      replyTo: freezed == replyTo
          ? _self.replyTo
          : replyTo // ignore: cast_nullable_to_non_nullable
              as MessageModel?,
    ));
  }

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get author {
    if (_self.author == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.author!, (value) {
      return _then(_self.copyWith(author: value));
    });
  }

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageModelCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
      return null;
    }

    return $MessageModelCopyWith<$Res>(_self.replyTo!, (value) {
      return _then(_self.copyWith(replyTo: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MessageModel].
extension MessageModelPatterns on MessageModel {
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
    TResult Function(_MessageModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MessageModel() when $default != null:
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
    TResult Function(_MessageModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessageModel():
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
    TResult? Function(_MessageModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessageModel() when $default != null:
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
            @JsonKey(name: 'channel_id') String channelId,
            @JsonKey(name: 'author_id') String authorId,
            String content,
            String type,
            @JsonKey(name: 'reply_to_id') String? replyToId,
            @JsonKey(name: 'thread_id') String? threadId,
            List<AttachmentModel> attachments,
            List<ReactionModel> reactions,
            bool pinned,
            bool edited,
            @JsonKey(name: 'edited_at') DateTime? editedAt,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            UserModel? author,
            MessageModel? replyTo)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MessageModel() when $default != null:
        return $default(
            _that.id,
            _that.channelId,
            _that.authorId,
            _that.content,
            _that.type,
            _that.replyToId,
            _that.threadId,
            _that.attachments,
            _that.reactions,
            _that.pinned,
            _that.edited,
            _that.editedAt,
            _that.createdAt,
            _that.updatedAt,
            _that.author,
            _that.replyTo);
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
            @JsonKey(name: 'channel_id') String channelId,
            @JsonKey(name: 'author_id') String authorId,
            String content,
            String type,
            @JsonKey(name: 'reply_to_id') String? replyToId,
            @JsonKey(name: 'thread_id') String? threadId,
            List<AttachmentModel> attachments,
            List<ReactionModel> reactions,
            bool pinned,
            bool edited,
            @JsonKey(name: 'edited_at') DateTime? editedAt,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            UserModel? author,
            MessageModel? replyTo)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessageModel():
        return $default(
            _that.id,
            _that.channelId,
            _that.authorId,
            _that.content,
            _that.type,
            _that.replyToId,
            _that.threadId,
            _that.attachments,
            _that.reactions,
            _that.pinned,
            _that.edited,
            _that.editedAt,
            _that.createdAt,
            _that.updatedAt,
            _that.author,
            _that.replyTo);
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
            @JsonKey(name: 'channel_id') String channelId,
            @JsonKey(name: 'author_id') String authorId,
            String content,
            String type,
            @JsonKey(name: 'reply_to_id') String? replyToId,
            @JsonKey(name: 'thread_id') String? threadId,
            List<AttachmentModel> attachments,
            List<ReactionModel> reactions,
            bool pinned,
            bool edited,
            @JsonKey(name: 'edited_at') DateTime? editedAt,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            UserModel? author,
            MessageModel? replyTo)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MessageModel() when $default != null:
        return $default(
            _that.id,
            _that.channelId,
            _that.authorId,
            _that.content,
            _that.type,
            _that.replyToId,
            _that.threadId,
            _that.attachments,
            _that.reactions,
            _that.pinned,
            _that.edited,
            _that.editedAt,
            _that.createdAt,
            _that.updatedAt,
            _that.author,
            _that.replyTo);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MessageModel implements MessageModel {
  const _MessageModel(
      {required this.id,
      @JsonKey(name: 'channel_id') required this.channelId,
      @JsonKey(name: 'author_id') required this.authorId,
      required this.content,
      this.type = 'default',
      @JsonKey(name: 'reply_to_id') this.replyToId,
      @JsonKey(name: 'thread_id') this.threadId,
      final List<AttachmentModel> attachments = const [],
      final List<ReactionModel> reactions = const [],
      this.pinned = false,
      this.edited = false,
      @JsonKey(name: 'edited_at') this.editedAt,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt,
      this.author,
      this.replyTo})
      : _attachments = attachments,
        _reactions = reactions;
  factory _MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'channel_id')
  final String channelId;
  @override
  @JsonKey(name: 'author_id')
  final String authorId;
  @override
  final String content;
  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  @override
  @JsonKey(name: 'thread_id')
  final String? threadId;
  final List<AttachmentModel> _attachments;
  @override
  @JsonKey()
  List<AttachmentModel> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  final List<ReactionModel> _reactions;
  @override
  @JsonKey()
  List<ReactionModel> get reactions {
    if (_reactions is EqualUnmodifiableListView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reactions);
  }

  @override
  @JsonKey()
  final bool pinned;
  @override
  @JsonKey()
  final bool edited;
  @override
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
// Joined data
  @override
  final UserModel? author;
  @override
  final MessageModel? replyTo;

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MessageModelCopyWith<_MessageModel> get copyWith =>
      __$MessageModelCopyWithImpl<_MessageModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessageModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MessageModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.replyToId, replyToId) ||
                other.replyToId == replyToId) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.pinned, pinned) || other.pinned == pinned) &&
            (identical(other.edited, edited) || other.edited == edited) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.replyTo, replyTo) || other.replyTo == replyTo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      channelId,
      authorId,
      content,
      type,
      replyToId,
      threadId,
      const DeepCollectionEquality().hash(_attachments),
      const DeepCollectionEquality().hash(_reactions),
      pinned,
      edited,
      editedAt,
      createdAt,
      updatedAt,
      author,
      replyTo);

  @override
  String toString() {
    return 'MessageModel(id: $id, channelId: $channelId, authorId: $authorId, content: $content, type: $type, replyToId: $replyToId, threadId: $threadId, attachments: $attachments, reactions: $reactions, pinned: $pinned, edited: $edited, editedAt: $editedAt, createdAt: $createdAt, updatedAt: $updatedAt, author: $author, replyTo: $replyTo)';
  }
}

/// @nodoc
abstract mixin class _$MessageModelCopyWith<$Res>
    implements $MessageModelCopyWith<$Res> {
  factory _$MessageModelCopyWith(
          _MessageModel value, $Res Function(_MessageModel) _then) =
      __$MessageModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'channel_id') String channelId,
      @JsonKey(name: 'author_id') String authorId,
      String content,
      String type,
      @JsonKey(name: 'reply_to_id') String? replyToId,
      @JsonKey(name: 'thread_id') String? threadId,
      List<AttachmentModel> attachments,
      List<ReactionModel> reactions,
      bool pinned,
      bool edited,
      @JsonKey(name: 'edited_at') DateTime? editedAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      UserModel? author,
      MessageModel? replyTo});

  @override
  $UserModelCopyWith<$Res>? get author;
  @override
  $MessageModelCopyWith<$Res>? get replyTo;
}

/// @nodoc
class __$MessageModelCopyWithImpl<$Res>
    implements _$MessageModelCopyWith<$Res> {
  __$MessageModelCopyWithImpl(this._self, this._then);

  final _MessageModel _self;
  final $Res Function(_MessageModel) _then;

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? authorId = null,
    Object? content = null,
    Object? type = null,
    Object? replyToId = freezed,
    Object? threadId = freezed,
    Object? attachments = null,
    Object? reactions = null,
    Object? pinned = null,
    Object? edited = null,
    Object? editedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? author = freezed,
    Object? replyTo = freezed,
  }) {
    return _then(_MessageModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _self.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _self.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      replyToId: freezed == replyToId
          ? _self.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      threadId: freezed == threadId
          ? _self.threadId
          : threadId // ignore: cast_nullable_to_non_nullable
              as String?,
      attachments: null == attachments
          ? _self._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<AttachmentModel>,
      reactions: null == reactions
          ? _self._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as List<ReactionModel>,
      pinned: null == pinned
          ? _self.pinned
          : pinned // ignore: cast_nullable_to_non_nullable
              as bool,
      edited: null == edited
          ? _self.edited
          : edited // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _self.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      author: freezed == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as UserModel?,
      replyTo: freezed == replyTo
          ? _self.replyTo
          : replyTo // ignore: cast_nullable_to_non_nullable
              as MessageModel?,
    ));
  }

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res>? get author {
    if (_self.author == null) {
      return null;
    }

    return $UserModelCopyWith<$Res>(_self.author!, (value) {
      return _then(_self.copyWith(author: value));
    });
  }

  /// Create a copy of MessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageModelCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
      return null;
    }

    return $MessageModelCopyWith<$Res>(_self.replyTo!, (value) {
      return _then(_self.copyWith(replyTo: value));
    });
  }
}

/// @nodoc
mixin _$AttachmentModel {
  String get id;
  String get filename;
  String get url;
  int get size;
  @JsonKey(name: 'content_type')
  String get contentType;
  int? get width;
  int? get height;

  /// Create a copy of AttachmentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AttachmentModelCopyWith<AttachmentModel> get copyWith =>
      _$AttachmentModelCopyWithImpl<AttachmentModel>(
          this as AttachmentModel, _$identity);

  /// Serializes this AttachmentModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AttachmentModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, filename, url, size, contentType, width, height);

  @override
  String toString() {
    return 'AttachmentModel(id: $id, filename: $filename, url: $url, size: $size, contentType: $contentType, width: $width, height: $height)';
  }
}

/// @nodoc
abstract mixin class $AttachmentModelCopyWith<$Res> {
  factory $AttachmentModelCopyWith(
          AttachmentModel value, $Res Function(AttachmentModel) _then) =
      _$AttachmentModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String filename,
      String url,
      int size,
      @JsonKey(name: 'content_type') String contentType,
      int? width,
      int? height});
}

/// @nodoc
class _$AttachmentModelCopyWithImpl<$Res>
    implements $AttachmentModelCopyWith<$Res> {
  _$AttachmentModelCopyWithImpl(this._self, this._then);

  final AttachmentModel _self;
  final $Res Function(AttachmentModel) _then;

  /// Create a copy of AttachmentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? filename = null,
    Object? url = null,
    Object? size = null,
    Object? contentType = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _self.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
      contentType: null == contentType
          ? _self.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
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

/// Adds pattern-matching-related methods to [AttachmentModel].
extension AttachmentModelPatterns on AttachmentModel {
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
    TResult Function(_AttachmentModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel() when $default != null:
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
    TResult Function(_AttachmentModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel():
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
    TResult? Function(_AttachmentModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel() when $default != null:
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
            String filename,
            String url,
            int size,
            @JsonKey(name: 'content_type') String contentType,
            int? width,
            int? height)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel() when $default != null:
        return $default(_that.id, _that.filename, _that.url, _that.size,
            _that.contentType, _that.width, _that.height);
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
            String filename,
            String url,
            int size,
            @JsonKey(name: 'content_type') String contentType,
            int? width,
            int? height)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel():
        return $default(_that.id, _that.filename, _that.url, _that.size,
            _that.contentType, _that.width, _that.height);
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
            String filename,
            String url,
            int size,
            @JsonKey(name: 'content_type') String contentType,
            int? width,
            int? height)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AttachmentModel() when $default != null:
        return $default(_that.id, _that.filename, _that.url, _that.size,
            _that.contentType, _that.width, _that.height);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AttachmentModel implements AttachmentModel {
  const _AttachmentModel(
      {required this.id,
      required this.filename,
      required this.url,
      required this.size,
      @JsonKey(name: 'content_type') required this.contentType,
      this.width,
      this.height});
  factory _AttachmentModel.fromJson(Map<String, dynamic> json) =>
      _$AttachmentModelFromJson(json);

  @override
  final String id;
  @override
  final String filename;
  @override
  final String url;
  @override
  final int size;
  @override
  @JsonKey(name: 'content_type')
  final String contentType;
  @override
  final int? width;
  @override
  final int? height;

  /// Create a copy of AttachmentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AttachmentModelCopyWith<_AttachmentModel> get copyWith =>
      __$AttachmentModelCopyWithImpl<_AttachmentModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AttachmentModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AttachmentModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, filename, url, size, contentType, width, height);

  @override
  String toString() {
    return 'AttachmentModel(id: $id, filename: $filename, url: $url, size: $size, contentType: $contentType, width: $width, height: $height)';
  }
}

/// @nodoc
abstract mixin class _$AttachmentModelCopyWith<$Res>
    implements $AttachmentModelCopyWith<$Res> {
  factory _$AttachmentModelCopyWith(
          _AttachmentModel value, $Res Function(_AttachmentModel) _then) =
      __$AttachmentModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String filename,
      String url,
      int size,
      @JsonKey(name: 'content_type') String contentType,
      int? width,
      int? height});
}

/// @nodoc
class __$AttachmentModelCopyWithImpl<$Res>
    implements _$AttachmentModelCopyWith<$Res> {
  __$AttachmentModelCopyWithImpl(this._self, this._then);

  final _AttachmentModel _self;
  final $Res Function(_AttachmentModel) _then;

  /// Create a copy of AttachmentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? filename = null,
    Object? url = null,
    Object? size = null,
    Object? contentType = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_AttachmentModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _self.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
      contentType: null == contentType
          ? _self.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
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
mixin _$ReactionModel {
  String get emoji;
  int get count;
  bool get me;
  List<String> get users;

  /// Create a copy of ReactionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReactionModelCopyWith<ReactionModel> get copyWith =>
      _$ReactionModelCopyWithImpl<ReactionModel>(
          this as ReactionModel, _$identity);

  /// Serializes this ReactionModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReactionModel &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.me, me) || other.me == me) &&
            const DeepCollectionEquality().equals(other.users, users));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, emoji, count, me,
      const DeepCollectionEquality().hash(users));

  @override
  String toString() {
    return 'ReactionModel(emoji: $emoji, count: $count, me: $me, users: $users)';
  }
}

/// @nodoc
abstract mixin class $ReactionModelCopyWith<$Res> {
  factory $ReactionModelCopyWith(
          ReactionModel value, $Res Function(ReactionModel) _then) =
      _$ReactionModelCopyWithImpl;
  @useResult
  $Res call({String emoji, int count, bool me, List<String> users});
}

/// @nodoc
class _$ReactionModelCopyWithImpl<$Res>
    implements $ReactionModelCopyWith<$Res> {
  _$ReactionModelCopyWithImpl(this._self, this._then);

  final ReactionModel _self;
  final $Res Function(ReactionModel) _then;

  /// Create a copy of ReactionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emoji = null,
    Object? count = null,
    Object? me = null,
    Object? users = null,
  }) {
    return _then(_self.copyWith(
      emoji: null == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String,
      count: null == count
          ? _self.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      me: null == me
          ? _self.me
          : me // ignore: cast_nullable_to_non_nullable
              as bool,
      users: null == users
          ? _self.users
          : users // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ReactionModel].
extension ReactionModelPatterns on ReactionModel {
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
    TResult Function(_ReactionModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReactionModel() when $default != null:
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
    TResult Function(_ReactionModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReactionModel():
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
    TResult? Function(_ReactionModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReactionModel() when $default != null:
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
    TResult Function(String emoji, int count, bool me, List<String> users)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReactionModel() when $default != null:
        return $default(_that.emoji, _that.count, _that.me, _that.users);
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
    TResult Function(String emoji, int count, bool me, List<String> users)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReactionModel():
        return $default(_that.emoji, _that.count, _that.me, _that.users);
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
    TResult? Function(String emoji, int count, bool me, List<String> users)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReactionModel() when $default != null:
        return $default(_that.emoji, _that.count, _that.me, _that.users);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReactionModel implements ReactionModel {
  const _ReactionModel(
      {required this.emoji,
      this.count = 0,
      this.me = false,
      final List<String> users = const []})
      : _users = users;
  factory _ReactionModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionModelFromJson(json);

  @override
  final String emoji;
  @override
  @JsonKey()
  final int count;
  @override
  @JsonKey()
  final bool me;
  final List<String> _users;
  @override
  @JsonKey()
  List<String> get users {
    if (_users is EqualUnmodifiableListView) return _users;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_users);
  }

  /// Create a copy of ReactionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReactionModelCopyWith<_ReactionModel> get copyWith =>
      __$ReactionModelCopyWithImpl<_ReactionModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReactionModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReactionModel &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.me, me) || other.me == me) &&
            const DeepCollectionEquality().equals(other._users, _users));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, emoji, count, me,
      const DeepCollectionEquality().hash(_users));

  @override
  String toString() {
    return 'ReactionModel(emoji: $emoji, count: $count, me: $me, users: $users)';
  }
}

/// @nodoc
abstract mixin class _$ReactionModelCopyWith<$Res>
    implements $ReactionModelCopyWith<$Res> {
  factory _$ReactionModelCopyWith(
          _ReactionModel value, $Res Function(_ReactionModel) _then) =
      __$ReactionModelCopyWithImpl;
  @override
  @useResult
  $Res call({String emoji, int count, bool me, List<String> users});
}

/// @nodoc
class __$ReactionModelCopyWithImpl<$Res>
    implements _$ReactionModelCopyWith<$Res> {
  __$ReactionModelCopyWithImpl(this._self, this._then);

  final _ReactionModel _self;
  final $Res Function(_ReactionModel) _then;

  /// Create a copy of ReactionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? emoji = null,
    Object? count = null,
    Object? me = null,
    Object? users = null,
  }) {
    return _then(_ReactionModel(
      emoji: null == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String,
      count: null == count
          ? _self.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      me: null == me
          ? _self.me
          : me // ignore: cast_nullable_to_non_nullable
              as bool,
      users: null == users
          ? _self._users
          : users // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
