// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flicko_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FlickoMessage _$FlickoMessageFromJson(Map<String, dynamic> json) =>
    _FlickoMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String?,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      type: json['type'] as String? ?? 'default',
      replyToId: json['reply_to_id'] as String?,
      threadId: json['thread_id'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => FlickoAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.map((e) => FlickoReaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pinned: json['pinned'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      recipientId: json['recipient_id'] as String?,
      author: json['author'] == null
          ? null
          : UserModel.fromJson(json['author'] as Map<String, dynamic>),
      replyTo: json['replyTo'] == null
          ? null
          : FlickoMessage.fromJson(json['replyTo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FlickoMessageToJson(_FlickoMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'channel_id': instance.channelId,
      'author_id': instance.authorId,
      'content': instance.content,
      'type': instance.type,
      'reply_to_id': instance.replyToId,
      'thread_id': instance.threadId,
      'attachments': instance.attachments,
      'reactions': instance.reactions,
      'pinned': instance.pinned,
      'edited': instance.edited,
      'edited_at': instance.editedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'recipient_id': instance.recipientId,
      'author': instance.author,
      'replyTo': instance.replyTo,
    };

_FlickoAttachment _$FlickoAttachmentFromJson(Map<String, dynamic> json) =>
    _FlickoAttachment(
      id: json['id'] as String,
      filename: json['filename'] as String,
      url: json['url'] as String,
      size: (json['size'] as num).toInt(),
      contentType: json['content_type'] as String,
      altText: json['alt_text'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      appwriteFileId: json['appwrite_file_id'] as String?,
      appwriteBucketId: json['appwrite_bucket_id'] as String?,
    );

Map<String, dynamic> _$FlickoAttachmentToJson(_FlickoAttachment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'url': instance.url,
      'size': instance.size,
      'content_type': instance.contentType,
      'alt_text': instance.altText,
      'width': instance.width,
      'height': instance.height,
      'appwrite_file_id': instance.appwriteFileId,
      'appwrite_bucket_id': instance.appwriteBucketId,
    };

_FlickoReaction _$FlickoReactionFromJson(Map<String, dynamic> json) =>
    _FlickoReaction(
      emoji: json['emoji'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
      me: json['me'] as bool? ?? false,
      users:
          (json['users'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
    );

Map<String, dynamic> _$FlickoReactionToJson(_FlickoReaction instance) =>
    <String, dynamic>{
      'emoji': instance.emoji,
      'count': instance.count,
      'me': instance.me,
      'users': instance.users,
    };
