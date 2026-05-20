import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/data/models/flicko_message.dart';

part 'chat_state.freezed.dart';

@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default([]) List<FlickoMessage> messages,
    @Default(<String>{}) Set<String> typingUsers,
    @Default(false) bool isLoading,
    @Default(false) bool isFetchingMore,
    @Default(false) bool isSending,
    @Default(true) bool hasMore,
    String? errorMessage,
    String? activeThreadId,
  }) = _ChatState;
}
