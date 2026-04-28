// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'soundboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SoundboardSound _$SoundboardSoundFromJson(Map<String, dynamic> json) =>
    _SoundboardSound(
      id: json['id'] as String,
      serverId: json['serverId'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      url: json['url'] as String,
      duration: (json['duration'] as num?)?.toInt() ?? 3,
      isFavorite: json['isFavorite'] as bool? ?? false,
      creatorId: json['creatorId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SoundboardSoundToJson(_SoundboardSound instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serverId': instance.serverId,
      'name': instance.name,
      'emoji': instance.emoji,
      'url': instance.url,
      'duration': instance.duration,
      'isFavorite': instance.isFavorite,
      'creatorId': instance.creatorId,
      'createdAt': instance.createdAt.toIso8601String(),
    };
