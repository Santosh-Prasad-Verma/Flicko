import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch_together_session.freezed.dart';
part 'watch_together_session.g.dart';

@freezed
abstract class WatchTogetherSettings with _$WatchTogetherSettings {
  const factory WatchTogetherSettings({
    @JsonKey(name: 'max_viewers') @Default(12) int maxViewers,
    @JsonKey(name: 'allow_seek_by_viewer') @Default(true) bool allowSeekByViewer,
  }) = _WatchTogetherSettings;

  factory WatchTogetherSettings.fromJson(Map<String, dynamic> json) => _$WatchTogetherSettingsFromJson(json);
}

@freezed
abstract class WatchTogetherSession with _$WatchTogetherSession {
  const factory WatchTogetherSession({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'host_user_id') required String hostUserId,
    @JsonKey(name: 'media_kind') required String mediaKind,
    @JsonKey(name: 'media_url') required String mediaUrl,
    @JsonKey(name: 'media_title') String? mediaTitle,
    @JsonKey(name: 'media_duration_ms') int? mediaDurationMs,
    required String state,
    @JsonKey(name: 'settings') required WatchTogetherSettings settings,
    @JsonKey(name: 'anchor_position_ms') @Default(0) int anchorPositionMs,
    @JsonKey(name: 'anchor_playing') @Default(false) bool anchorPlaying,
    @JsonKey(name: 'anchor_rate') @Default(1.0) double anchorRate,
    @JsonKey(name: 'anchor_wall_ms') @Default(0) int anchorWallMs,
    @Default(0) int seq,
    @JsonKey(name: 'is_standalone') @Default(false) bool isStandalone,
    @JsonKey(name: 'is_public') @Default(false) bool isPublic,
    @JsonKey(name: 'lobby_name') String? lobbyName,
  }) = _WatchTogetherSession;

  factory WatchTogetherSession.fromJson(Map<String, dynamic> json) => _$WatchTogetherSessionFromJson(json);
}

@freezed
abstract class WatchTogetherJoinResponse with _$WatchTogetherJoinResponse {
  const factory WatchTogetherJoinResponse({
    required WatchTogetherSession session,
    @JsonKey(name: 'livekit_token') required String liveKitToken,
  }) = _WatchTogetherJoinResponse;

  factory WatchTogetherJoinResponse.fromJson(Map<String, dynamic> json) => _$WatchTogetherJoinResponseFromJson(json);
}
