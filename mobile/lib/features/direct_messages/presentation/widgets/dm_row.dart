import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DMRow extends StatelessWidget {
  final DMConversation conversation;
  final VoidCallback onTap;

  const DMRow({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = conversation.participant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: FlickoSpacing.md,
          vertical: 8,
        ),
        padding: const EdgeInsets.all(FlickoSpacing.md),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: conversation.unreadCount > 0
                ? const Color(FlickoColors.brandLime)
                : const Color(FlickoColors.border),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(FlickoColors.bgTertiary),
                  backgroundImage: user.avatarUrl != null
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person,
                          size: 20, color: Color(FlickoColors.textMuted))
                      : null,
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _getStatusColor(user.onlineStatus),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(FlickoColors.bgPrimary),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: FlickoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user.displayName ?? user.username,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(FlickoColors.textPrimary),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _formatTimestamp(conversation.lastMessageAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    conversation.lastMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: conversation.unreadCount > 0
                          ? const Color(FlickoColors.textPrimary)
                          : const Color(FlickoColors.textSecondary),
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.brandLime),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  conversation.unreadCount > 99
                      ? '99+'
                      : conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Color(FlickoColors.black),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return const Color(FlickoColors.statusOnline);
      case 'idle':
        return const Color(FlickoColors.statusIdle);
      case 'dnd':
        return const Color(FlickoColors.statusDnd);
      default:
        return const Color(FlickoColors.statusOffline);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == timestamp.year &&
        yesterday.month == timestamp.month &&
        yesterday.day == timestamp.day) {
      return 'Yesterday';
    }
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
