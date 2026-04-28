import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_model.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

@freezed
abstract class MessageModel with _$MessageModel {
  const factory MessageModel({
    required String id,
    @JsonKey(name: 'channel_id') required String channelId,
    @JsonKey(name: 'author_id') required String authorId,
    required String content,
    @Default('default') String type,
    @JsonKey(name: 'reply_to_id') String? replyToId,
    @JsonKey(name: 'thread_id') String? threadId,
    @Default([]) List<AttachmentModel> attachments,
    @Default([]) List<ReactionModel> reactions,
    @Default(false) bool pinned,
    @Default(false) bool edited,
    @JsonKey(name: 'edited_at') DateTime? editedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Joined data
    UserModel? author,
    MessageModel? replyTo,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) => _$MessageModelFromJson(json);
}

@freezed
abstract class AttachmentModel with _$AttachmentModel {
  const factory AttachmentModel({
    required String id,
    required String filename,
    required String url,
    required int size,
    @JsonKey(name: 'content_type') required String contentType,
    int? width,
    int? height,
  }) = _AttachmentModel;

  factory AttachmentModel.fromJson(Map<String, dynamic> json) => _$AttachmentModelFromJson(json);
}

@freezed
abstract class ReactionModel with _$ReactionModel {
  const factory ReactionModel({
    required String emoji,
    @Default(0) int count,
    @Default(false) bool me,
    @Default([]) List<String> users,
  }) = _ReactionModel;

  factory ReactionModel.fromJson(Map<String, dynamic> json) => _$ReactionModelFromJson(json);
}
