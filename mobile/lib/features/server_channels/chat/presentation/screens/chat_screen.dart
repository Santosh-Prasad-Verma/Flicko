import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/server_channels/chat/application/chat_notifier.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/message_actions.dart';
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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showExtraControls = false;

  // Design tokens
  static const _bgPrimary = Color(0xFF000000);
  static const _bgCard = Color(0xFF0A0A0A);
  static const _bgSurface = Color(0xFF111111);
  static const _greenPunch = Color(0xFF10B981);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9CA3AF);
  static const _border = Color(0xFF1A1A1A);

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
      onReply: () {},
      onEdit: () {},
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

  void _sendMessage() {
    final content = _textController.text.trim();
    if (content.isNotEmpty) {
      ref.read(chatNotifierProvider(widget.channelId).notifier).sendMessage(content);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider(widget.channelId));

    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: _bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.tag, color: _greenPunch, size: 22),
            const SizedBox(width: 8),
            Text(
              (widget.channelName ?? 'channel').toLowerCase(),
              style: GoogleFonts.outfit(
                color: _textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _textSecondary),
            onPressed: () => context.push('/advanced-search', extra: {
              'serverId': widget.serverId,
              'channelId': widget.channelId,
            }),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, color: _textSecondary),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _border, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _greenPunch),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: chatState.messages.length + (chatState.isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _greenPunch)),
                        );
                      }

                      final message = chatState.messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          if (chatState.typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${chatState.typingUsers.length} user${chatState.typingUsers.length > 1 ? 's are' : ' is'} typing...',
                  style: GoogleFonts.outfit(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),

          // Extra controls row
          if (_showExtraControls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _bgSurface,
                border: Border(top: BorderSide(color: _border, width: 1)),
              ),
              child: Row(
                children: [
                  _buildInputAction(Icons.photo_library_outlined, 'Gallery', () {}),
                  _buildInputAction(Icons.camera_alt_outlined, 'Camera', () {}),
                  _buildInputAction(Icons.gif_box_outlined, 'GIFs', () {}),
                  _buildInputAction(Icons.poll_outlined, 'Poll', () {}),
                  _buildInputAction(Icons.attach_file, 'File', () {}),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: _bgPrimary,
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showExtraControls = !_showExtraControls),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showExtraControls ? _greenPunch : _bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Icon(
                      _showExtraControls ? Icons.close : Icons.add,
                      color: _showExtraControls ? Colors.black : _textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: GoogleFonts.outfit(color: _textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Message #${(widget.channelName ?? 'channel').toLowerCase()}',
                              hintStyle: GoogleFonts.outfit(color: _textSecondary, fontSize: 15),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.emoji_emotions_outlined, color: _textSecondary, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _greenPunch,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(FlickoMessage message) {
    bool isOutgoing = false;
    ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, profile) {
        if (user.id == message.authorId) isOutgoing = true;
      },
      orElse: () {},
    );

    final timeStr = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";
    final authorName = message.author?.displayName ?? message.author?.username ?? 'User';
    final authorAvatar = message.author?.avatarUrl;

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(message),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 12,
          left: isOutgoing ? 40 : 0,
          right: isOutgoing ? 0 : 40,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isOutgoing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 48),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/u/${message.authorId}'),
                      child: Text(
                        authorName,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _greenPunch,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(fontSize: 11, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isOutgoing) ...[
                  GestureDetector(
                    onTap: () => context.push('/u/${message.authorId}'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border, width: 1),
                        image: authorAvatar != null
                            ? DecorationImage(
                                image: NetworkImage(authorAvatar),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: authorAvatar == null
                          ? Center(
                              child: Text(
                                authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                                style: GoogleFonts.outfit(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOutgoing ? _greenPunch : _bgSurface,
                      border: Border.all(
                        color: isOutgoing ? _greenPunch : _border,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isOutgoing ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isOutgoing ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isOutgoing ? Colors.black : _textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isOutgoing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(timeStr, style: GoogleFonts.outfit(fontSize: 11, color: _textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1),
              ),
              child: Icon(icon, color: _textSecondary, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
