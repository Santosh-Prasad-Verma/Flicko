import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/ai_assistant/translate/presentation/translated_text_panel.dart';
import 'package:mobile/features/shared/presentation/widgets/safe_network_media.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
// Note: MessageDripCard removed in favor of glass theme
import 'poll_message_card.dart';

/// Enhanced MessageItem with reply preview, inline editing, and edited indicator
///
/// Mirrors the React Native MessageItem component features.
class EnhancedMessageItem extends ConsumerStatefulWidget {
  final FlickoMessage message;
  final bool isContinuation;
  final Function(String emoji) onReactionToggle;
  final VoidCallback onLongPress;
  final Function(String newContent) onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onCopy;

  const EnhancedMessageItem({
    super.key,
    required this.message,
    required this.isContinuation,
    required this.onReactionToggle,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.onReply,
    required this.onCopy,
  });

  @override
  ConsumerState<EnhancedMessageItem> createState() => _EnhancedMessageItemState();
}

class _EnhancedMessageItemState extends ConsumerState<EnhancedMessageItem> {
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
      widget.onEdit(newContent);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Handle poll message
    if (widget.message.type == 'poll') {
      return PollMessageCard(message: widget.message);
    }

    // System messages
    if (widget.message.type != 'default' && widget.message.type != 'poll') {
      return _buildSystemMessage();
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        padding: EdgeInsets.only(
          top: widget.isContinuation ? 2 : 16,
          bottom: 2,
          left: 16,
          right: 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar column
            SizedBox(
              width: 40,
              child: widget.isContinuation
                  ? null
                  : UserAvatar(
                      imageUrl: widget.message.author?.avatarUrl,
                      size: 40,
                      status: widget.message.author?.onlineStatus ?? 'offline',
                    ),
            ),
            const SizedBox(width: 12),
            // Content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply preview if this message is a reply
                  if (widget.message.replyTo != null) _buildReplyPreview(),

                  // Author name and timestamp
                  if (!widget.isContinuation) _buildHeader(),

                  const SizedBox(height: 4),

                  // Message content or edit field
                   _isEditing ? _buildEditField() : _buildContent(),

                  // Optional translation panel. Renders nothing in idle state;
                  // auto-triggers when the user's behavior setting is `always`,
                  // otherwise waits for an explicit Translate action.
                  TranslatedTextPanel(
                    messageId: widget.message.id,
                    messageText: widget.message.content,
                    channelId: widget.message.channelId,
                  ),

                  // Attachments
                  if (widget.message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAttachments(),
                  ],

                  // Reactions
                  if (widget.message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildReactions(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    String text;
    IconData icon;
    Color color;

    switch (widget.message.type) {
      case 'join':
        text =
            '${widget.message.author?.displayName ?? widget.message.author?.username ?? "Someone"} joined the server';
        icon = Icons.person_add;
        color = const Color(FlickoColors.success);
      case 'leave':
        text =
            '${widget.message.author?.displayName ?? widget.message.author?.username ?? "Someone"} left the server';
        icon = Icons.person_remove;
        color = const Color(FlickoColors.textMuted);
      case 'boost':
        text =
            '${widget.message.author?.displayName ?? widget.message.author?.username ?? "Someone"} boosted the server!';
        icon = Icons.rocket_launch;
        color = const Color(FlickoColors.fuchsia);
      case 'pin':
        text =
            '${widget.message.author?.displayName ?? widget.message.author?.username ?? "Someone"} pinned a message';
        icon = Icons.push_pin;
        color = const Color(FlickoColors.warning);
      default:
        text = widget.message.content;
        icon = Icons.info;
        color = const Color(FlickoColors.textMuted);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    final replyTo = widget.message.replyTo!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: Color(int.tryParse(
                      replyTo.author?.accentColor?.replaceFirst('#', '0xFF') ??
                          '0xFF5865F2') ??
                  FlickoColors.blurple),
              width: 3,
            ),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
        ),
        child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 14,
            color: Color(int.tryParse(
                    replyTo.author?.accentColor?.replaceFirst('#', '0xFF') ??
                        '0xFF5865F2') ??
                FlickoColors.blurple),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTo.author?.displayName ??
                      replyTo.author?.username ??
                      'Unknown',
                  style: GoogleFonts.inter(
                    color: Color(int.tryParse(replyTo.author?.accentColor
                                ?.replaceFirst('#', '0xFF') ??
                            '0xFF5865F2') ??
                        FlickoColors.blurple),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  replyTo.content,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader() {
    final author = widget.message.author;
    final accentColor = Color(int.tryParse(
            author?.accentColor?.replaceFirst('#', '0xFF') ?? '0xFF5865F2') ??
        FlickoColors.blurple);

    return Row(
      children: [
        Text(
          author?.displayName ?? author?.username ?? 'Unknown',
          style: GoogleFonts.inter(
            color: accentColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTimestamp(widget.message.createdAt),
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 11,
          ),
        ),
        if (widget.message.edited) ...[
          const SizedBox(width: 4),
          Text(
            '(edited)',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent() {
    // Detect sticker URLs from Handy Emoji Panel CDN
    final trimmed = widget.message.content.trim();
    if (_isStickerUrl(trimmed)) {
      return CachedNetworkImage(
        imageUrl: trimmed,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: MarkdownBody(
            data: widget.message.content,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 15,
                height: 1.4,
              ),
              code: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 13,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              blockquote: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 15,
              ),
              a: GoogleFonts.inter(
                color: const Color(FlickoColors.blurple),
                fontSize: 15,
                decoration: TextDecoration.underline,
              ),
            ),
            onTapLink: (text, href, title) async {
              if (href != null) {
                final uri = Uri.parse(href);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  bool _isStickerUrl(String content) {
    return content.startsWith('https://raw.githubusercontent.com/SuhasDissa/Handy_emoji_panel/') ||
        (content.startsWith('https://') &&
         (content.endsWith('.png') || content.endsWith('.gif') || content.endsWith('.jpeg')) &&
         content.contains('Sticker'));
  }

  Widget _buildEditField() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          TextField(
            controller: _editController,
            maxLines: null,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Edit message',
              hintStyle: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
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
                  style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.blurple),
                  foregroundColor: Colors.white,
                ),
                child: Text('Save', style: GoogleFonts.inter()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    return Column(
      children: widget.message.attachments.map((attachment) {
        final isImage = attachment.contentType.startsWith('image/');

        if (isImage) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _ImageAttachmentWidget(attachment: attachment),
          );
        }

        // File attachment
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.insert_drive_file,
                color: Color(FlickoColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.filename,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatFileSize(attachment.size),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download,
                    color: Color(FlickoColors.blurple)),
                onPressed: () async {
                  final uri = Uri.parse(attachment.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReactions() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: widget.message.reactions.map((reaction) {
        final isMe = reaction.me;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onReactionToggle(reaction.emoji);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(FlickoColors.blurple).withValues(alpha: 0.3)
                  : const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgTertiary),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  reaction.count.toString(),
                  style: GoogleFonts.inter(
                    color: isMe
                        ? const Color(FlickoColors.blurple)
                        : const Color(FlickoColors.textSecondary),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ImageAttachmentWidget extends StatefulWidget {
  final FlickoAttachment attachment;

  const _ImageAttachmentWidget({required this.attachment});

  @override
  State<_ImageAttachmentWidget> createState() => _ImageAttachmentWidgetState();
}

class _ImageAttachmentWidgetState extends State<_ImageAttachmentWidget> {
  bool _isSpoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final isSpoiler = widget.attachment.filename.startsWith('SPOILER_');
    final showSpoiler = isSpoiler && !_isSpoilerRevealed;
    final hasAltText = widget.attachment.altText != null &&
        widget.attachment.altText!.trim().isNotEmpty;

    Widget image = SafeNetworkImage(
      imageUrl: widget.attachment.url,
      contentType: widget.attachment.contentType,
      fileName: widget.attachment.filename,
      width: 300,
      height: 200,
      fit: BoxFit.cover,
    );

    if (showSpoiler) {
      image = Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: image,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'SPOILER',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (showSpoiler) {
          setState(() => _isSpoilerRevealed = true);
        } else {
          // Future expansion: open full-screen image viewer
        }
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
          if (!showSpoiler && hasAltText)
            Positioned(
              bottom: 8,
              left: 8,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(FlickoColors.bgSecondary),
                      title: Text('ALT Text',
                          style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary))),
                      content: Text(
                        widget.attachment.altText!,
                        style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textSecondary)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close',
                              style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textMuted))),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ALT',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
