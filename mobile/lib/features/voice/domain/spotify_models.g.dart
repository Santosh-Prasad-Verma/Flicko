// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spotify_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpotifySession _$SpotifySessionFromJson(Map<String, dynamic> json) =>
    _SpotifySession(
      cookies: Map<String, String>.from(json['cookies'] as Map),
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      displayName: json['displayName'] as String?,
      spotifyUserId: json['spotifyUserId'] as String?,
    );

Map<String, dynamic> _$SpotifySessionToJson(_SpotifySession instance) =>
    <String, dynamic>{
      'cookies': instance.cookies,
      'connectedAt': instance.connectedAt.toIso8601String(),
      'displayName': instance.displayName,
      'spotifyUserId': instance.spotifyUserId,
    };

_SpotifyTrack _$SpotifyTrackFromJson(Map<String, dynamic> json) =>
    _SpotifyTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      artistName: json['artistName'] as String,
      albumName: json['albumName'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      uri: json['uri'] as String?,
    );

Map<String, dynamic> _$SpotifyTrackToJson(_SpotifyTrack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'artistName': instance.artistName,
      'albumName': instance.albumName,
      'durationMs': instance.durationMs,
      'imageUrl': instance.imageUrl,
      'externalUrl': instance.externalUrl,
      'uri': instance.uri,
    };

_PlaybackState _$PlaybackStateFromJson(Map<String, dynamic> json) =>
    _PlaybackState(
      isPlaying: json['isPlaying'] as bool? ?? false,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      currentTrack: json['currentTrack'] == null
          ? null
          : SpotifyTrack.fromJson(json['currentTrack'] as Map<String, dynamic>),
      deviceName: json['deviceName'] as String?,
      volumePercent: (json['volumePercent'] as num?)?.toInt() ?? 50,
      shuffleState: json['shuffleState'] as bool? ?? false,
      repeatState: json['repeatState'] as String? ?? 'off',
    );

Map<String, dynamic> _$PlaybackStateToJson(_PlaybackState instance) =>
    <String, dynamic>{
      'isPlaying': instance.isPlaying,
      'positionMs': instance.positionMs,
      'durationMs': instance.durationMs,
      'currentTrack': instance.currentTrack,
      'deviceName': instance.deviceName,
      'volumePercent': instance.volumePercent,
      'shuffleState': instance.shuffleState,
      'repeatState': instance.repeatState,
    };

_SpotifyPlaylist _$SpotifyPlaylistFromJson(Map<String, dynamic> json) =>
    _SpotifyPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] as bool? ?? false,
      externalUrl: json['externalUrl'] as String?,
    );

Map<String, dynamic> _$SpotifyPlaylistToJson(_SpotifyPlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'trackCount': instance.trackCount,
      'isPublic': instance.isPublic,
      'externalUrl': instance.externalUrl,
    };

_SpotifyDevice _$SpotifyDeviceFromJson(Map<String, dynamic> json) =>
    _SpotifyDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      isActive: json['isActive'] as bool? ?? false,
      volumePercent: (json['volumePercent'] as num?)?.toInt() ?? 50,
    );

Map<String, dynamic> _$SpotifyDeviceToJson(_SpotifyDevice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'isActive': instance.isActive,
      'volumePercent': instance.volumePercent,
    };
