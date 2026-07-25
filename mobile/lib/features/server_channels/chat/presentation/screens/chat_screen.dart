import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/ai_assistant/summary/presentation/catch_me_up_pill.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/server_channels/chat/application/chat_notifier.dart';
import 'package:mobile/features/server_channels/chat/application/chat_state.dart';
import 'package:mobile/features/server_channels/chat/application/scroll_to_message.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_item.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/message_actions.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_input.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/pinned_messages_sheet.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/poll_creator_modal.dart';

import 'package:mobile/core/widgets/particle_fx_engine.dart';
import 'package:mobile/features/store/data/warp_service.dart';
import 'package:mobile/features/shared/presentation/widgets/entrance_warp_overlay.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';
import 'package:mobile/features/channel_backgrounds/application/channel_background_provider.dart';
import 'package:mobile/features/channel_backgrounds/presentation/channel_background_customizer_dialog.dart';

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
  String? _editingMessageId;
  int _lastMessageCount = 0;
  bool _showEntranceWarp = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

  /// Best-effort scroll to a cited message. The list is `reverse: true` so
  /// the newest item lives at offset 0; we estimate height (96 px) per row
  /// and animate. If the message hasn't been paged in yet we surface a
  /// transient snackbar — paging-on-demand is a follow-up.
  void _jumpToMessage(String messageId) {
    final state = ref.read(chatNotifierProvider(widget.channelId));
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message not loaded yet — keep scrolling up.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_scrollController.hasClients) return;
    const estimatedRowHeight = 96.0;
    final target = (idx * estimatedRowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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
      onEdit: () => setState(() => _editingMessageId = message.id),
      onPin: () => ref
          .read(chatNotifierProvider(widget.channelId).notifier)
          .togglePinMessage(message.id, !message.pinned),
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
    // React to scroll-to-message requests issued by the AI summary citation
    // peek. The chat screen owns the ScrollController, so it has to do the
    // actual scroll. We consume the intent so we don't loop on rebuilds.
    ref.listen<ScrollToMessageIntent?>(scrollToMessageProvider, (prev, next) {
      if (next == null) return;
      if (next.channelId != widget.channelId) return;
      _jumpToMessage(next.messageId);
      ref.read(scrollToMessageProvider.notifier).consume();
    });
    ref.listen<ChatState>(chatNotifierProvider(widget.channelId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
    final chatState = ref.watch(chatNotifierProvider(widget.channelId));
    final equippedWarp = ref.watch(equippedWarpProvider).value;
    final bgState = ref.watch(channelBackgroundProvider(widget.channelId));
    final overrideState = ref.watch(channelBackgroundOverrideProvider(widget.channelId));

    final bg = bgState.value;
    final userOverride = overrideState.value;
    final opacity = userOverride?.enabled == true ? userOverride!.opacity : 0.3;
    final bgEnabled = userOverride?.enabled ?? true;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030504), // Extremely dark near black with a lime tint
            Color(0xFF090E0C), // Slightly lighter obsidian green
            Color(0xFF020302), // Deep pitch black
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          if (bg != null && bgEnabled)
            Positioned.fill(
              child: Opacity(
                opacity: opacity,
                child: Builder(
                  builder: (context) {
                    final path = bg.fileIdMobile ?? bg.fileIdOriginal;
                    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
                    return Image(
                      image: isNetwork
                          ? NetworkImage(path)
                          : FileImage(File(path)) as ImageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    );
                  },
                ),
              ),
            ),
          Scaffold(
            backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
          titleSpacing: 0,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search channel messages...',
                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
                    border: InputBorder.none,
                  ),
                )
              : Row(
                  children: [
                    const Icon(Icons.tag, color: Color(FlickoColors.brandLime), size: 20),
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
              icon: Icon(
                _isSearching ? Icons.close : Icons.search_rounded,
                color: const Color(FlickoColors.brandLime),
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.push_pin_outlined, color: Color(FlickoColors.brandLime)),
              onPressed: () {
                final pinned = chatState.messages.where((m) => m.pinned).toList();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (ctx) => PinnedMessagesSheet(
                    pinnedMessages: pinned,
                    onJumpToMessage: (msg) => _jumpToMessage(msg.id),
                    onUnpinMessage: (msg) {
                      ref
                          .read(chatNotifierProvider(widget.channelId).notifier)
                          .togglePinMessage(msg.id, false);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Color(FlickoColors.brandLime)),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.65),
                  builder: (ctx) => ChannelBackgroundCustomizerDialog(
                    channelId: widget.channelId,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.people_outline, color: Color(FlickoColors.brandLime)),
              onPressed: () => context.push('/server/${widget.serverId}/members'),
            ),
          ],
        ),
        body: Stack(
        children: [
          ParticleFxEngine(
            controller: _particleController,
            child: Column(
              children: [
                CatchMeUpPill(
                  channelId: widget.channelId,
                  serverId: widget.serverId,
                ),
                Expanded(
                  child: chatState.isLoading
                      ? const MessageListSkeleton(count: 6)
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

                            final filteredMessages = _isSearching && _searchController.text.trim().isNotEmpty
                                ? chatState.messages.where((m) => m.content.toLowerCase().contains(_searchController.text.trim().toLowerCase()) || m.authorName.toLowerCase().contains(_searchController.text.trim().toLowerCase())).toList()
                                : chatState.messages;

                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true, // Discord style lists newest at bottom
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: filteredMessages.length + (chatState.isFetchingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filteredMessages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }

                                final message = filteredMessages[index];
                                final nextMessage = index > 0 ? filteredMessages[index - 1] : null;

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

                                return EnhancedMessageItem(
                                  message: message,
                                  isContinuation: isContinuation,
                                  onReactionToggle: (emoji) => ref
                                      .read(chatNotifierProvider(widget.channelId).notifier)
                                      .toggleReaction(message.id, emoji),
                                  onLongPress: () => _onMessageLongPress(message),
                                  onEdit: (newContent) {
                                    ref
                                        .read(chatNotifierProvider(widget.channelId).notifier)
                                        .editMessage(message.id, newContent);
                                    setState(() => _editingMessageId = null);
                                  },
                                  onEditCancel: () => setState(() => _editingMessageId = null),
                                  isEditing: _editingMessageId == message.id,
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
                      '${chatState.typingUsers.length} user${chatState.typingUsers.length > 1 ? "s are" : " is"} typing...',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              EnhancedMessageInput(
                serverId: widget.serverId,
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
                    serverId: widget.serverId,
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
          if (_showEntranceWarp && equippedWarp != null)
            EntranceWarpOverlay(
              warpId: equippedWarp.id,
              onComplete: () {
                setState(() {
                  _showEntranceWarp = false;
                });
              },
            ),
        ],
      ),
      ),
      ],
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
