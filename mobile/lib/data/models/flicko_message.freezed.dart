// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flicko_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FlickoMessage {

 String get id;@JsonKey(name: 'channel_id') String? get channelId;@JsonKey(name: 'author_id') String get authorId; String get content; String get type;@JsonKey(name: 'reply_to_id') String? get replyToId;@JsonKey(name: 'thread_id') String? get threadId; List<FlickoAttachment> get attachments; List<FlickoReaction> get reactions; bool get pinned; bool get edited;@JsonKey(name: 'edited_at') DateTime? get editedAt;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;// DM specific fields
@JsonKey(name: 'recipient_id') String? get recipientId;// Joined data
 UserModel? get author; FlickoMessage? get replyTo;
/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlickoMessageCopyWith<FlickoMessage> get copyWith => _$FlickoMessageCopyWithImpl<FlickoMessage>(this as FlickoMessage, _$identity);

  /// Serializes this FlickoMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlickoMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.content, content) || other.content == content)&&(identical(other.type, type) || other.type == type)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.edited, edited) || other.edited == edited)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.author, author) || other.author == author)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId,authorId,content,type,replyToId,threadId,const DeepCollectionEquality().hash(attachments),const DeepCollectionEquality().hash(reactions),pinned,edited,editedAt,createdAt,updatedAt,recipientId,author,replyTo);

@override
String toString() {
  return 'FlickoMessage(id: $id, channelId: $channelId, authorId: $authorId, content: $content, type: $type, replyToId: $replyToId, threadId: $threadId, attachments: $attachments, reactions: $reactions, pinned: $pinned, edited: $edited, editedAt: $editedAt, createdAt: $createdAt, updatedAt: $updatedAt, recipientId: $recipientId, author: $author, replyTo: $replyTo)';
}


}

/// @nodoc
abstract mixin class $FlickoMessageCopyWith<$Res>  {
  factory $FlickoMessageCopyWith(FlickoMessage value, $Res Function(FlickoMessage) _then) = _$FlickoMessageCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'channel_id') String? channelId,@JsonKey(name: 'author_id') String authorId, String content, String type,@JsonKey(name: 'reply_to_id') String? replyToId,@JsonKey(name: 'thread_id') String? threadId, List<FlickoAttachment> attachments, List<FlickoReaction> reactions, bool pinned, bool edited,@JsonKey(name: 'edited_at') DateTime? editedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'recipient_id') String? recipientId, UserModel? author, FlickoMessage? replyTo
});


$UserModelCopyWith<$Res>? get author;$FlickoMessageCopyWith<$Res>? get replyTo;

}
/// @nodoc
class _$FlickoMessageCopyWithImpl<$Res>
    implements $FlickoMessageCopyWith<$Res> {
  _$FlickoMessageCopyWithImpl(this._self, this._then);

  final FlickoMessage _self;
  final $Res Function(FlickoMessage) _then;

/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channelId = freezed,Object? authorId = null,Object? content = null,Object? type = null,Object? replyToId = freezed,Object? threadId = freezed,Object? attachments = null,Object? reactions = null,Object? pinned = null,Object? edited = null,Object? editedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? recipientId = freezed,Object? author = freezed,Object? replyTo = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<FlickoAttachment>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<FlickoReaction>,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,edited: null == edited ? _self.edited : edited // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recipientId: freezed == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserModel?,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as FlickoMessage?,
  ));
}
/// Create a copy of FlickoMessage
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
}/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlickoMessageCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $FlickoMessageCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}


