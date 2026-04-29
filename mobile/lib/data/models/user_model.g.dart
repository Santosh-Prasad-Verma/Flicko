// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Badge _$BadgeFromJson(Map<String, dynamic> json) => _Badge(
  id: json['id'] as String,
  name: json['name'] as String,
  icon: json['icon'] as String,
  color: json['color'] as String,
);

Map<String, dynamic> _$BadgeToJson(_Badge instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'icon': instance.icon,
  'color': instance.color,
};

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  username: json['username'] as String,
  displayName: json['display_name'] as String?,
  avatarUrl: json['avatar'] as String?,
  bannerUrl: json['banner'] as String?,
  bio: json['bio'] as String?,
  pronouns: json['pronouns'] as String?,
  phone: json['phone'] as String?,
  accentColor: json['accent_color'] as String?,
  bannerColors:
      (json['banner_colors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  avatarDecoration: json['avatar_decoration'] as String?,
  onlineStatus: json['online_status'] as String? ?? 'offline',
  customStatus: json['custom_status'] as String?,
  customStatusEmoji: json['custom_status_emoji'] as String?,
  badges:
      (json['badges'] as List<dynamic>?)
          ?.map((e) => Badge.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  isStaff: json['is_staff'] as bool? ?? false,
  isPartner: json['is_partner'] as bool? ?? false,
  hasNitro: json['has_nitro'] as bool? ?? false,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt:
      json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'display_name': instance.displayName,
      'avatar': instance.avatarUrl,
      'banner': instance.bannerUrl,
      'bio': instance.bio,
      'pronouns': instance.pronouns,
      'phone': instance.phone,
      'accent_color': instance.accentColor,
      'banner_colors': instance.bannerColors,
      'avatar_decoration': instance.avatarDecoration,
      'online_status': instance.onlineStatus,
      'custom_status': instance.customStatus,
      'custom_status_emoji': instance.customStatusEmoji,
      'badges': instance.badges,
      'is_staff': instance.isStaff,
      'is_partner': instance.isPartner,
      'has_nitro': instance.hasNitro,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
