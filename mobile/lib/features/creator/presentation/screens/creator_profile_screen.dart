import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/creator_profile_notifier.dart';
import '../widgets/creator_post_card.dart';
import 'creator_thread_screen.dart';

class CreatorProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const CreatorProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(creatorProfileProvider(widget.userId).notifier).fetchMorePosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(creatorProfileProvider(widget.userId));
    final notifier = ref.read(creatorProfileProvider(widget.userId).notifier);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final isSelf = currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: _bg,
      body: profileState.isLoading && profileState.profile == null
          ? const Center(child: CircularProgressIndicator(color: _neon))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Custom beautiful header
                SliverAppBar(
                  expandedHeight: 120,
                  backgroundColor: _surface,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  title: Text(
                    profileState.profile?.displayName ?? profileState.profile?.username ?? 'Profile',
                    style: GoogleFonts.epilogue(
                      color: _white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                // Creator Header Details
                SliverToBoxAdapter(
                  child: _buildProfileHeader(profileState, notifier, isSelf),
                ),
                // Divider
                SliverToBoxAdapter(
                  child: Container(
                    height: 8,
                    color: Colors.black,
                  ),
                ),
                // Posts Title/Tab header
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _surface,
                      border: Border(
                        bottom: BorderSide(color: Colors.white10, width: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      'POSTS',
                      style: GoogleFonts.spaceMono(
                        color: _neon,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                // Posts Infinite scroll List
                if (profileState.posts.isEmpty && !profileState.isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No posts published yet.',
                        style: GoogleFonts.inter(color: _muted),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < profileState.posts.length) {
                          final post = profileState.posts[index];
                          return CreatorPostCard(
                            post: post,
                            profileUserIdContext: widget.userId,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CreatorThreadScreen(postId: post.id),
                                ),
                              );
                            },
                          );
                        } else if (profileState.isLoadMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(color: _neon),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                      childCount: profileState.posts.length + (profileState.hasMore ? 1 : 0),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(
    CreatorProfileState state,
    CreatorProfileNotifier notifier,
    bool isSelf,
  ) {
    if (state.profile == null) return const SizedBox.shrink();

    final profile = state.profile!;

    return Container(
      color: _surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _neon, width: 1.5),
                  image: profile.avatar != null && profile.avatar!.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(profile.avatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profile.avatar == null || profile.avatar!.isEmpty
                    ? const Center(
                        child: Icon(Icons.person, color: _neon, size: 36),
                      )
                    : null,
              ),
              const Spacer(),
              // Follow/Unfollow Button
              if (!isSelf)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: profile.isFollowing ? Colors.transparent : _neon,
                    side: BorderSide(color: profile.isFollowing ? Colors.white24 : _neon),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    notifier.toggleFollow().catchError((e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to update follow status: $e')),
                      );
                    });
                  },
                  child: Text(
                    profile.isFollowing ? 'FOLLOWING' : 'FOLLOW',
                    style: GoogleFonts.spaceMono(
                      color: profile.isFollowing ? _white : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // User Metadata
          Row(
            children: [
              Text(
                profile.displayName ?? profile.username,
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              if (profile.verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: _neon, size: 18),
              ],
            ],
          ),
          Text(
            '@${profile.username}',
            style: GoogleFonts.inter(color: _muted, fontSize: 14),
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              profile.bio!,
              style: GoogleFonts.inter(color: _white.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          // Statistics Counts
          Row(
            children: [
              _statLabel('${profile.postCount}', 'POSTS'),
              const SizedBox(width: 24),
              _statLabel('${profile.followerCount}', 'FOLLOWERS'),
              const SizedBox(width: 24),
              _statLabel('${profile.followingCount}', 'FOLLOWING'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statLabel(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
