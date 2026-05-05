import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/repositories/message_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/models/auth_state.dart' as app_auth;
import 'chat_state.dart';

/// Notifier for managing chat messages in a specific channel.
class ChatNotifier extends StateNotifier<ChatState> {
  final MessageRepository _repository;
  final String _channelId;
  final String _myId;
  RealtimeChannel? _subscription;

  ChatNotifier(this._repository, this._channelId, this._myId) : super(const ChatState()) {
    init();
  }

  /// Initializes the chat state: fetches initial messages and sets up real-time listener.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final messages = await _repository.getMessages(_channelId);
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 50,
      );

      _setupSubscription();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _setupSubscription() {
    _subscription = _repository.subscribeToChannel(_channelId, (eventType, payload) {
      // In this modular version, we refresh to ensure all joined data (author profiles, etc.)
      // and nested models (reactions) are correctly parsed through the repository's logic.
      _refreshMessages();
    });

    _repository.subscribeToTyping(_channelId, (userId, isTyping) {
      if (userId == _myId) return; // Ignore own typing events
      final currentTyping = Set<String>.from(state.typingUsers);
      if (isTyping) {
        currentTyping.add(userId);
      } else {
        currentTyping.remove(userId);
      }
      state = state.copyWith(typingUsers: currentTyping);
    });
  }

  Future<void> _refreshMessages() async {
    try {
      final messages = await _repository.getMessages(_channelId);
      state = state.copyWith(messages: messages);
    } catch (_) {
      // Silent fail on background refresh
    }
  }

  /// Fetches the next page of messages for infinite scrolling.
  Future<void> fetchMore() async {
    if (state.isFetchingMore || !state.hasMore || state.messages.isEmpty) return;

    state = state.copyWith(isFetchingMore: true);
    try {
      final lastTimestamp = state.messages.last.createdAt;
      final moreMessages = await _repository.getMessages(_channelId, cursor: lastTimestamp);
      
      state = state.copyWith(
        messages: [...state.messages, ...moreMessages],
        isFetchingMore: false,
        hasMore: moreMessages.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isFetchingMore: false);
    }
  }

  /// Sends a new message with optional attachments.
  Future<void> sendMessage(String content, {String? replyToId, List<XFile>? localAttachments}) async {
    if (content.trim().isEmpty && (localAttachments == null || localAttachments.isEmpty)) return;

    state = state.copyWith(isSending: true);

    try {
      final List<FlickoAttachment> uploadedAttachments = [];
      
      if (localAttachments != null && localAttachments.isNotEmpty) {
        for (final file in localAttachments) {
          final result = await _repository.uploadAttachment(
            File(file.path),
            _myId,
            _channelId,
          );
          
          final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
          
          uploadedAttachments.add(FlickoAttachment(
            id: DateTime.now().toIso8601String(), // Temporary ID for model
            url: result['url']!,
            contentType: mimeType,
            filename: file.name,
            size: await file.length(),
            appwriteFileId: result['fileId'],
            appwriteBucketId: result['bucketId'],
          ));
        }
      }

      await _repository.sendMessage(
        channelId: _channelId,
        content: content,
        replyToId: replyToId,
        attachments: uploadedAttachments.isEmpty ? null : uploadedAttachments,
      );
      
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: 'Failed to send message: $e');
    }
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete message: $e');
    }
  }

  /// Toggles a reaction.
  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      await _repository.toggleReaction(messageId, emoji);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to toggle reaction: $e');
    }
  }

  /// Edits a message.
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await _repository.editMessage(messageId, newContent);
      // Refresh messages to show the edited content
      await _refreshMessages();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to edit message: $e');
    }
  }

  /// Send typing indicator state
  Future<void> sendTyping(bool isTyping) async {
    try {
      await _repository.sendTyping(_channelId, _myId, isTyping);
    } catch (_) {
      // Intentionally ignore failure to send typing indicator
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

/// Provider for [ChatNotifier] scoped to a specific [channelId].
final chatNotifierProvider = StateNotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>((ref, channelId) {
  final repository = ref.watch(messageRepositoryProvider);
  final app_auth.AuthState authState = ref.watch(authNotifierProvider);
  final myId = authState.maybeWhen(
    authenticated: (user, _) => user.id,
    orElse: () => '',
  );
  
  return ChatNotifier(repository, channelId, myId);
});
