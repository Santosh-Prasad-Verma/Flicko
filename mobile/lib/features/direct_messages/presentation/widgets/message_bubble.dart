import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/kinetic_nameplate_text.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mobile/features/shared/presentation/widgets/safe_network_media.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/shared/presentation/widgets/message_drip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/message_actions.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_chat_controller.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final DMMessage message;
  final VoidCallback? onTapProfile;

  const MessageBubble({
    super.key,
    required this.message,
    this.onTapProfile,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editController.text = widget.message.content;
    });
  }

  void _saveEdit() {
    final newContent = _editController.text.trim();
    if (newContent.isNotEmpty && newContent != widget.message.content) {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      final otherUserId = widget.message.senderId == myUserId
          ? widget.message.recipientId
          : widget.message.senderId;

      ref
          .read(dmChatControllerProvider(otherUserId).notifier)
          .editMessage(widget.message.id, newContent);
    }
    setState(() => _isEditing = false);
  }

  void _toggleReaction(String emoji) {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    final otherUserId = widget.message.senderId == myUserId
        ? widget.message.recipientId
        : widget.message.senderId;

    ref
        .read(dmChatControllerProvider(otherUserId).notifier)
        .toggleReaction(widget.message.id, emoji);
  }

  void _deleteMessage() {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    final otherUserId = widget.message.senderId == myUserId
        ? widget.message.recipientId
        : widget.message.senderId;

    ref
        .read(dmChatControllerProvider(otherUserId).notifier)
        .deleteMessage(widget.message.id);
  }

  void _showMessageActions() {
    final myUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // Convert DMMessage to FlickoMessage for MessageActions
    final flickoMsg = FlickoMessage(
      id: widget.message.id,
      authorId: widget.message.senderId,
      content: widget.message.content,
      type: 'default',
      createdAt: widget.message.createdAt,
      reactions: widget.message.reactions,
      edited: widget.message.editedAt != null,
      editedAt: widget.message.editedAt,
    );

    context.showMessageActions(
      message: flickoMsg,
      currentUserId: myUserId,
      onReaction: (emoji) => _toggleReaction(emoji),
      onReply: () {},
      onEdit: () {
        setState(() {
          _isEditing = true;
          _editController.text = widget.message.content;
        });
      },
      onDelete: () => _deleteMessage(),
      onCopy: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final senderName =
        message.sender?.displayName ?? message.sender?.username ?? 'Unknown';
    final avatarUrl = message.sender?.avatarUrl;
    final timeStr = DateFormat('h:mm a').format(message.createdAt);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMine = message.senderId == currentUserId;
    final bubbleColor = isMine
        ? const Color(FlickoColors.bgSecondary)
        : const Color(FlickoColors.bgTertiary);
    final borderColor = isMine
        ? const Color(FlickoColors.emeraldGreen)
        : const Color(FlickoColors.border);

    return GestureDetector(
      onLongPress: _showMessageActions,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FlickoSpacing.md,
          vertical: FlickoSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              GestureDetector(
                onTap: widget.onTapProfile,
                behavior: HitTestBehavior.opaque,
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  name: senderName,
                  size: 38,
                  showStatus: false,
                ),
              ),
              const SizedBox(width: FlickoSpacing.md),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    GestureDetector(
                      onTap: widget.onTapProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: KineticNameplateText(
                          text: senderName.toUpperCase(),
                          userId: message.senderId,
                          style: const TextStyle(
                            color: Color(FlickoColors.emeraldGreen),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  MessageDripCard(
                    authorId: message.senderId,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: FlickoSpacing.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: isMine
                            ? const [
                                BoxShadow(
                                  color: Color(FlickoColors.emeraldGreen),
                                  blurRadius: 0,
                                  offset: Offset(4, 4),
                                )
                              ]
                            : null,
                      ),
                      child: _isEditing ? _buildEditField() : _buildContent(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(FlickoColors.textMuted),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEditing,
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saveEdit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.emeraldGreen),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    final message = widget.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          _isStickerUrl(message.content)
              ? _buildStickerContent(message.content)
              : _isGifUrl(message.content)
                  ? _buildGifContent(message.content)
                  : MarkdownBody(
                      data: message.editedAt != null
                          ? '${message.content} *(edited)*'
                          : message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Color(FlickoColors.textPrimary),
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
        if (message.attachments != null && message.attachments!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FlickoSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: message.attachments!.map((attachment) {
                return _buildAttachment(context, attachment);
              }).toList(),
            ),
          ),
        if (message.reactions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildReactions(),
        ],
      ],
    );
  }

  Widget _buildAttachment(BuildContext context, DMAttachment attachment) {
    if (attachment.type.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: FlickoSpacing.sm),
        child: GestureDetector(
          onTap: () => _openFullScreenImage(context, attachment.url, attachment.name),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FlickoRadius.md),
            child: SafeNetworkImage(
              imageUrl: attachment.url,
              contentType: attachment.type,
              fileName: attachment.name,
              width: 300,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    // Generic file attachment
    return Container(
      margin: const EdgeInsets.only(bottom: FlickoSpacing.sm),
      padding: const EdgeInsets.all(FlickoSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        border:
            Border.all(color: const Color(FlickoColors.emeraldGreen), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file,
              color: Color(FlickoColors.textSecondary)),
          const SizedBox(width: FlickoSpacing.sm),
          Flexible(
            child: Text(
              attachment.name ?? 'File',
              style: const TextStyle(color: Color(FlickoColors.textPrimary)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Check if the message content is a sticker URL from Handy Emoji Panel CDN
  bool _isStickerUrl(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('https://raw.githubusercontent.com/SuhasDissa/Handy_emoji_panel/') ||
        (trimmed.startsWith('https://') && 
         (trimmed.endsWith('.png') || trimmed.endsWith('.gif') || trimmed.endsWith('.jpeg')) &&
         trimmed.contains('Sticker'));
  }

  /// Render a sticker URL as an inline cached network image
  Widget _buildStickerContent(String url) {
    return CachedNetworkImage(
      imageUrl: url.trim(),
      width: 160,
      height: 160,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image_outlined,
        color: Color(FlickoColors.textMuted),
        size: 48,
      ),
    );
  }

  /// Check if the message content is a GIF URL (GIPHY, Tenor, or .gif)
  bool _isGifUrl(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('https://')) return false;
    return trimmed.contains('giphy.com') ||
        trimmed.contains('tenor.com') ||
        trimmed.contains('media.giphy.com') ||
        Uri.tryParse(trimmed)?.path.endsWith('.gif') == true;
  }

  /// Render a GIF URL as an inline cached network image
  Widget _buildGifContent(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url.trim(),
        width: 280,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 280,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgTertiary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF52B788)),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 280,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgTertiary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gif_box_rounded,
                  color: Color(FlickoColors.textMuted), size: 40),
              SizedBox(height: 8),
              Text('Failed to load GIF',
                  style: TextStyle(
                      color: Color(FlickoColors.textMuted), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  /// Open an image in a fullscreen interactive viewer
  void _openFullScreenImage(
      BuildContext context, String url, String? name) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) =>
          _FullScreenImageViewer(imageUrl: url, fileName: name),
    );
  }

  Widget _buildReactions() {
    final myUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.message.reactions.map((reaction) {
        final hasReacted = reaction.users.contains(myUserId);
        
        return GestureDetector(
          onTap: () => _toggleReaction(reaction.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasReacted
                  ? const Color(FlickoColors.blurple).withValues(alpha: 0.3)
                  : const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasReacted
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgTertiary),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
                if (reaction.count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${reaction.count}',
                    style: GoogleFonts.inter(
                      color: hasReacted
                          ? const Color(FlickoColors.textPrimary)
                          : const Color(FlickoColors.textSecondary),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? fileName;
  const _FullScreenImageViewer({required this.imageUrl, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          fileName ?? 'Image',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF52B788)),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
