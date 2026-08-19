import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/services/media_processor_service.dart';

import 'package:mobile/data/models/user_model.dart';

class DMChatState {
  final List<DMMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? error;
  final UserModel? participant;

  DMChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = true,
    this.error,
    this.participant,
  });

  DMChatState copyWith({
    List<DMMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? error,
    UserModel? participant,
  }) {
    return DMChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      participant: participant ?? this.participant,
    );
  }
}

final dmChatControllerProvider =
    NotifierProvider.autoDispose.family<DMChatController, DMChatState, String>(
  DMChatController.new,
);

class DMChatController extends Notifier<DMChatState> {
  late final DMRepository _repository;
  late final String _myId;
  late final String _otherUserId;
  RealtimeChannel? _subscription;

  DMChatController(this._otherUserId);

  @override
  DMChatState build() {
    _repository = ref.watch(dmRepositoryProvider);
    _myId = ref.watch(currentUserIdProvider) ?? '';

    ref.onDispose(() {
      if (_subscription != null) {
        _repository.unsubscribe(_subscription!);
      }
    });

    // Defer async initialization until after the first state exists.
    Future.microtask(_initChat);
    return DMChatState();
  }

  void _initChat() {
    fetchMessages();
    _loadParticipant();
    _setupSubscription();
  }

  Future<void> _loadParticipant() async {
    if (_otherUserId.isEmpty) return;
    try {
      final userProfile = await _repository.fetchUserProfile(_otherUserId);
      state = state.copyWith(participant: userProfile);
    } catch (e) {
      // Ignore or log error
    }
  }

  Future<void> fetchMessages({bool loadMore = false}) async {
    if (_myId.isEmpty) return;
    if (loadMore && !state.hasMore) return;

    if (!loadMore) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final lastTimestamp = loadMore && state.messages.isNotEmpty
          ? state.messages.last.createdAt
          : null;

      final newMessages = await _repository.fetchMessagesWithPagination(
        _myId,
        _otherUserId,
        before: lastTimestamp,
      );

      state = state.copyWith(
        messages: loadMore ? [...state.messages, ...newMessages] : newMessages,
        isLoading: false,
        hasMore: newMessages.length == 50,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupSubscription() {
    if (_myId.isEmpty) return;

    _subscription =
        _repository.subscribeToConversation(_myId, _otherUserId, (event, payload) async {
      if (event == PostgresChangeEvent.insert) {
        try {
          final newMessage = await _repository.decodeMessageRow(payload);
          // Only add if not already present
          if (!state.messages.any((m) => m.id == newMessage.id)) {
            state = state.copyWith(
              messages: [newMessage, ...state.messages],
            );
          }
        } catch (_) {
          fetchMessages();
        }
      } else {
        fetchMessages();
      }
    });
  }

  Future<void> sendMessage(String content,
      {List<XFile>? localAttachments}) async {
    if (content.trim().isEmpty &&
        (localAttachments == null || localAttachments.isEmpty)) {
      return;
    }

    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = DMMessage(
      id: tempMessageId,
      senderId: _myId,
      recipientId: _otherUserId,
      content: content,
      createdAt: DateTime.now(),
    );

    // Optimistically add the message to state immediately
    state = state.copyWith(
      messages: [tempMessage, ...state.messages],
      isSending: true,
    );

    try {
      final List<DMAttachment> uploadedAttachments = [];

      if (localAttachments != null && localAttachments.isNotEmpty) {
        final ids = [_myId, _otherUserId]..sort();
        final conversationId = ids.join('_');

        for (final file in localAttachments) {
          final originalFile = File(file.path);
          final processedFile = await MediaProcessorService.processMedia(originalFile);

          final url = await _repository.uploadAttachment(
            processedFile,
            _myId,
            conversationId,
          );

          final mimeType =
              lookupMimeType(processedFile.path) ?? 'application/octet-stream';

          uploadedAttachments.add(DMAttachment(
            url: url,
            type: mimeType,
            name: file.name,
            size: await processedFile.length(),
          ));
        }
      }

      final sentMessage = await _repository.sendMessage(
        senderId: _myId,
        recipientId: _otherUserId,
        content: content,
        attachments: uploadedAttachments.isEmpty ? null : uploadedAttachments,
      );
      
      // Replace the temp message with the actual sent message, unless it was already inserted by realtime
      final isAlreadyInserted = state.messages.any((m) => m.id == sentMessage.id);
      final List<DMMessage> updatedMessages;
      if (isAlreadyInserted) {
        updatedMessages = state.messages.where((m) => m.id != tempMessageId).toList();
      } else {
        updatedMessages = state.messages.map((m) {
          return m.id == tempMessageId ? sentMessage : m;
        }).toList();
      }

      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
      );
    } catch (e) {
      // Remove the temp message from the list on failure
      final updatedMessages = state.messages.where((m) => m.id != tempMessageId).toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> editMessage(String messageId, String content) async {
    try {
      await _repository.editMessage(messageId, _otherUserId, content);
      fetchMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
      fetchMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      await _repository.toggleReaction(messageId, emoji);
      fetchMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
