import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/repositories/message_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/services/media_processor_service.dart';
import 'chat_state.dart';

/// Provider for [ChatNotifier] scoped to a specific [channelId].
final chatNotifierProvider = NotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);

/// Notifier for managing chat messages in a specific channel.
class ChatNotifier extends Notifier<ChatState> {
  late final MessageRepository _repository;
  late final String _channelId;
  late final String _myId;
  RealtimeChannel? _subscription;

  final String channelId;
  ChatNotifier(this.channelId);

  @override
  ChatState build() {
    _channelId = channelId;
    _repository = ref.watch(messageRepositoryProvider);
    final authState = ref.watch(authNotifierProvider);
    _myId = authState.maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => '',
    );

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    init();
    return const ChatState();
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
      _refreshMessages();
    });

    _repository.subscribeToTyping(_channelId, (userId, isTyping) {
      if (userId == _myId) return;
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
          final originalFile = File(file.path);
          final processedFile = await MediaProcessorService.processMedia(originalFile);
          
          final url = await _repository.uploadAttachment(
            processedFile,
            _myId,
            _channelId,
          );
          
          final mimeType = lookupMimeType(processedFile.path) ?? 'application/octet-stream';
          
          uploadedAttachments.add(FlickoAttachment(
            id: DateTime.now().toIso8601String(),
            url: url,
            contentType: mimeType,
            filename: file.name,
            size: await processedFile.length(),
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
}
