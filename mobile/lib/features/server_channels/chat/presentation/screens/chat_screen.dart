import 'dart:ui';
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
import 'package:mobile/features/server/presentation/server_members_screen.dart';

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

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  FlickoMessage? _replyTo;
  late final AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scrollController.addListener(_onScroll);
    
    // Initial animation trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listController.forward();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatNotifierProvider(widget.channelId).notifier).fetchMore();
    }
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider(widget.channelId));

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: const Color(FlickoColors.bgPrimary).withValues(alpha: 0.7),
              elevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  const Icon(Icons.tag, color: Color(FlickoColors.blurpleLight), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.channelName ?? 'Channel',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.people_outline, color: Color(FlickoColors.textMuted), size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServerMembersScreen(serverId: widget.serverId),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1F22),
              Color(FlickoColors.bgTertiary),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: chatState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                      ),
                      itemCount: chatState.messages.length + (chatState.isFetchingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatState.messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple))),
                          );
                        }

                        final message = chatState.messages[index];
                        final nextMessage = index > 0 ? chatState.messages[index - 1] : null;

                        bool isContinuation = false;
                        if (nextMessage != null && 
                            nextMessage.authorId == message.authorId &&
                            nextMessage.type != 'system') {
                          final diff = nextMessage.createdAt.difference(message.createdAt).abs();
                          if (diff.inMinutes < 5) {
                            isContinuation = true;
                          }
                        }

                        // Staggered animation
                        // Since it's reversed, index 0 is at bottom
                        final animation = CurvedAnimation(
                          parent: _listController,
                          curve: Interval(
                            (index / 15).clamp(0.0, 1.0),
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        );

                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: animation.value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - animation.value)),
                                child: child,
                              ),
                            );
                          },
                          child: EnhancedMessageItem(
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
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (chatState.typingUsers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: const Color(FlickoColors.textMuted).withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${chatState.typingUsers.length} user${chatState.typingUsers.length > 1 ? 's are' : ' is'} typing...',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 4,
                left: 8,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgPrimary).withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: EnhancedMessageInput(
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }
}
