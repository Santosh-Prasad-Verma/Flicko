import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/creator_thread_notifier.dart';
import '../widgets/creator_post_card.dart';
import '../../data/models/creator_post.dart';

class CreatorThreadScreen extends ConsumerStatefulWidget {
  final String postId;

  const CreatorThreadScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<CreatorThreadScreen> createState() => _CreatorThreadScreenState();
}

class _CreatorThreadScreenState extends ConsumerState<CreatorThreadScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitReply(String parentId) async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(creatorThreadProvider(widget.postId).notifier).submitReply(
            content: text,
            parentId: parentId,
          );
      _inputController.clear();
      _focusNode.unfocus();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to post reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadState = ref.watch(creatorThreadProvider(widget.postId));
    final notifier = ref.read(creatorThreadProvider(widget.postId).notifier);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(
          threadState.rootPost?.postType == 'qna' ? 'Question & Answers' : 'Thread',
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: Column(
        children: [
          // Post and replies list
          Expanded(
            child: threadState.isLoadingRoot
                ? const Center(child: CircularProgressIndicator(color: _neon))
                : _buildThreadList(threadState, notifier, currentUserId),
          ),
          // Reply input field
          _buildInputBar(threadState.rootPost?.id ?? widget.postId),
        ],
      ),
    );
  }

  Widget _buildThreadList(
    CreatorThreadState state,
    CreatorThreadNotifier notifier,
    String? currentUserId,
  ) {
    if (state.rootPost == null) {
      return Center(
        child: Text(
          'Post not found',
          style: GoogleFonts.inter(color: _muted),
        ),
      );
    }

    final rootPost = state.rootPost!;
    final directReplies = state.replies[rootPost.id] ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Root Post
        CreatorPostCard(
          post: rootPost,
          isDetailView: true,
          threadIdContext: rootPost.id,
        ),

        const Divider(color: Colors.white10, height: 1),

        // Replies section header
        if (directReplies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              rootPost.postType == 'qna' ? 'ANSWERS' : 'REPLIES',
              style: GoogleFonts.spaceMono(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],

        // Nested Replies Tree structure (Indented and capped at 2 depths max)
        for (final reply1 in directReplies) ...[
          _buildReplyNode(reply1, 1, state, notifier, currentUserId),
        ],
      ],
    );
  }

  Widget _buildReplyNode(
    CreatorPost post,
    int depth, // Depth 1 or 2
    CreatorThreadState state,
    CreatorThreadNotifier notifier,
    String? currentUserId,
  ) {
    final repliesToThis = state.replies[post.id];
    final isLoadingSub = state.loadingReplyIds.contains(post.id);
    final hasAnswers = post.replyCount > 0;

    final double indent = depth == 1 ? 16.0 : 32.0;

    final isQnA = state.rootPost?.postType == 'qna';
    final isAccepted = state.rootPost?.acceptedAnswerId == post.id;
    final isRootAuthor = state.rootPost?.userId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply Card with precise indentation padding
        Padding(
          padding: EdgeInsets.only(left: indent, right: 12, top: 8, bottom: 4),
          child: Stack(
            children: [
              // Thread vertical line details for beautiful layout
              Positioned(
                left: -8,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1.5,
                  color: isAccepted ? _neon.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: isAccepted
                      ? Border.all(color: _neon.withValues(alpha: 0.4), width: 1.5)
                      : Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  color: isAccepted ? _neon.withValues(alpha: 0.02) : _surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CreatorPostCard(
                      post: post,
                      isDetailView: false,
                      threadIdContext: state.rootPost?.id ?? '',
                      onTap: () {
                        // Clicking deep thread reply navigates to its own screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CreatorThreadScreen(postId: post.id),
                          ),
                        );
                      },
                    ),
                    // Q&A / Accept Answer actions
                    if (isQnA)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                        child: Row(
                          children: [
                            if (isAccepted) ...[
                              const Icon(Icons.check_circle_rounded, color: _neon, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'ACCEPTED ANSWER',
                                style: GoogleFonts.spaceMono(
                                  color: _neon,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ] else if (isRootAuthor && state.rootPost?.acceptedAnswerId == null) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _neon, width: 1),
                                  foregroundColor: _neon,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: Text(
                                  'ACCEPT ANSWER',
                                  style: GoogleFonts.spaceMono(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                                onPressed: () {
                                  notifier.acceptAnswer(post.id);
                                },
                              ),
                            ],
                            const Spacer(),
                            // Quick Inline Reply Button
                            GestureDetector(
                              onTap: () {
                                _inputController.text = '@${post.username} ';
                                _focusNode.requestFocus();
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.reply_rounded, color: _muted, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'REPLY',
                                    style: GoogleFonts.spaceMono(
                                      color: _muted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _inputController.text = '@${post.username} ';
                                _focusNode.requestFocus();
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.reply_rounded, color: _muted, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'REPLY',
                                    style: GoogleFonts.spaceMono(
                                      color: _muted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Handle sub-replies at Depth 2
        if (repliesToThis != null) ...[
          for (final reply2 in repliesToThis) ...[
            _buildReplyNode(reply2, depth + 1, state, notifier, currentUserId),
          ],
        ] else if (hasAnswers) ...[
          // Show "progressive loading" option if replies exist but aren't fetched
          Padding(
            padding: EdgeInsets.only(left: indent + 16.0, top: 4, bottom: 8),
            child: isLoadingSub
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: _neon, strokeWidth: 1.5),
                  )
                : TextButton(
                    onPressed: () {
                      notifier.loadRepliesFor(post.id);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard_arrow_down_rounded, color: _neon, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'View ${post.replyCount} more replies',
                          style: GoogleFonts.spaceGrotesk(
                            color: _neon,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputBar(String activeParentId) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      maxLines: null,
                      style: GoogleFonts.inter(color: _white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Post a reply...',
                        hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send Button
          GestureDetector(
            onTap: _isSubmitting ? null : () => _submitReply(activeParentId),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _neon,
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
