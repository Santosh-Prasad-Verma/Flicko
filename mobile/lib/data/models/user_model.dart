import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class Badge with _$Badge {
  const factory Badge({
    required String id,
    required String name,
    required String icon,
    required String color,
  }) = _Badge;

  factory Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);
}

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String username,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'avatar') String? avatarUrl,
    @JsonKey(name: 'banner') String? bannerUrl,
    String? bio,
    String? pronouns,
    String? phone,
    String? location,
    @JsonKey(name: 'website_url') String? websiteUrl,
    @JsonKey(name: 'social_link') String? socialLink,
    @JsonKey(name: 'accent_color') String? accentColor,
    @JsonKey(name: 'banner_colors') List<String>? bannerColors,
    @JsonKey(name: 'avatar_decoration') String? avatarDecoration,
    @JsonKey(name: 'online_status') @Default('offline') String onlineStatus,
    @JsonKey(name: 'custom_status') String? customStatus,
    @JsonKey(name: 'custom_status_emoji') String? customStatusEmoji,
    @JsonKey(name: 'badges', fromJson: _parseBadges) @Default([]) List<Badge> badges,
    @JsonKey(name: 'is_staff') @Default(false) bool isStaff,
    @JsonKey(name: 'is_partner') @Default(false) bool isPartner,
    @JsonKey(name: 'has_nitro') @Default(false) bool hasNitro,
    @JsonKey(name: 'created_at', fromJson: _parseDateTime) required DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _parseNullableDateTime) DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}

DateTime _parseDateTime(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
  if (val is DateTime) return val;
  return DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is String) return DateTime.tryParse(val);
  if (val is DateTime) return val;
  return null;
}

List<Badge> _parseBadges(dynamic val) {
  if (val == null) return const [];
  if (val is List) {
    return val.map((e) {
      if (e is Map<String, dynamic>) {
        return Badge.fromJson(e);
      } else if (e is Map) {
        return Badge.fromJson(Map<String, dynamic>.from(e));
      } else if (e is String) {
        return Badge(id: e, name: e, icon: '', color: '');
      }
      return null;
    }).whereType<Badge>().toList();
  }
  return const [];
}