/// Adds pattern-matching-related methods to [FlickoMessage].
extension FlickoMessagePatterns on FlickoMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlickoMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlickoMessage() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlickoMessage value)  $default,){
final _that = this;
switch (_that) {
case _FlickoMessage():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlickoMessage value)?  $default,){
final _that = this;
switch (_that) {
case _FlickoMessage() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'channel_id')  String? channelId, @JsonKey(name: 'author_id')  String authorId,  String content,  String type, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'thread_id')  String? threadId,  List<FlickoAttachment> attachments,  List<FlickoReaction> reactions,  bool pinned,  bool edited, @JsonKey(name: 'edited_at')  DateTime? editedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'recipient_id')  String? recipientId,  UserModel? author,  FlickoMessage? replyTo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlickoMessage() when $default != null:
return $default(_that.id,_that.channelId,_that.authorId,_that.content,_that.type,_that.replyToId,_that.threadId,_that.attachments,_that.reactions,_that.pinned,_that.edited,_that.editedAt,_that.createdAt,_that.updatedAt,_that.recipientId,_that.author,_that.replyTo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'channel_id')  String? channelId, @JsonKey(name: 'author_id')  String authorId,  String content,  String type, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'thread_id')  String? threadId,  List<FlickoAttachment> attachments,  List<FlickoReaction> reactions,  bool pinned,  bool edited, @JsonKey(name: 'edited_at')  DateTime? editedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'recipient_id')  String? recipientId,  UserModel? author,  FlickoMessage? replyTo)  $default,) {final _that = this;
switch (_that) {
case _FlickoMessage():
return $default(_that.id,_that.channelId,_that.authorId,_that.content,_that.type,_that.replyToId,_that.threadId,_that.attachments,_that.reactions,_that.pinned,_that.edited,_that.editedAt,_that.createdAt,_that.updatedAt,_that.recipientId,_that.author,_that.replyTo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'channel_id')  String? channelId, @JsonKey(name: 'author_id')  String authorId,  String content,  String type, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'thread_id')  String? threadId,  List<FlickoAttachment> attachments,  List<FlickoReaction> reactions,  bool pinned,  bool edited, @JsonKey(name: 'edited_at')  DateTime? editedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'recipient_id')  String? recipientId,  UserModel? author,  FlickoMessage? replyTo)?  $default,) {final _that = this;
switch (_that) {
case _FlickoMessage() when $default != null:
return $default(_that.id,_that.channelId,_that.authorId,_that.content,_that.type,_that.replyToId,_that.threadId,_that.attachments,_that.reactions,_that.pinned,_that.edited,_that.editedAt,_that.createdAt,_that.updatedAt,_that.recipientId,_that.author,_that.replyTo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlickoMessage implements FlickoMessage {
  const _FlickoMessage({required this.id, @JsonKey(name: 'channel_id') this.channelId, @JsonKey(name: 'author_id') required this.authorId, required this.content, this.type = 'default', @JsonKey(name: 'reply_to_id') this.replyToId, @JsonKey(name: 'thread_id') this.threadId, final  List<FlickoAttachment> attachments = const [], final  List<FlickoReaction> reactions = const [], this.pinned = false, this.edited = false, @JsonKey(name: 'edited_at') this.editedAt, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'recipient_id') this.recipientId, this.author, this.replyTo}): _attachments = attachments,_reactions = reactions;
  factory _FlickoMessage.fromJson(Map<String, dynamic> json) => _$FlickoMessageFromJson(json);

@override final  String id;
@override@JsonKey(name: 'channel_id') final  String? channelId;
@override@JsonKey(name: 'author_id') final  String authorId;
@override final  String content;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'reply_to_id') final  String? replyToId;
@override@JsonKey(name: 'thread_id') final  String? threadId;
 final  List<FlickoAttachment> _attachments;
@override@JsonKey() List<FlickoAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

 final  List<FlickoReaction> _reactions;
@override@JsonKey() List<FlickoReaction> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

@override@JsonKey() final  bool pinned;
@override@JsonKey() final  bool edited;
@override@JsonKey(name: 'edited_at') final  DateTime? editedAt;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
// DM specific fields
@override@JsonKey(name: 'recipient_id') final  String? recipientId;
// Joined data
@override final  UserModel? author;
@override final  FlickoMessage? replyTo;

/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlickoMessageCopyWith<_FlickoMessage> get copyWith => __$FlickoMessageCopyWithImpl<_FlickoMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlickoMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlickoMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.content, content) || other.content == content)&&(identical(other.type, type) || other.type == type)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.edited, edited) || other.edited == edited)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.recipientId, recipientId) || other.recipientId == recipientId)&&(identical(other.author, author) || other.author == author)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId,authorId,content,type,replyToId,threadId,const DeepCollectionEquality().hash(_attachments),const DeepCollectionEquality().hash(_reactions),pinned,edited,editedAt,createdAt,updatedAt,recipientId,author,replyTo);

@override
String toString() {
  return 'FlickoMessage(id: $id, channelId: $channelId, authorId: $authorId, content: $content, type: $type, replyToId: $replyToId, threadId: $threadId, attachments: $attachments, reactions: $reactions, pinned: $pinned, edited: $edited, editedAt: $editedAt, createdAt: $createdAt, updatedAt: $updatedAt, recipientId: $recipientId, author: $author, replyTo: $replyTo)';
}


}

