import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/shared/presentation/widgets/safe_network_media.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class MessageItem extends StatelessWidget {
  final FlickoMessage message;
  final bool isContinuation;
  final Function(FlickoMessage)? onReply;
  final Function()? onLongPress;
  final Function(String)? onReactionToggle;

  const MessageItem({
    super.key,
    required this.message,
    this.isContinuation = false,
    this.onReply,
    this.onLongPress,
    this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == 'system') {
      return _buildSystemMessage(context);
    }

    if (isContinuation) {
      return _buildContinuationMessage(context);
    }

    return _buildFullMessage(context);
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildFullMessage(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              imageUrl: message.author?.avatarUrl,
              name: message.author?.displayName ??
                  message.author?.username ??
                  '?',
              size: 40,
              status: _mapStatus(message.author?.onlineStatus),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 4),
                  _buildContent(context),
                  if (message.attachments.isNotEmpty)
                    _buildAttachments(context),
                  if (message.reactions.isNotEmpty) _buildReactions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinuationMessage(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(
            left: 72.0, right: 16.0, top: 2.0, bottom: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContent(context),
            if (message.attachments.isNotEmpty) _buildAttachments(context),
            if (message.reactions.isNotEmpty) _buildReactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.createdAt);
    final authorName =
        message.author?.displayName ?? message.author?.username ?? 'Unknown';
    final roleColor = message.author?.accentColor != null
        ? Color(
            int.parse(message.author!.accentColor!.replaceFirst('#', '0xFF')))
        : const Color(FlickoColors.textPrimary);

    return Row(
      children: [
        Text(
          authorName,
          style: GoogleFonts.inter(
            color: roleColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeStr,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.content.isEmpty) return const SizedBox.shrink();

    // Detect sticker URLs from Handy Emoji Panel CDN
    final trimmed = message.content.trim();
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

    return MarkdownBody(
      data: message.content,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 15,
          height: 1.4,
        ),
        code: GoogleFonts.firaCode(
          backgroundColor: const Color(FlickoColors.bgTertiary),
          color: const Color(FlickoColors.textPrimary),
          fontSize: 13,
        ),
        blockquote: GoogleFonts.inter(
          color: const Color(FlickoColors.textSecondary),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
                color: const Color(FlickoColors.textMuted), width: 3),
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

  Widget _buildAttachments(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.attachments.map((a) {
          if (a.contentType.startsWith('image/')) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SafeNetworkImage(
                  imageUrl: a.url,
                  contentType: a.contentType,
                  fileName: a.filename,
                  fit: BoxFit.contain,
                ),
              ),
            );
          }
          // Generic file attachment
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file,
                    color: Color(FlickoColors.textMuted)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.filename,
                      style: GoogleFonts.inter(
                          color: const Color(FlickoColors.blurpleLight),
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${(a.size / 1024).toStringAsFixed(1)} KB',
                      style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.download,
                      color: Color(FlickoColors.textMuted)),
                  onPressed: () => launchUrl(Uri.parse(a.url)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: message.reactions.map((r) {
          return GestureDetector(
            onTap: () => onReactionToggle?.call(r.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: r.me
                    ? const Color(FlickoColors.blurple).withValues(alpha: 0.2)
                    : const Color(FlickoColors.bgTertiary),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: r.me
                      ? const Color(FlickoColors.blurple)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${r.count}',
                    style: GoogleFonts.inter(
                      color: r.me
                          ? const Color(FlickoColors.blurpleLight)
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
      ),
    );
  }

  UserStatus _mapStatus(String? status) {
    switch (status) {
      case 'online':
        return UserStatus.online;
      case 'idle':
        return UserStatus.idle;
      case 'dnd':
        return UserStatus.dnd;
      default:
        return UserStatus.offline;
    }
  }
}
