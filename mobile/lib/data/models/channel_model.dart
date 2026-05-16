import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel_model.freezed.dart';
part 'channel_model.g.dart';

enum ChannelType {
  @JsonValue('text') text,
  @JsonValue('voice') voice,
  @JsonValue('category') category,
  @JsonValue('announcement') announcement,
  @JsonValue('forum') forum,
  @JsonValue('stage') stage,
  @JsonValue('dm') dm,
  @JsonValue('photo_album') photoAlbum,
}

@freezed
abstract class ChannelModel with _$ChannelModel {
  const factory ChannelModel({
    required String id,
    @JsonKey(name: 'server_id') required String serverId,
    required String name,
    @Default(ChannelType.text) ChannelType type,
    String? topic,
    @Default(0) int position,
    @Default(false) bool nsfw,
    @JsonKey(name: 'parent_id') String? parentId,
    @JsonKey(name: 'slowmode_seconds') @Default(0) int slowmodeSeconds,
    @JsonKey(name: 'last_message_id') String? lastMessageId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ChannelModel;

  factory ChannelModel.fromJson(Map<String, dynamic> json) => _$ChannelModelFromJson(json);
}