/// @nodoc
abstract mixin class _$FlickoMessageCopyWith<$Res> implements $FlickoMessageCopyWith<$Res> {
  factory _$FlickoMessageCopyWith(_FlickoMessage value, $Res Function(_FlickoMessage) _then) = __$FlickoMessageCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'channel_id') String? channelId,@JsonKey(name: 'author_id') String authorId, String content, String type,@JsonKey(name: 'reply_to_id') String? replyToId,@JsonKey(name: 'thread_id') String? threadId, List<FlickoAttachment> attachments, List<FlickoReaction> reactions, bool pinned, bool edited,@JsonKey(name: 'edited_at') DateTime? editedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'recipient_id') String? recipientId, UserModel? author, FlickoMessage? replyTo
});


@override $UserModelCopyWith<$Res>? get author;@override $FlickoMessageCopyWith<$Res>? get replyTo;

}
/// @nodoc
class __$FlickoMessageCopyWithImpl<$Res>
    implements _$FlickoMessageCopyWith<$Res> {
  __$FlickoMessageCopyWithImpl(this._self, this._then);

  final _FlickoMessage _self;
  final $Res Function(_FlickoMessage) _then;

/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channelId = freezed,Object? authorId = null,Object? content = null,Object? type = null,Object? replyToId = freezed,Object? threadId = freezed,Object? attachments = null,Object? reactions = null,Object? pinned = null,Object? edited = null,Object? editedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? recipientId = freezed,Object? author = freezed,Object? replyTo = freezed,}) {
  return _then(_FlickoMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<FlickoAttachment>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<FlickoReaction>,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,edited: null == edited ? _self.edited : edited // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recipientId: freezed == recipientId ? _self.recipientId : recipientId // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserModel?,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as FlickoMessage?,
  ));
}

/// Create a copy of FlickoMessage
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
}/// Create a copy of FlickoMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlickoMessageCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $FlickoMessageCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}


/// @nodoc
mixin _$FlickoAttachment {

 String get id; String get filename; String get url; int get size;@JsonKey(name: 'content_type') String get contentType;@JsonKey(name: 'alt_text') String? get altText; int? get width; int? get height;@JsonKey(name: 'appwrite_file_id') String? get appwriteFileId;@JsonKey(name: 'appwrite_bucket_id') String? get appwriteBucketId;
/// Create a copy of FlickoAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlickoAttachmentCopyWith<FlickoAttachment> get copyWith => _$FlickoAttachmentCopyWithImpl<FlickoAttachment>(this as FlickoAttachment, _$identity);

  /// Serializes this FlickoAttachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlickoAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.url, url) || other.url == url)&&(identical(other.size, size) || other.size == size)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.altText, altText) || other.altText == altText)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.appwriteFileId, appwriteFileId) || other.appwriteFileId == appwriteFileId)&&(identical(other.appwriteBucketId, appwriteBucketId) || other.appwriteBucketId == appwriteBucketId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,filename,url,size,contentType,altText,width,height,appwriteFileId,appwriteBucketId);

@override
String toString() {
  return 'FlickoAttachment(id: $id, filename: $filename, url: $url, size: $size, contentType: $contentType, altText: $altText, width: $width, height: $height, appwriteFileId: $appwriteFileId, appwriteBucketId: $appwriteBucketId)';
}


}

