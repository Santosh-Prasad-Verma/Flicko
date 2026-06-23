import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/data/repositories/message_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/services/media_processor_service.dart';
import 'chat_state.dart';

/// Provider for [ChatNotifier] scoped to a specific [channelId].
final chatNotifierProvider =
    NotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);

/// Notifier for managing chat messages in a specific channel.
class ChatNotifier extends Notifier<ChatState> {
  late final MessageRepository _repository;
  late final String _channelId;
  late final String _myId;
  RealtimeChannel? _subscription;

  ChatNotifier(this._channelId);

  @override
  ChatState build() {
    _repository = ref.watch(messageRepositoryProvider);
    _myId = ref.watch(currentUserIdProvider) ?? '';

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    Future.microtask(init);
    return const ChatState();
  }

  /// Initializes the chat state: fetches initial messages and sets up real-time listener.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final messages = await _repository.getMessages(_channelId);
      print('[ChatNotifier] init successfully loaded channelId: $_channelId, fetched ${messages.length} messages');
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 50,
      );

      _setupSubscription();
    } catch (e) {
      print('[ChatNotifier] init failed for channelId: $_channelId with error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _setupSubscription() {
    _subscription = _repository.subscribeToChannel(_channelId, (eventType, payload) async {
      if (eventType == PostgresChangeEvent.insert) {
        try {
          final messageId = payload['id'] as String?;
          if (messageId == null) return;
          // Check if already in list to avoid duplicates
          if (state.messages.any((m) => m.id == messageId)) return;

          final newMessage = await _repository.getById(messageId);
          if (newMessage != null) {
            if (!state.messages.any((m) => m.id == newMessage.id)) {
              state = state.copyWith(
                messages: [newMessage, ...state.messages],
              );
            }
          }
        } catch (_) {
          _refreshMessages();
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        final messageId = payload['id'] as String?;
        if (messageId != null) {
          state = state.copyWith(
            messages: state.messages.where((m) => m.id != messageId).toList(),
          );
        }
      } else if (eventType == PostgresChangeEvent.update) {
        try {
          final messageId = payload['id'] as String?;
          if (messageId != null) {
            final updatedMessage = await _repository.getById(messageId);
            if (updatedMessage != null) {
              state = state.copyWith(
                messages: state.messages.map((m) => m.id == messageId ? updatedMessage : m).toList(),
              );
            }
          }
        } catch (_) {
          _refreshMessages();
        }
      } else {
        _refreshMessages();
      }
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
  Future<void> sendMessage(String content, {String? replyToId, List<XFile>? localAttachments, String? serverId}) async {
    if (content.trim().isEmpty && (localAttachments == null || localAttachments.isEmpty)) return;

    if (content.trim().startsWith('/')) {
      final rawInput = content.substring(1).trim();
      final tokens = _tokenize(rawInput);
      if (tokens.isNotEmpty) {
        final commandName = tokens[0];
        final args = tokens.sublist(1);
        final options = _parseCommandOptions(commandName, args);

        state = state.copyWith(isSending: true);
        try {
          final res = await _repository.invokeCommand(
            command: commandName,
            channelId: _channelId,
            serverId: serverId ?? '',
            options: options,
          );

          if (res != null) {
            final responseMap = res['response'] as Map<String, dynamic>?;
            if (responseMap != null) {
              final respContent = responseMap['content'] as String? ?? '';
              final embed = responseMap['embed'] as Map<String, dynamic>?;
              final ephemeral = responseMap['ephemeral'] as bool? ?? false;

              // Format content to include embed if present
              String finalContent = respContent;
              if (embed != null) {
                final title = embed['title'] as String? ?? '';
                final desc = embed['description'] as String? ?? '';
                final fields = embed['fields'] as List<dynamic>?;
                
                final List<String> embedParts = [];
                if (title.isNotEmpty) embedParts.add('**$title**');
                if (desc.isNotEmpty) embedParts.add(desc);
                if (fields != null) {
                  for (final f in fields) {
                    final fMap = Map<String, dynamic>.from(f as Map);
                    final fName = fMap['name'] as String? ?? '';
                    final fVal = fMap['value'] as String? ?? '';
                    if (fName.isNotEmpty || fVal.isNotEmpty) {
                      embedParts.add('$fName: $fVal');
                    }
                  }
                }
                if (embedParts.isNotEmpty) {
                  if (finalContent.isNotEmpty) {
                    finalContent = '$finalContent\n\n${embedParts.join('\n')}';
                  } else {
                    finalContent = embedParts.join('\n');
                  }
                }
              }

              if (ephemeral) {
                final ephemeralMsg = FlickoMessage(
                  id: 'ephemeral_${DateTime.now().millisecondsSinceEpoch}',
                  channelId: _channelId,
                  authorId: 'system',
                  content: finalContent,
                  type: 'ephemeral',
                  createdAt: DateTime.now(),
                  author: UserModel(
                    id: 'system',
                    username: 'System',
                    displayName: 'System',
                    avatarUrl: null,
                    onlineStatus: 'online',
                    createdAt: DateTime.now(),
                  ),
                );
                state = state.copyWith(
                  messages: [ephemeralMsg, ...state.messages],
                  isSending: false,
                );
              } else {
                await _repository.sendSystemMessage(_channelId, finalContent);
                state = state.copyWith(isSending: false);
              }
            } else {
              state = state.copyWith(
                isSending: false,
                errorMessage: 'Empty command response',
              );
            }
          } else {
            state = state.copyWith(
              isSending: false,
              errorMessage: 'Failed to execute command: no response',
            );
          }
        } catch (e) {
          state = state.copyWith(
            isSending: false,
            errorMessage: 'Failed to execute command: $e',
          );
        }
        return;
      }
    }

    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final authState = ref.read(authNotifierProvider);
    final UserModel? userProfile = authState.maybeWhen(
      authenticated: (_, profile) => profile,
      orElse: () => null,
    );

    final tempMessage = FlickoMessage(
      id: tempMessageId,
      channelId: _channelId,
      authorId: _myId,
      content: content,
      type: replyToId != null ? 'reply' : 'default',
      replyToId: replyToId,
      createdAt: DateTime.now(),
      author: userProfile,
    );

    state = state.copyWith(
      messages: [tempMessage, ...state.messages],
      isSending: true,
    );

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

      final messageId = await _repository.sendMessage(
        channelId: _channelId,
        content: content,
        replyToId: replyToId,
        attachments: uploadedAttachments.isEmpty ? null : uploadedAttachments,
      );

      final sentMessage = await _repository.getById(messageId);
      
      final isAlreadyInserted = state.messages.any((m) => m.id == messageId);
      final List<FlickoMessage> updatedMessages;
      if (isAlreadyInserted) {
        updatedMessages = state.messages.where((m) => m.id != tempMessageId).toList();
      } else {
        updatedMessages = state.messages.map((m) {
          if (m.id == tempMessageId) {
            return sentMessage ?? m.copyWith(id: messageId);
          }
          return m;
        }).toList();
      }
      
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
      );
    } catch (e) {
      final updatedMessages = state.messages.where((m) => m.id != tempMessageId).toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        errorMessage: 'Failed to send message: $e',
      );
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

  /// Toggles the pin status of a message.
  Future<void> togglePinMessage(String messageId, bool pinned) async {
    try {
      await _repository.togglePinMessage(messageId, pinned);
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == messageId ? m.copyWith(pinned: pinned) : m).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pin/unpin message: $e');
    }
  }

  /// Creates a thread from a message.
  Future<void> createThread(String messageId) async {
    try {
      await _repository.createThread(messageId);
      state = state.copyWith(activeThreadId: messageId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to create thread: $e');
    }
  }

  List<String> _tokenize(String text) {
    final List<String> tokens = [];
    final StringBuffer current = StringBuffer();
    bool inDoubleQuotes = false;
    bool inSingleQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
        current.write(char);
      } else if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
        current.write(char);
      } else if ((char == ' ' || char == '\t' || char == '\n') && !inDoubleQuotes && !inSingleQuotes) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      tokens.add(current.toString());
    }
    return tokens;
  }

  Map<String, dynamic> _parseCommandOptions(String commandName, List<String> args) {
    final Map<String, dynamic> options = {};
    int positionalIdx = 0;

    for (final arg in args) {
      final colonIdx = arg.indexOf(':');
      final equalIdx = arg.indexOf('=');

      if (colonIdx > 0) {
        final key = arg.substring(0, colonIdx).trim().toLowerCase();
        var val = arg.substring(colonIdx + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        if (val.toLowerCase() == 'true') {
          options[key] = true;
        } else if (val.toLowerCase() == 'false') {
          options[key] = false;
        } else {
          options[key] = val;
        }
      } else if (equalIdx > 0) {
        final key = arg.substring(0, equalIdx).trim().toLowerCase();
        var val = arg.substring(equalIdx + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        if (val.toLowerCase() == 'true') {
          options[key] = true;
        } else if (val.toLowerCase() == 'false') {
          options[key] = false;
        } else {
          options[key] = val;
        }
      } else {
        var val = arg.trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        if (positionalIdx == 0) {
          options['action'] = val;
        } else {
          options['positional_$positionalIdx'] = val;
        }
        positionalIdx++;
      }
    }
    return options;
  }
}
