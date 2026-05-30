import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/ai_assistant/translate/application/translate_provider.dart';
import 'package:mobile/features/ai_assistant/translate/application/translate_settings_provider.dart';
import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// Message Actions Bottom Sheet
///
/// Full-featured message actions menu with reply, edit, delete, reactions, copy, etc.
/// Mirrors the React Native MessageActions component.
class MessageActions extends ConsumerWidget {
  final FlickoMessage message;
  final String currentUserId;
  final Function(String emoji) onReaction;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onPin;
  final VoidCallback? onThread;
  final VoidCallback? onMarkUnread;
  final VoidCallback? onViewProfile;
  final VoidCallback? onMention;

  const MessageActions({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.onReaction,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    this.onPin,
    this.onThread,
    this.onMarkUnread,
    this.onViewProfile,
    this.onMention,
  });

  bool get _isMyMessage => message.authorId == currentUserId;
  bool get _canEdit => _isMyMessage && message.type == 'default';
  bool get _canDelete => _isMyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.textMuted),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Quick reactions row
            _buildQuickReactions(context),
            
            const Divider(color: Color(FlickoColors.bgTertiary), height: 1),
            
            // Main actions
            _buildAction(
              icon: Icons.reply,
              label: 'Reply',
              color: const Color(FlickoColors.textPrimary),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            
            if (message.threadId != null || onThread != null)
              _buildAction(
                icon: Icons.forum_outlined,
                label: message.threadId != null ? 'View Thread' : 'Create Thread',
                color: const Color(FlickoColors.textPrimary),
                onTap: () {
                  Navigator.pop(context);
                  onThread?.call();
                },
              ),
            
            _buildAction(
              icon: Icons.copy,
              label: 'Copy Text',
              color: const Color(FlickoColors.textPrimary),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                onCopy();
              },
            ),

            // Show the Translate menu item only when the user's auto-translate
            // behavior is `ask` or `always`. Hidden entirely on `never`.
            if (() {
              final s = ref.watch(translateUserSettingsProvider);
              final v = s.hasValue ? s.value : null;
              return v?.behavior != TranslateBehavior.never;
            }())
              _buildAction(
                icon: Icons.translate,
                label: AppLocalizations.of(context)?.translateAction ?? 'Translate',
                color: const Color(FlickoColors.textPrimary),
                onTap: () {
                  Navigator.pop(context);
                  final target = ref.read(translateTargetLangProvider);
                  ref
                      .read(translationProvider(TranslateKey(message.id)).notifier)
                      .translate(
                        text: message.content,
                        target: target,
                        channelId: message.channelId,
                      );
                },
              ),
            
            if (_canEdit)
              _buildAction(
                icon: Icons.edit,
                label: 'Edit Message',
                color: const Color(FlickoColors.textPrimary),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
            
            _buildAction(
              icon: Icons.push_pin_outlined,
              label: message.pinned ? 'Unpin Message' : 'Pin Message',
              color: const Color(FlickoColors.textPrimary),
              onTap: () {
                Navigator.pop(context);
                onPin?.call();
              },
            ),
            
            _buildAction(
              icon: Icons.mark_chat_unread_outlined,
              label: 'Mark Unread',
              color: const Color(FlickoColors.textPrimary),
              onTap: () {
                Navigator.pop(context);
                onMarkUnread?.call();
              },
            ),
            
            const Divider(color: Color(FlickoColors.bgTertiary), height: 1),
            
            // User actions
            if (message.authorId != currentUserId) ...[
              _buildAction(
                icon: Icons.person_outline,
                label: 'View Profile',
                color: const Color(FlickoColors.textPrimary),
                onTap: () {
                  Navigator.pop(context);
                  onViewProfile?.call();
                },
              ),
              _buildAction(
                icon: Icons.alternate_email,
                label: 'Mention User',
                color: const Color(FlickoColors.textPrimary),
                onTap: () {
                  Navigator.pop(context);
                  onMention?.call();
                },
              ),
              const Divider(color: Color(FlickoColors.bgTertiary), height: 1),
            ],
            
            // Danger zone
            if (_canDelete)
              _buildAction(
                icon: Icons.delete_outline,
                label: 'Delete Message',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReactions(BuildContext context) {
    final quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🎉'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickEmojis.map((emoji) {
          final isSelected = message.reactions.any(
            (r) => r.emoji == emoji && r.me,
          );
          
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onReaction(emoji);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(FlickoColors.blurple).withValues(alpha: 0.3)
                    : const Color(FlickoColors.bgTertiary),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: const Color(FlickoColors.blurple))
                    : null,
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Message',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}

/// Extension to show MessageActions as a bottom sheet
extension MessageActionsExtension on BuildContext {
  void showMessageActions({
    required FlickoMessage message,
    required String currentUserId,
    required Function(String emoji) onReaction,
    required VoidCallback onReply,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onCopy,
    VoidCallback? onPin,
    VoidCallback? onThread,
    VoidCallback? onMarkUnread,
    VoidCallback? onViewProfile,
    VoidCallback? onMention,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MessageActions(
        message: message,
        currentUserId: currentUserId,
        onReaction: onReaction,
        onReply: onReply,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onPin: onPin,
        onThread: onThread,
        onMarkUnread: onMarkUnread,
        onViewProfile: onViewProfile,
        onMention: onMention,
      ),
    );
  }
}
