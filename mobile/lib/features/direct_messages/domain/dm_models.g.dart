// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DMConversation _$DMConversationFromJson(Map<String, dynamic> json) =>
    _DMConversation(
      id: json['id'] as String,
      participant: UserModel.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      lastMessage: json['lastMessage'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      isTyping: json['isTyping'] as bool? ?? false,
    );

Map<String, dynamic> _$DMConversationToJson(_DMConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'participant': instance.participant,
      'lastMessage': instance.lastMessage,
      'lastMessageAt': instance.lastMessageAt.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'isPinned': instance.isPinned,
      'isMuted': instance.isMuted,
      'isTyping': instance.isTyping,
    };

_DMAttachment _$DMAttachmentFromJson(Map<String, dynamic> json) =>
    _DMAttachment(
      url: json['url'] as String,
      type: json['type'] as String,
      name: json['name'] as String?,
      size: (json['size'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      appwriteFileId: json['appwrite_file_id'] as String?,
      appwriteBucketId: json['appwrite_bucket_id'] as String?,
    );

Map<String, dynamic> _$DMAttachmentToJson(_DMAttachment instance) =>
    <String, dynamic>{
      'url': instance.url,
      'type': instance.type,
      'name': instance.name,
      'size': instance.size,
      'width': instance.width,
      'height': instance.height,
      'appwrite_file_id': instance.appwriteFileId,
      'appwrite_bucket_id': instance.appwriteBucketId,
    };

_DMMessage _$DMMessageFromJson(Map<String, dynamic> json) => _DMMessage(
  id: json['id'] as String,
  senderId: json['sender_id'] as String,
  recipientId: json['recipient_id'] as String,
  content: json['content'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  sender: json['sender'] == null
      ? null
      : UserModel.fromJson(json['sender'] as Map<String, dynamic>),
  recipient: json['recipient'] == null
      ? null
      : UserModel.fromJson(json['recipient'] as Map<String, dynamic>),
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => DMAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DMMessageToJson(_DMMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender_id': instance.senderId,
      'recipient_id': instance.recipientId,
      'content': instance.content,
      'created_at': instance.createdAt.toIso8601String(),
      'sender': instance.sender,
      'recipient': instance.recipient,
      'attachments': instance.attachments,
    };
