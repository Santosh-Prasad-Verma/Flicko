// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerModel _$ServerModelFromJson(Map<String, dynamic> json) => _ServerModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  iconUrl: json['icon'] as String?,
  bannerUrl: json['banner'] as String?,
  ownerId: json['owner_id'] as String,
  memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ServerModelToJson(_ServerModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.iconUrl,
      'banner': instance.bannerUrl,
      'owner_id': instance.ownerId,
      'member_count': instance.memberCount,
      'created_at': instance.createdAt.toIso8601String(),
    };
