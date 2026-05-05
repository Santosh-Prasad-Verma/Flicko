import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class DMChatState {
  final List<DMMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? error;

  DMChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = true,
    this.error,
  });

  DMChatState copyWith({
    List<DMMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? error,
  }) {
    return DMChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

final dmChatControllerProvider = StateNotifierProvider.family<DMChatController, DMChatState, String>((ref, otherUserId) {
  final repository = ref.watch(dmRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final myId = authState.maybeWhen(
    authenticated: (user, _) => user.id,
    orElse: () => '',
  );
  
  return DMChatController(repository, myId, otherUserId)..init();
});

class DMChatController extends StateNotifier<DMChatState> {
  final DMRepository _repository;
  final String _myId;
  final String _otherUserId;
  RealtimeChannel? _subscription;

  DMChatController(this._repository, this._myId, this._otherUserId) : super(DMChatState());

  void init() {
    fetchMessages();
    _setupSubscription();
  }

  @override
  void dispose() {
    if (_subscription != null) {
      _repository.unsubscribe(_subscription!);
    }
    super.dispose();
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

    _subscription = _repository.subscribeToConversation(_myId, _otherUserId, (newMessage) {
      // Check if we already have this message (e.g. from optimistic update or race condition)
      if (state.messages.any((m) => m.id == newMessage.id)) return;

      // Append new message to the top (since list is inverted)
      state = state.copyWith(
        messages: [newMessage, ...state.messages],
      );
    });
  }

  Future<void> sendMessage(String content, {List<XFile>? localAttachments}) async {
    if (content.trim().isEmpty && (localAttachments == null || localAttachments.isEmpty)) return;

    state = state.copyWith(isSending: true);

    try {
      final List<DMAttachment> uploadedAttachments = [];
      
      if (localAttachments != null && localAttachments.isNotEmpty) {
        // Conversation ID is traditionally sort(myId, otherUserId) to keep it consistent
        final ids = [_myId, _otherUserId]..sort();
        final conversationId = ids.join('_');

        for (final file in localAttachments) {
          final url = await _repository.uploadAttachment(
            File(file.path),
            _myId,
            conversationId,
          );
          
          final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
          
          uploadedAttachments.add(DMAttachment(
            url: url,
            type: mimeType,
            name: file.name,
            size: await file.length(),
          ));
        }
      }

      await _repository.sendMessage(
        senderId: _myId,
        recipientId: _otherUserId,
        content: content,
        attachments: uploadedAttachments.isEmpty ? null : uploadedAttachments,
      );
      // Real-time listener will pick up the new message
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }
}
