// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageModel _$MessageModelFromJson(Map<String, dynamic> json) =>
    _MessageModel(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      type: json['type'] as String? ?? 'default',
      replyToId: json['reply_to_id'] as String?,
      threadId: json['thread_id'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => ReactionModel.fromJson(e as Map<String, dynamic>))
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
      author: json['author'] == null
          ? null
          : UserModel.fromJson(json['author'] as Map<String, dynamic>),
      replyTo: json['replyTo'] == null
          ? null
          : MessageModel.fromJson(json['replyTo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MessageModelToJson(_MessageModel instance) =>
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
      'author': instance.author,
      'replyTo': instance.replyTo,
    };

_AttachmentModel _$AttachmentModelFromJson(Map<String, dynamic> json) =>
    _AttachmentModel(
      id: json['id'] as String,
      filename: json['filename'] as String,
      url: json['url'] as String,
      size: (json['size'] as num).toInt(),
      contentType: json['content_type'] as String,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AttachmentModelToJson(_AttachmentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'url': instance.url,
      'size': instance.size,
      'content_type': instance.contentType,
      'width': instance.width,
      'height': instance.height,
    };

_ReactionModel _$ReactionModelFromJson(Map<String, dynamic> json) =>
    _ReactionModel(
      emoji: json['emoji'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
      me: json['me'] as bool? ?? false,
      users:
          (json['users'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$ReactionModelToJson(_ReactionModel instance) =>
    <String, dynamic>{
      'emoji': instance.emoji,
      'count': instance.count,
      'me': instance.me,
      'users': instance.users,
    };