/// @nodoc
abstract mixin class $FlickoAttachmentCopyWith<$Res>  {
  factory $FlickoAttachmentCopyWith(FlickoAttachment value, $Res Function(FlickoAttachment) _then) = _$FlickoAttachmentCopyWithImpl;
@useResult
$Res call({
 String id, String filename, String url, int size,@JsonKey(name: 'content_type') String contentType,@JsonKey(name: 'alt_text') String? altText, int? width, int? height,@JsonKey(name: 'appwrite_file_id') String? appwriteFileId,@JsonKey(name: 'appwrite_bucket_id') String? appwriteBucketId
});




}
/// @nodoc
class _$FlickoAttachmentCopyWithImpl<$Res>
    implements $FlickoAttachmentCopyWith<$Res> {
  _$FlickoAttachmentCopyWithImpl(this._self, this._then);

  final FlickoAttachment _self;
  final $Res Function(FlickoAttachment) _then;

/// Create a copy of FlickoAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? filename = null,Object? url = null,Object? size = null,Object? contentType = null,Object? altText = freezed,Object? width = freezed,Object? height = freezed,Object? appwriteFileId = freezed,Object? appwriteBucketId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,altText: freezed == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,appwriteFileId: freezed == appwriteFileId ? _self.appwriteFileId : appwriteFileId // ignore: cast_nullable_to_non_nullable
as String?,appwriteBucketId: freezed == appwriteBucketId ? _self.appwriteBucketId : appwriteBucketId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FlickoAttachment].
extension FlickoAttachmentPatterns on FlickoAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlickoAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlickoAttachment() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlickoAttachment value)  $default,){
final _that = this;
switch (_that) {
case _FlickoAttachment():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlickoAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _FlickoAttachment() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String filename,  String url,  int size, @JsonKey(name: 'content_type')  String contentType, @JsonKey(name: 'alt_text')  String? altText,  int? width,  int? height, @JsonKey(name: 'appwrite_file_id')  String? appwriteFileId, @JsonKey(name: 'appwrite_bucket_id')  String? appwriteBucketId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlickoAttachment() when $default != null:
return $default(_that.id,_that.filename,_that.url,_that.size,_that.contentType,_that.altText,_that.width,_that.height,_that.appwriteFileId,_that.appwriteBucketId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String filename,  String url,  int size, @JsonKey(name: 'content_type')  String contentType, @JsonKey(name: 'alt_text')  String? altText,  int? width,  int? height, @JsonKey(name: 'appwrite_file_id')  String? appwriteFileId, @JsonKey(name: 'appwrite_bucket_id')  String? appwriteBucketId)  $default,) {final _that = this;
switch (_that) {
case _FlickoAttachment():
return $default(_that.id,_that.filename,_that.url,_that.size,_that.contentType,_that.altText,_that.width,_that.height,_that.appwriteFileId,_that.appwriteBucketId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String filename,  String url,  int size, @JsonKey(name: 'content_type')  String contentType, @JsonKey(name: 'alt_text')  String? altText,  int? width,  int? height, @JsonKey(name: 'appwrite_file_id')  String? appwriteFileId, @JsonKey(name: 'appwrite_bucket_id')  String? appwriteBucketId)?  $default,) {final _that = this;
switch (_that) {
case _FlickoAttachment() when $default != null:
return $default(_that.id,_that.filename,_that.url,_that.size,_that.contentType,_that.altText,_that.width,_that.height,_that.appwriteFileId,_that.appwriteBucketId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlickoAttachment implements FlickoAttachment {
  const _FlickoAttachment({required this.id, required this.filename, required this.url, required this.size, @JsonKey(name: 'content_type') required this.contentType, @JsonKey(name: 'alt_text') this.altText, this.width, this.height, @JsonKey(name: 'appwrite_file_id') this.appwriteFileId, @JsonKey(name: 'appwrite_bucket_id') this.appwriteBucketId});
  factory _FlickoAttachment.fromJson(Map<String, dynamic> json) => _$FlickoAttachmentFromJson(json);

@override final  String id;
@override final  String filename;
@override final  String url;
@override final  int size;
@override@JsonKey(name: 'content_type') final  String contentType;
@override@JsonKey(name: 'alt_text') final  String? altText;
@override final  int? width;
@override final  int? height;
@override@JsonKey(name: 'appwrite_file_id') final  String? appwriteFileId;
@override@JsonKey(name: 'appwrite_bucket_id') final  String? appwriteBucketId;

/// Create a copy of FlickoAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlickoAttachmentCopyWith<_FlickoAttachment> get copyWith => __$FlickoAttachmentCopyWithImpl<_FlickoAttachment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlickoAttachmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlickoAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.url, url) || other.url == url)&&(identical(other.size, size) || other.size == size)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.altText, altText) || other.altText == altText)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.appwriteFileId, appwriteFileId) || other.appwriteFileId == appwriteFileId)&&(identical(other.appwriteBucketId, appwriteBucketId) || other.appwriteBucketId == appwriteBucketId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,filename,url,size,contentType,altText,width,height,appwriteFileId,appwriteBucketId);

@override
String toString() {
  return 'FlickoAttachment(id: $id, filename: $filename, url: $url, size: $size, contentType: $contentType, altText: $altText, width: $width, height: $height, appwriteFileId: $appwriteFileId, appwriteBucketId: $appwriteBucketId)';
}


}

/// @nodoc
abstract mixin class _$FlickoAttachmentCopyWith<$Res> implements $FlickoAttachmentCopyWith<$Res> {
  factory _$FlickoAttachmentCopyWith(_FlickoAttachment value, $Res Function(_FlickoAttachment) _then) = __$FlickoAttachmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String filename, String url, int size,@JsonKey(name: 'content_type') String contentType,@JsonKey(name: 'alt_text') String? altText, int? width, int? height,@JsonKey(name: 'appwrite_file_id') String? appwriteFileId,@JsonKey(name: 'appwrite_bucket_id') String? appwriteBucketId
});




}
/// @nodoc
class __$FlickoAttachmentCopyWithImpl<$Res>
    implements _$FlickoAttachmentCopyWith<$Res> {
  __$FlickoAttachmentCopyWithImpl(this._self, this._then);

  final _FlickoAttachment _self;
  final $Res Function(_FlickoAttachment) _then;

/// Create a copy of FlickoAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? filename = null,Object? url = null,Object? size = null,Object? contentType = null,Object? altText = freezed,Object? width = freezed,Object? height = freezed,Object? appwriteFileId = freezed,Object? appwriteBucketId = freezed,}) {
  return _then(_FlickoAttachment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,altText: freezed == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,appwriteFileId: freezed == appwriteFileId ? _self.appwriteFileId : appwriteFileId // ignore: cast_nullable_to_non_nullable
as String?,appwriteBucketId: freezed == appwriteBucketId ? _self.appwriteBucketId : appwriteBucketId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$FlickoReaction {

 String get emoji; int get count; bool get me; List<String> get users;
/// Create a copy of FlickoReaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlickoReactionCopyWith<FlickoReaction> get copyWith => _$FlickoReactionCopyWithImpl<FlickoReaction>(this as FlickoReaction, _$identity);

  /// Serializes this FlickoReaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlickoReaction&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other.users, users));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,emoji,count,me,const DeepCollectionEquality().hash(users));

@override
String toString() {
  return 'FlickoReaction(emoji: $emoji, count: $count, me: $me, users: $users)';
}


}

/// @nodoc
abstract mixin class $FlickoReactionCopyWith<$Res>  {
  factory $FlickoReactionCopyWith(FlickoReaction value, $Res Function(FlickoReaction) _then) = _$FlickoReactionCopyWithImpl;
@useResult
$Res call({
 String emoji, int count, bool me, List<String> users
});




}
/// @nodoc
class _$FlickoReactionCopyWithImpl<$Res>
    implements $FlickoReactionCopyWith<$Res> {
  _$FlickoReactionCopyWithImpl(this._self, this._then);

  final FlickoReaction _self;
  final $Res Function(FlickoReaction) _then;

/// Create a copy of FlickoReaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? emoji = null,Object? count = null,Object? me = null,Object? users = null,}) {
  return _then(_self.copyWith(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as bool,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [FlickoReaction].
extension FlickoReactionPatterns on FlickoReaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlickoReaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlickoReaction() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlickoReaction value)  $default,){
final _that = this;
switch (_that) {
case _FlickoReaction():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlickoReaction value)?  $default,){
final _that = this;
switch (_that) {
case _FlickoReaction() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String emoji,  int count,  bool me,  List<String> users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlickoReaction() when $default != null:
return $default(_that.emoji,_that.count,_that.me,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String emoji,  int count,  bool me,  List<String> users)  $default,) {final _that = this;
switch (_that) {
case _FlickoReaction():
return $default(_that.emoji,_that.count,_that.me,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String emoji,  int count,  bool me,  List<String> users)?  $default,) {final _that = this;
switch (_that) {
case _FlickoReaction() when $default != null:
return $default(_that.emoji,_that.count,_that.me,_that.users);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlickoReaction implements FlickoReaction {
  const _FlickoReaction({required this.emoji, this.count = 0, this.me = false, final  List<String> users = const []}): _users = users;
  factory _FlickoReaction.fromJson(Map<String, dynamic> json) => _$FlickoReactionFromJson(json);

@override final  String emoji;
@override@JsonKey() final  int count;
@override@JsonKey() final  bool me;
 final  List<String> _users;
@override@JsonKey() List<String> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}


/// Create a copy of FlickoReaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlickoReactionCopyWith<_FlickoReaction> get copyWith => __$FlickoReactionCopyWithImpl<_FlickoReaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlickoReactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlickoReaction&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other._users, _users));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,emoji,count,me,const DeepCollectionEquality().hash(_users));

@override
String toString() {
  return 'FlickoReaction(emoji: $emoji, count: $count, me: $me, users: $users)';
}


}

/// @nodoc
abstract mixin class _$FlickoReactionCopyWith<$Res> implements $FlickoReactionCopyWith<$Res> {
  factory _$FlickoReactionCopyWith(_FlickoReaction value, $Res Function(_FlickoReaction) _then) = __$FlickoReactionCopyWithImpl;
@override @useResult
$Res call({
 String emoji, int count, bool me, List<String> users
});




}
/// @nodoc
class __$FlickoReactionCopyWithImpl<$Res>
    implements _$FlickoReactionCopyWith<$Res> {
  __$FlickoReactionCopyWithImpl(this._self, this._then);

  final _FlickoReaction _self;
  final $Res Function(_FlickoReaction) _then;

/// Create a copy of FlickoReaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? emoji = null,Object? count = null,Object? me = null,Object? users = null,}) {
  return _then(_FlickoReaction(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as bool,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
