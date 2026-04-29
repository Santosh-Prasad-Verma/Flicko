// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChannelModel _$ChannelModelFromJson(Map<String, dynamic> json) =>
    _ChannelModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      name: json['name'] as String,
      type:
          $enumDecodeNullable(_$ChannelTypeEnumMap, json['type']) ??
          ChannelType.text,
      topic: json['topic'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      nsfw: json['nsfw'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
      slowmodeSeconds: (json['slowmode_seconds'] as num?)?.toInt() ?? 0,
      lastMessageId: json['last_message_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt:
          json['updated_at'] == null
              ? null
              : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ChannelModelToJson(_ChannelModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'server_id': instance.serverId,
      'name': instance.name,
      'type': _$ChannelTypeEnumMap[instance.type]!,
      'topic': instance.topic,
      'position': instance.position,
      'nsfw': instance.nsfw,
      'parent_id': instance.parentId,
      'slowmode_seconds': instance.slowmodeSeconds,
      'last_message_id': instance.lastMessageId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$ChannelTypeEnumMap = {
  ChannelType.text: 'text',
  ChannelType.voice: 'voice',
  ChannelType.category: 'category',
  ChannelType.announcement: 'announcement',
  ChannelType.forum: 'forum',
  ChannelType.stage: 'stage',
  ChannelType.dm: 'dm',
};
