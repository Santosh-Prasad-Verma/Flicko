import 'package:freezed_annotation/freezed_annotation.dart';

part 'music_party_session.freezed.dart';
part 'music_party_session.g.dart';

@freezed
abstract class MusicPartySettings with _$MusicPartySettings {
  const factory MusicPartySettings({
    @JsonKey(name: 'vote_skip_threshold') @Default(0.5) double voteSkipThreshold,
    @JsonKey(name: 'max_listeners') @Default(25) int maxListeners,
    @JsonKey(name: 'allow_dupes') @Default(true) bool allowDupes,
  }) = _MusicPartySettings;

  factory MusicPartySettings.fromJson(Map<String, dynamic> json) =>
      _$MusicPartySettingsFromJson(json);
}

@freezed
abstract class MusicPartySession with _$MusicPartySession {
  const factory MusicPartySession({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'dj_user_id') required String djUserId,
    @JsonKey(name: 'next_dj_user_id') String? nextDjUserId,
    @JsonKey(name: 'rotation_mode') @Default('manual') String rotationMode,
    required String state,
    @JsonKey(name: 'current_track_uri') String? currentTrackUri,
    @JsonKey(name: 'current_position_ms') @Default(0) int currentPositionMs,
    @JsonKey(name: 'anchor_wall_ms') @Default(0) int anchorWallMs,
    @Default(0) int seq,
    required MusicPartySettings settings,
  }) = _MusicPartySession;

  factory MusicPartySession.fromJson(Map<String, dynamic> json) =>
      _$MusicPartySessionFromJson(json);
}

@freezed
abstract class MusicPartyQueueItem with _$MusicPartyQueueItem {
  const factory MusicPartyQueueItem({
    required String id,
    @JsonKey(name: 'session_id') required String sessionId,
    @JsonKey(name: 'spotify_uri') required String spotifyUri,
    String? title,
    String? artist,
    @JsonKey(name: 'duration_ms') int? durationMs,
    @JsonKey(name: 'album_art_url') String? albumArtUrl,
    @JsonKey(name: 'preview_url') String? previewUrl,
    @JsonKey(name: 'added_by_user_id') required String addedByUserId,
    required double position,
    @Default('queued') String state,
  }) = _MusicPartyQueueItem;

  factory MusicPartyQueueItem.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyQueueItemFromJson(json);
}

@freezed
abstract class MusicPartyAnchor with _$MusicPartyAnchor {
  const factory MusicPartyAnchor({
    @JsonKey(name: 'track_uri') required String trackUri,
    @JsonKey(name: 'position_ms') @Default(0) int positionMs,
    @Default(false) bool playing,
    @JsonKey(name: 'wall_clock_ms') @Default(0) int wallClockMs,
    @Default(0) int seq,
    @JsonKey(name: 'dj_id') required String djId,
  }) = _MusicPartyAnchor;

  factory MusicPartyAnchor.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyAnchorFromJson(json);
}

@freezed
abstract class MusicPartyJoinResponse with _$MusicPartyJoinResponse {
  const factory MusicPartyJoinResponse({
    required MusicPartySession session,
    @Default([]) List<MusicPartyQueueItem> queue,
    MusicPartyAnchor? anchor,
    @JsonKey(name: 'livekit_token') required String liveKitToken,
  }) = _MusicPartyJoinResponse;

  factory MusicPartyJoinResponse.fromJson(Map<String, dynamic> json) =>
      _$MusicPartyJoinResponseFromJson(json);
}

@freezed
abstract class SkipVoteStatus with _$SkipVoteStatus {
  const factory SkipVoteStatus({
    @JsonKey(name: 'current_votes') @Default(0) int currentVotes,
    @Default(0.5) double threshold,
    @JsonKey(name: 'total_voters') @Default(0) int totalVoters,
    @Default(false) bool reached,
  }) = _SkipVoteStatus;

  factory SkipVoteStatus.fromJson(Map<String, dynamic> json) =>
      _$SkipVoteStatusFromJson(json);
}
