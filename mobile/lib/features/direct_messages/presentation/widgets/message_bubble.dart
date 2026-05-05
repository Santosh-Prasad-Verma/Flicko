import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final DMMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender?.name ?? 'Unknown';
    final avatarUrl = message.sender?.avatarUrl;
    final timeStr = DateFormat('h:mm a').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FlickoSpacing.md,
        vertical: FlickoSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            imageUrl: avatarUrl,
            name: senderName,
            size: 40,
            showStatus: false,
          ),
          const SizedBox(width: FlickoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        color: Color(FlickoColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: FlickoSpacing.sm),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FlickoSpacing.xs),
                if (message.content.isNotEmpty)
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Color(FlickoColors.textPrimary),
                        fontSize: 15,
                        height: 1.4,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(BuildContext context, DMAttachment attachment) {
    if (attachment.type.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: FlickoSpacing.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FlickoRadius.md),
          child: CachedNetworkImage(
            imageUrl: attachment.url,
            placeholder: (context, url) => Container(
              height: 200,
              width: 300,
              color: const Color(FlickoColors.bgTertiary),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    
    // Generic file attachment
    return Container(
      margin: const EdgeInsets.only(bottom: FlickoSpacing.sm),
      padding: const EdgeInsets.all(FlickoSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(FlickoRadius.md),
        border: Border.all(color: const Color(FlickoColors.bgTertiary)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Color(FlickoColors.textSecondary)),
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
}
