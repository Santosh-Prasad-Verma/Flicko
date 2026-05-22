import 'package:freezed_annotation/freezed_annotation.dart';

part 'music_model.freezed.dart';
part 'music_model.g.dart';

enum MusicType {
  @JsonValue('track')
  track,
  @JsonValue('album')
  album,
  @JsonValue('artist')
  artist,
}

@freezed
abstract class MusicItem with _$MusicItem {
  const factory MusicItem({
    required String id,
    required MusicType type,
    required String name,
    required String artistName,
    String? albumName,
    int? durationMs,
    String? imageUrl,
    String? previewUrl,
    String? externalUrl,
    @Default('saavn') String source,
  }) = _MusicItem;

  factory MusicItem.fromJson(Map<String, dynamic> json) => _$MusicItemFromJson(json);
}
