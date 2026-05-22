import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/creator_feed_notifier.dart';
import '../state/creator_profile_notifier.dart';
import '../state/creator_thread_notifier.dart';
import '../screens/creator_profile_screen.dart';
import '../../data/models/creator_post.dart';

class CreatorPostCard extends ConsumerWidget {
  final CreatorPost post;
  final bool isDetailView;
  final VoidCallback? onTap;
  final String? profileUserIdContext; // If viewed inside a specific profile, to trigger profile updates
  final String? threadIdContext; // If viewed inside a thread, to trigger thread updates

  const CreatorPostCard({
    super.key,
    required this.post,
    this.isDetailView = false,
    this.onTap,
    this.profileUserIdContext,
    this.threadIdContext,
  });

  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);
  static const _likedColor = Color(0xFFFF6B6B);
  static const _repostedColor = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = post.postType == 'video';
    final isQnA = post.postType == 'qna';

    final timeStr = _formatTime(post.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(
            color: isQnA
                ? _neon.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            width: isQnA ? 1.5 : 1.0,
          ),
          boxShadow: isQnA
              ? [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.03),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context, post.userId),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isQnA ? _neon : Colors.transparent,
                        width: 1.5,
                      ),
                      image: post.avatar != null && post.avatar!.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(post.avatar!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: post.avatar == null || post.avatar!.isEmpty
                        ? const Center(
                            child: Icon(Icons.person, color: _neon, size: 24),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(context, post.userId),
                        child: Row(
                          children: [
                            Text(
                              post.displayName ?? post.username,
                              style: GoogleFonts.spaceGrotesk(
                                color: _white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            if (post.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: _neon, size: 14),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '@${post.username} • $timeStr',
                        style: GoogleFonts.inter(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Custom Tags based on types
                if (isQnA)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.1),
                      border: Border.all(color: _neon.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Q&A',
                      style: GoogleFonts.spaceMono(
                        color: _neon,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else if (post.acceptedAnswerId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'SOLVED',
                      style: GoogleFonts.spaceMono(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Title for Q&A / Discussions
            if (post.title != null && post.title!.isNotEmpty) ...[
              Text(
                post.title!,
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Content
            Text(
              post.content,
              style: GoogleFonts.inter(
                color: _white.withValues(alpha: 0.9),
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
            // Media Attachments
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: const Color(0xFF111113),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: post.mediaUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: _neon),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: _muted, size: 36),
                          ),
                        ),
                        if (isVideo)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: _white,
                                size: 32,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Engagement Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionButton(
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe ? _likedColor : _muted,
                  activeColor: _likedColor,
                  label: '${post.likeCount}',
                  onTap: () => _handleLike(ref),
                ),
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: _muted,
                  activeColor: _neon,
                  label: '${post.replyCount}',
                  onTap: onTap ?? () {},
                ),
                _actionButton(
                  icon: post.repostedByMe ? Icons.repeat : Icons.repeat_rounded,
                  color: post.repostedByMe ? _repostedColor : _muted,
                  activeColor: _repostedColor,
                  label: '${post.repostCount}',
                  onTap: () => _handleRepost(ref),
                ),
                _actionButton(
                  icon: Icons.share_outlined,
                  color: _muted,
                  activeColor: _neon,
                  label: '',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color activeColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            if (label.isNotEmpty && label != '0') ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: color == _muted ? _muted : activeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleLike(WidgetRef ref) {
    if (threadIdContext != null) {
      ref.read(creatorThreadProvider(threadIdContext!).notifier).toggleLike(post.id);
    } else if (profileUserIdContext != null) {
      ref.read(creatorProfileProvider(profileUserIdContext!).notifier).toggleLike(post.id);
    } else {
      ref.read(creatorFeedProvider.notifier).toggleLike(post.id);
    }
  }

  void _handleRepost(WidgetRef ref) {
    if (threadIdContext != null) {
      ref.read(creatorThreadProvider(threadIdContext!).notifier).toggleRepost(post.id);
    } else if (profileUserIdContext != null) {
      ref.read(creatorProfileProvider(profileUserIdContext!).notifier).toggleRepost(post.id);
    } else {
      ref.read(creatorFeedProvider.notifier).toggleRepost(post.id);
    }
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatorProfileScreen(userId: userId),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }
}


