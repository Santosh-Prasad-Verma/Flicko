// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MusicItem _$MusicItemFromJson(Map<String, dynamic> json) => _MusicItem(
  id: json['id'] as String,
  type: $enumDecode(_$MusicTypeEnumMap, json['type']),
  name: json['name'] as String,
  artistName: json['artistName'] as String,
  albumName: json['albumName'] as String?,
  durationMs: (json['durationMs'] as num?)?.toInt(),
  imageUrl: json['imageUrl'] as String?,
  previewUrl: json['previewUrl'] as String?,
  externalUrl: json['externalUrl'] as String?,
  source: json['source'] as String? ?? 'appleMusic',
);

Map<String, dynamic> _$MusicItemToJson(_MusicItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$MusicTypeEnumMap[instance.type]!,
      'name': instance.name,
      'artistName': instance.artistName,
      'albumName': instance.albumName,
      'durationMs': instance.durationMs,
      'imageUrl': instance.imageUrl,
      'previewUrl': instance.previewUrl,
      'externalUrl': instance.externalUrl,
      'source': instance.source,
    };

const _$MusicTypeEnumMap = {
  MusicType.track: 'track',
  MusicType.album: 'album',
  MusicType.artist: 'artist',
};
