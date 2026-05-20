import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/server_channels/chat/application/chat_notifier.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_item.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/message_actions.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_input.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/poll_creator_modal.dart';

import 'package:mobile/core/widgets/particle_fx_engine.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;
  final String? channelName;

  const ChatScreen({
    super.key,
    required this.serverId,
    required this.channelId,
    this.channelName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final ParticleController _particleController = ParticleController();
  FlickoMessage? _replyTo;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatNotifierProvider(widget.channelId).notifier).fetchMore();
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(FlickoColors.bgTertiary),
      ),
    );
  }

  void _onMessageLongPress(FlickoMessage message) {
    final currentUserId = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => '',
    );

    context.showMessageActions(
      message: message,
      currentUserId: currentUserId,
      onReaction: (emoji) => ref
          .read(chatNotifierProvider(widget.channelId).notifier)
          .toggleReaction(message.id, emoji),
      onReply: () => setState(() => _replyTo = message),
      onEdit: () {
        // Edit is handled inline by EnhancedMessageItem
      },
      onDelete: () => ref
          .read(chatNotifierProvider(widget.channelId).notifier)
          .deleteMessage(message.id),
      onCopy: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied to clipboard', style: GoogleFonts.inter()),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      onThread: () {
        ref.read(chatNotifierProvider(widget.channelId).notifier)
            .createThread(message.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider(widget.channelId));

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.tag, color: Color(FlickoColors.textMuted), size: 20),
            const SizedBox(width: 8),
            Text(
              widget.channelName ?? 'Channel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined, color: Color(FlickoColors.textMuted)),
            onPressed: () => _showComingSoon('Voice channels'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(FlickoColors.textMuted)),
            onPressed: () => _showComingSoon('Video channels'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, color: Color(FlickoColors.textMuted)),
            onPressed: () {},
          ),
        ],
      ),
      body: ParticleFxEngine(
        controller: _particleController,
        child: Column(
          children: [
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        // Check if new messages arrived and contain trigger words
                        if (chatState.messages.length > _lastMessageCount) {
                          final newMessages = chatState.messages.sublist(
                              0, chatState.messages.length - _lastMessageCount);
                          _lastMessageCount = chatState.messages.length;

                          for (var msg in newMessages) {
                            if (ParticleFxEngine.shouldTriggerFx(msg.content)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _particleController.play();
                              });
                              break; // Only play once per batch
                            }
                          }
                        }

                        return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Discord style lists newest at bottom
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: chatState.messages.length + (chatState.isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      final message = chatState.messages[index];
                      final nextMessage = index > 0 ? chatState.messages[index - 1] : null;

                      // Grouping logic: Same author and within 5 minutes
                      bool isContinuation = false;
                      if (nextMessage != null && 
                          nextMessage.authorId == message.authorId &&
                          nextMessage.type != 'system') {
                        final diff = nextMessage.createdAt.difference(message.createdAt).abs();
                        if (diff.inMinutes < 5) {
                          isContinuation = true;
                        }
                      }

                      final currentUserId = ref.read(authNotifierProvider).maybeWhen(
                        authenticated: (user, _) => user.id,
                        orElse: () => '',
                      );

                      return EnhancedMessageItem(
                        message: message,
                        isContinuation: isContinuation,
                        onReactionToggle: (emoji) => ref
                            .read(chatNotifierProvider(widget.channelId).notifier)
                            .toggleReaction(message.id, emoji),
                        onLongPress: () => _onMessageLongPress(message),
                        onEdit: (newContent) => ref
                            .read(chatNotifierProvider(widget.channelId).notifier)
                            .editMessage(message.id, newContent),
                        onDelete: () => ref
                            .read(chatNotifierProvider(widget.channelId).notifier)
                            .deleteMessage(message.id),
                        onReply: () => setState(() => _replyTo = message),
                        onCopy: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard', style: GoogleFonts.inter()),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          if (chatState.typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${chatState.typingUsers.length} user${chatState.typingUsers.length > 1 ? 's are' : ' is'} typing...',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          EnhancedMessageInput(
            replyToName: _replyTo?.author?.displayName ?? _replyTo?.author?.username,
            onCancelReply: () => setState(() => _replyTo = null),
            onPollRequested: () {
              showPollCreatorModal(
                context, 
                channelId: widget.channelId, 
                serverId: widget.serverId,
              );
            },
            onSend: (content, {attachments, gifUrl, stickerUrl}) {
              String messageContent = content;
              if (gifUrl != null) messageContent = gifUrl;
              if (stickerUrl != null) messageContent = stickerUrl;

              ref.read(chatNotifierProvider(widget.channelId).notifier).sendMessage(
                    messageContent,
                    replyToId: _replyTo?.id,
                    localAttachments: attachments,
                  );
              setState(() => _replyTo = null);
            },
            onTypingStart: () {
              ref.read(chatNotifierProvider(widget.channelId).notifier).sendTyping(true);
            },
            onTypingStop: () {
              ref.read(chatNotifierProvider(widget.channelId).notifier).sendTyping(false);
            },
          ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _particleController.dispose();
    super.dispose();
  }
}
