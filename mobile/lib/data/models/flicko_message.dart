import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_model.dart';

part 'flicko_message.freezed.dart';
part 'flicko_message.g.dart';

@freezed
abstract class FlickoMessage with _$FlickoMessage {
  const factory FlickoMessage({
    required String id,
    @JsonKey(name: 'channel_id') String? channelId,
    @JsonKey(name: 'author_id') String? authorId,
    required String content,
    @Default('default') String type,
    @JsonKey(name: 'reply_to_id') String? replyToId,
    @JsonKey(name: 'thread_id') String? threadId,
    @Default([]) List<FlickoAttachment> attachments,
    @Default([]) List<FlickoReaction> reactions,
    @Default(false) bool pinned,
    @Default(false) bool edited,
    @JsonKey(name: 'edited_at', fromJson: _parseNullableDateTime) DateTime? editedAt,
    @JsonKey(name: 'created_at', fromJson: _parseDateTime) required DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _parseNullableDateTime) DateTime? updatedAt,
    // DM specific fields
    @JsonKey(name: 'recipient_id') String? recipientId,
    // Joined data
    UserModel? author,
    FlickoMessage? replyTo,
  }) = _FlickoMessage;

  factory FlickoMessage.fromJson(Map<String, dynamic> json) => _$FlickoMessageFromJson(json);
}

@freezed
abstract class FlickoAttachment with _$FlickoAttachment {
  const factory FlickoAttachment({
    required String id,
    required String filename,
    required String url,
    required int size,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'alt_text') String? altText,
    int? width,
    int? height,
  }) = _FlickoAttachment;

  factory FlickoAttachment.fromJson(Map<String, dynamic> json) => _$FlickoAttachmentFromJson(json);
}

@freezed
abstract class FlickoReaction with _$FlickoReaction {
  const factory FlickoReaction({
    required String emoji,
    @Default(0) int count,
    @Default(false) bool me,
    @Default([]) List<String> users,
  }) = _FlickoReaction;

  factory FlickoReaction.fromJson(Map<String, dynamic> json) => _$FlickoReactionFromJson(json);
}

DateTime _parseDateTime(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is String) return DateTime.parse(val);
  if (val is DateTime) return val;
  return DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is String) return DateTime.parse(val);
  if (val is DateTime) return val;
  return null;
}
