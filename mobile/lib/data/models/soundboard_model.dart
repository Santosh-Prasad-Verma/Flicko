import 'package:freezed_annotation/freezed_annotation.dart';

part 'soundboard_model.freezed.dart';
part 'soundboard_model.g.dart';

@freezed
abstract class SoundboardSound with _$SoundboardSound {
  const factory SoundboardSound({
    required String id,
    required String serverId,
    required String name,
    required String emoji,
    required String url,
    @Default(3) int duration, // in seconds
    @Default(false) bool isFavorite,
    required String creatorId,
    required DateTime createdAt,
  }) = _SoundboardSound;

  factory SoundboardSound.fromJson(Map<String, dynamic> json) => _$SoundboardSoundFromJson(json);
}
