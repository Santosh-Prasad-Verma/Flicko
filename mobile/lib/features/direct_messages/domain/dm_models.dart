import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/data/models/user_model.dart';

part 'dm_models.freezed.dart';
part 'dm_models.g.dart';

@freezed
class DMConversation with _$DMConversation {
  const factory DMConversation({
    required String id, // The other user's ID
    required UserModel participant,
    required String lastMessage,
    required DateTime lastMessageAt,
    @Default(0) int unreadCount,
    @Default(false) bool isPinned,
    @Default(false) bool isMuted,
    @Default(false) bool isTyping,
  }) = _DMConversation;

  factory DMConversation.fromJson(Map<String, dynamic> json) => _$DMConversationFromJson(json);
}

@freezed
class DMAttachment with _$DMAttachment {
  const factory DMAttachment({
    required String url,
    required String type,
    String? name,
    int? size,
    int? width,
    int? height,
  }) = _DMAttachment;

  factory DMAttachment.fromJson(Map<String, dynamic> json) => _$DMAttachmentFromJson(json);
}

@freezed
class DMMessage with _$DMMessage {
  const factory DMMessage({
    required String id,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'recipient_id') required String recipientId,
    required String content,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    UserModel? sender,
    UserModel? recipient,
    List<DMAttachment>? attachments,
  }) = _DMMessage;

  factory DMMessage.fromJson(Map<String, dynamic> json) => _$DMMessageFromJson(json);
}
