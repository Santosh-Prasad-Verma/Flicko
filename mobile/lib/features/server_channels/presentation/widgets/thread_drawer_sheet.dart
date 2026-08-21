import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Message Thread Drawer Sheet
/// Displays a parent message and a real-time thread discussion feed.
class ThreadDrawerSheet extends ConsumerStatefulWidget {
  final String channelId;
  final String parentMessageId;
  final String parentMessageContent;
  final String parentAuthorName;
  final String? parentAuthorAvatar;

  const ThreadDrawerSheet({
    super.key,
    required this.channelId,
    required this.parentMessageId,
    required this.parentMessageContent,
    required this.parentAuthorName,
    this.parentAuthorAvatar,
  });

  static void show(
    BuildContext context, {
    required String channelId,
    required String parentMessageId,
    required String parentMessageContent,
    required String parentAuthorName,
    String? parentAuthorAvatar,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ThreadDrawerSheet(
          channelId: channelId,
          parentMessageId: parentMessageId,
          parentMessageContent: parentMessageContent,
          parentAuthorName: parentAuthorName,
          parentAuthorAvatar: parentAuthorAvatar,
        ),
      ),
    );
  }

  @override
  ConsumerState<ThreadDrawerSheet> createState() => _ThreadDrawerSheetState();
}

class _ThreadDrawerSheetState extends ConsumerState<ThreadDrawerSheet> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;
  List<Map<String, dynamic>> _threadMessages = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadThreadMessages();
    _subscribeToThread();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadThreadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*, user:profiles!user_id(username, display_name, avatar)')
          .eq('channel_id', widget.channelId)
          .or('thread_id.eq.${widget.parentMessageId},reply_to_id.eq.${widget.parentMessageId}')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _threadMessages = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (_) {}
  }

  void _subscribeToThread() {
    _subscription = Supabase.instance.client
        .channel('public:messages:thread_${widget.parentMessageId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: widget.channelId,
          ),
          callback: (payload) {
            _loadThreadMessages();
          },
        )
        ..subscribe();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _replyController.clear();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('messages').insert({
        'channel_id': widget.channelId,
        'user_id': userId,
        'content': text,
        'reply_to_id': widget.parentMessageId,
        'thread_id': widget.parentMessageId,
      });

      await _loadThreadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reply: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, color: Color(FlickoColors.brandLime), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Thread Discussion',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),

          // Parent Message Container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(FlickoColors.bgPrimary),
                  backgroundImage: widget.parentAuthorAvatar != null
                      ? NetworkImage(widget.parentAuthorAvatar!)
                      : null,
                  child: widget.parentAuthorAvatar == null
                      ? Text(widget.parentAuthorName[0].toUpperCase(),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.parentAuthorName,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.brandLime),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.parentMessageContent,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Thread Replies Feed
          Expanded(
            child: _threadMessages.isEmpty
                ? Center(
                    child: Text(
                      'No thread replies yet. Start the conversation!',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _threadMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _threadMessages[index];
                      final user = msg['user'] as Map<String, dynamic>?;
                      final author = user?['display_name'] ?? user?['username'] ?? 'User';
                      final avatar = user?['avatar'] as String?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(FlickoColors.bgTertiary),
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null
                                  ? Text(author[0].toUpperCase(),
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg['content'] as String? ?? '',
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(FlickoColors.bgPrimary),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Reply in thread...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                        filled: true,
                        fillColor: const Color(FlickoColors.bgSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.brandLime)))
                        : const Icon(Icons.send_rounded, color: Color(FlickoColors.brandLime)),
                    onPressed: _sendReply,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
