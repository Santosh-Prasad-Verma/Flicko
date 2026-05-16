import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// User mention suggestion data
class MentionUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? status;

  MentionUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.status,
  });

  String get name => displayName ?? username;
}

/// Mention Autocomplete Widget
///
/// Shows user suggestions when typing @ in the message input.
/// Mirrors the React Native MentionAutocomplete component.
class MentionAutocomplete extends StatelessWidget {
  final List<MentionUser> users;
  final String query;
  final Function(MentionUser user) onSelect;
  final VoidCallback onDismiss;

  const MentionAutocomplete({
    super.key,
    required this.users,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  /// Filters users based on the mention query
  List<MentionUser> get _filteredUsers {
    if (query.isEmpty) return users.take(10).toList();
    
    final lowerQuery = query.toLowerCase();
    return users.where((user) {
      return user.username.toLowerCase().contains(lowerQuery) ||
             (user.displayName?.toLowerCase().contains(lowerQuery) ?? false);
    }).take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgFloating),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(FlickoColors.bgTertiary),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Mentions',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(FlickoColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          
          // User list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final user = filtered[index];
                return _buildUserItem(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(MentionUser user) {
    return GestureDetector(
      onTap: () => onSelect(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(FlickoColors.bgTertiary).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: user.avatarUrl,
              size: 32,
              status: user.status ?? 'offline',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${user.username}',
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
}

/// Extension methods for mention handling
class MentionController extends TextEditingController {
  final List<MentionUser> availableUsers;
  Function(String query)? onMentionQueryChanged;
  VoidCallback? onMentionDismissed;

  MentionController({
    super.text,
    required this.availableUsers,
    this.onMentionQueryChanged,
    this.onMentionDismissed,
  });

  /// Checks if cursor is currently in a mention context (@...)
  MentionContext? get mentionContext {
    final text = this.text;
    final cursorPosition = selection.start;
    
    if (cursorPosition <= 0) return null;
    
    // Find the start of current word
    int wordStart = cursorPosition - 1;
    while (wordStart >= 0 && text[wordStart] != ' ' && text[wordStart] != '\n') {
      wordStart--;
    }
    wordStart++;
    
    // Check if word starts with @
    if (wordStart >= 0 && wordStart < text.length && text[wordStart] == '@') {
      final query = text.substring(wordStart + 1, cursorPosition);
      return MentionContext(
        query: query,
        startIndex: wordStart,
        endIndex: cursorPosition,
      );
    }
    
    return null;
  }

  /// Inserts a mention at the current cursor position
  void insertMention(MentionUser user) {
    final context = mentionContext;
    if (context == null) return;
    
    final mentionText = '@${user.username} ';
    final newText = text.substring(0, context.startIndex) + 
                    mentionText + 
                    text.substring(context.endIndex);
    
    text = newText;
    selection = TextSelection.collapsed(
      offset: context.startIndex + mentionText.length,
    );
    
    onMentionDismissed?.call();
  }

  @override
  set selection(TextSelection newSelection) {
    super.selection = newSelection;
    
    // Check for mention context and notify
    final context = mentionContext;
    if (context != null) {
      onMentionQueryChanged?.call(context.query);
    } else {
      onMentionDismissed?.call();
    }
  }
}

/// Data class for mention context
class MentionContext {
  final String query;
  final int startIndex;
  final int endIndex;

  MentionContext({
    required this.query,
    required this.startIndex,
    required this.endIndex,
  });
}
