// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_together_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WatchTogetherSettings _$WatchTogetherSettingsFromJson(
        Map<String, dynamic> json) =>
    _WatchTogetherSettings(
      maxViewers: (json['max_viewers'] as num?)?.toInt() ?? 12,
      allowSeekByViewer: json['allow_seek_by_viewer'] as bool? ?? true,
    );

Map<String, dynamic> _$WatchTogetherSettingsToJson(
        _WatchTogetherSettings instance) =>
    <String, dynamic>{
      'max_viewers': instance.maxViewers,
      'allow_seek_by_viewer': instance.allowSeekByViewer,
    };

_WatchTogetherSession _$WatchTogetherSessionFromJson(
        Map<String, dynamic> json) =>
    _WatchTogetherSession(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      hostUserId: json['host_user_id'] as String,
      mediaKind: json['media_kind'] as String,
      mediaUrl: json['media_url'] as String,
      mediaTitle: json['media_title'] as String?,
      mediaDurationMs: (json['media_duration_ms'] as num?)?.toInt(),
      state: json['state'] as String,
      settings: WatchTogetherSettings.fromJson(
          json['settings'] as Map<String, dynamic>),
      anchorPositionMs: (json['anchor_position_ms'] as num?)?.toInt() ?? 0,
      anchorPlaying: json['anchor_playing'] as bool? ?? false,
      anchorRate: (json['anchor_rate'] as num?)?.toDouble() ?? 1.0,
      anchorWallMs: (json['anchor_wall_ms'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      isStandalone: json['is_standalone'] as bool? ?? false,
      isPublic: json['is_public'] as bool? ?? false,
      lobbyName: json['lobby_name'] as String?,
    );

Map<String, dynamic> _$WatchTogetherSessionToJson(
        _WatchTogetherSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'host_user_id': instance.hostUserId,
      'media_kind': instance.mediaKind,
      'media_url': instance.mediaUrl,
      'media_title': instance.mediaTitle,
      'media_duration_ms': instance.mediaDurationMs,
      'state': instance.state,
      'settings': instance.settings,
      'anchor_position_ms': instance.anchorPositionMs,
      'anchor_playing': instance.anchorPlaying,
      'anchor_rate': instance.anchorRate,
      'anchor_wall_ms': instance.anchorWallMs,
      'seq': instance.seq,
      'is_standalone': instance.isStandalone,
      'is_public': instance.isPublic,
      'lobby_name': instance.lobbyName,
    };

_WatchTogetherJoinResponse _$WatchTogetherJoinResponseFromJson(
        Map<String, dynamic> json) =>
    _WatchTogetherJoinResponse(
      session: WatchTogetherSession.fromJson(
          json['session'] as Map<String, dynamic>),
      voiceToken: json['voice_token'] as String? ?? '',
    );

Map<String, dynamic> _$WatchTogetherJoinResponseToJson(
        _WatchTogetherJoinResponse instance) =>
    <String, dynamic>{
      'session': instance.session,
      'voice_token': instance.voiceToken,
    };
