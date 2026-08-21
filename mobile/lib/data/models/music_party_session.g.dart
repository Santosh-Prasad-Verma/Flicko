// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_party_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MusicPartySettings _$MusicPartySettingsFromJson(Map<String, dynamic> json) =>
    _MusicPartySettings(
      voteSkipThreshold:
          (json['vote_skip_threshold'] as num?)?.toDouble() ?? 0.5,
      maxListeners: (json['max_listeners'] as num?)?.toInt() ?? 25,
      allowDupes: json['allow_dupes'] as bool? ?? true,
    );

Map<String, dynamic> _$MusicPartySettingsToJson(_MusicPartySettings instance) =>
    <String, dynamic>{
      'vote_skip_threshold': instance.voteSkipThreshold,
      'max_listeners': instance.maxListeners,
      'allow_dupes': instance.allowDupes,
    };

_MusicPartySession _$MusicPartySessionFromJson(Map<String, dynamic> json) =>
    _MusicPartySession(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      djUserId: json['dj_user_id'] as String,
      nextDjUserId: json['next_dj_user_id'] as String?,
      rotationMode: json['rotation_mode'] as String? ?? 'manual',
      state: json['state'] as String,
      currentTrackUri: json['current_track_uri'] as String?,
      currentPositionMs: (json['current_position_ms'] as num?)?.toInt() ?? 0,
      anchorWallMs: (json['anchor_wall_ms'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      settings:
          MusicPartySettings.fromJson(json['settings'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MusicPartySessionToJson(_MusicPartySession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'dj_user_id': instance.djUserId,
      'next_dj_user_id': instance.nextDjUserId,
      'rotation_mode': instance.rotationMode,
      'state': instance.state,
      'current_track_uri': instance.currentTrackUri,
      'current_position_ms': instance.currentPositionMs,
      'anchor_wall_ms': instance.anchorWallMs,
      'seq': instance.seq,
      'settings': instance.settings,
    };

_MusicPartyQueueItem _$MusicPartyQueueItemFromJson(Map<String, dynamic> json) =>
    _MusicPartyQueueItem(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      spotifyUri: json['spotify_uri'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      albumArtUrl: json['album_art_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      addedByUserId: json['added_by_user_id'] as String,
      position: (json['position'] as num).toDouble(),
      state: json['state'] as String? ?? 'queued',
    );

Map<String, dynamic> _$MusicPartyQueueItemToJson(
        _MusicPartyQueueItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'session_id': instance.sessionId,
      'spotify_uri': instance.spotifyUri,
      'title': instance.title,
      'artist': instance.artist,
      'duration_ms': instance.durationMs,
      'album_art_url': instance.albumArtUrl,
      'preview_url': instance.previewUrl,
      'added_by_user_id': instance.addedByUserId,
      'position': instance.position,
      'state': instance.state,
    };

_MusicPartyAnchor _$MusicPartyAnchorFromJson(Map<String, dynamic> json) =>
    _MusicPartyAnchor(
      trackUri: json['track_uri'] as String,
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      playing: json['playing'] as bool? ?? false,
      wallClockMs: (json['wall_clock_ms'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      djId: json['dj_id'] as String,
    );

Map<String, dynamic> _$MusicPartyAnchorToJson(_MusicPartyAnchor instance) =>
    <String, dynamic>{
      'track_uri': instance.trackUri,
      'position_ms': instance.positionMs,
      'playing': instance.playing,
      'wall_clock_ms': instance.wallClockMs,
      'seq': instance.seq,
      'dj_id': instance.djId,
    };

_MusicPartyJoinResponse _$MusicPartyJoinResponseFromJson(
        Map<String, dynamic> json) =>
    _MusicPartyJoinResponse(
      session:
          MusicPartySession.fromJson(json['session'] as Map<String, dynamic>),
      queue: (json['queue'] as List<dynamic>?)
              ?.map((e) =>
                  MusicPartyQueueItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      anchor: json['anchor'] == null
          ? null
          : MusicPartyAnchor.fromJson(json['anchor'] as Map<String, dynamic>),
      voiceToken: json['voice_token'] as String? ?? '',
    );

Map<String, dynamic> _$MusicPartyJoinResponseToJson(
        _MusicPartyJoinResponse instance) =>
    <String, dynamic>{
      'session': instance.session,
      'queue': instance.queue,
      'anchor': instance.anchor,
      'voice_token': instance.voiceToken,
    };

_SkipVoteStatus _$SkipVoteStatusFromJson(Map<String, dynamic> json) =>
    _SkipVoteStatus(
      currentVotes: (json['current_votes'] as num?)?.toInt() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.5,
      totalVoters: (json['total_voters'] as num?)?.toInt() ?? 0,
      reached: json['reached'] as bool? ?? false,
    );

Map<String, dynamic> _$SkipVoteStatusToJson(_SkipVoteStatus instance) =>
    <String, dynamic>{
      'current_votes': instance.currentVotes,
      'threshold': instance.threshold,
      'total_voters': instance.totalVoters,
      'reached': instance.reached,
    };
