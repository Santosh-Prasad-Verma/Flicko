import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mobile/features/shared/presentation/widgets/safe_network_media.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageBubble extends StatelessWidget {
  final DMMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
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
        ? const Color(FlickoColors.brandLime)
        : const Color(FlickoColors.border);

    return Padding(
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
            UserAvatar(
              imageUrl: avatarUrl,
              name: senderName,
              size: 38,
              showStatus: false,
            ),
            const SizedBox(width: FlickoSpacing.md),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      senderName.toUpperCase(),
                      style: const TextStyle(
                        color: Color(FlickoColors.brandLime),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Container(
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
                              color: Color(FlickoColors.brandLime),
                              blurRadius: 0,
                              offset: Offset(4, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.isNotEmpty)
                        MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Color(FlickoColors.textPrimary),
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (message.attachments != null &&
                          message.attachments!.isNotEmpty)
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
    );
  }

  Widget _buildAttachment(BuildContext context, DMAttachment attachment) {
    if (attachment.type.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: FlickoSpacing.sm),
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
      );
    }

    // Generic file attachment
    return Container(
      margin: const EdgeInsets.only(bottom: FlickoSpacing.sm),
      padding: const EdgeInsets.all(FlickoSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        border:
            Border.all(color: const Color(FlickoColors.brandLime), width: 1.2),
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
}
