import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/flicko_card.dart';
import 'package:mobile/features/shared/presentation/widgets/safe_image.dart';

enum SortMode { latestActivity, creationDate }

class ForumTag {
  final String id;
  final String name;
  final String? emoji;
  final bool? moderated;

  ForumTag({
    required this.id,
    required this.name,
    this.emoji,
    this.moderated,
  });

  factory ForumTag.fromJson(Map<String, dynamic> json) {
    return ForumTag(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      moderated: json['moderated'] as bool?,
    );
  }
}

class ForumPostItem {
  final String id;
  final String name;
  final String creatorId;
  final int messageCount;
  final String? lastMessageAt;
  final String createdAt;
  final Map<String, dynamic>? creator;
  final List<ForumTag>? tags;
  final String? firstMessage;

  ForumPostItem({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.messageCount,
    this.lastMessageAt,
    required this.createdAt,
    this.creator,
    this.tags,
    this.firstMessage,
  });

  factory ForumPostItem.fromJson(Map<String, dynamic> json) {
    return ForumPostItem(
      id: json['id'] as String,
      name: json['name'] as String,
      creatorId: json['creator_id'] as String,
      messageCount: json['message_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] as String?,
      createdAt: json['created_at'] as String,
      creator: json['creator'] as Map<String, dynamic>?,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((t) => ForumTag.fromJson(t as Map<String, dynamic>))
          .toList(),
      firstMessage: json['first_message'] as String?,
    );
  }
}

class ForumChannelScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const ForumChannelScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<ForumChannelScreen> createState() => _ForumChannelScreenState();
}

class _ForumChannelScreenState extends ConsumerState<ForumChannelScreen> with TickerProviderStateMixin {
  SortMode _sort = SortMode.latestActivity;
  String? _filterTagId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<ForumPostItem> _posts = [];
  List<ForumTag> _tags = [];
  Map<String, dynamic>? _channel;
  int _currentPage = 1;

  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadData();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadChannel(),
      _loadTags(),
      _loadPosts(),
    ]);
    setState(() => _isLoading = false);
    _staggerController.forward(from: 0);
  }

  Future<void> _loadChannel() async {
    try {
      final response = await Supabase.instance.client
          .from('channels')
          .select('*')
          .eq('id', widget.channelId)
          .single();
      setState(() => _channel = response);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadTags() async {
    try {
      final response = await Supabase.instance.client
          .from('forum_tags')
          .select('*')
          .eq('channel_id', widget.channelId);
      setState(() => _tags = (response as List)
          .map((t) => ForumTag.fromJson(t as Map<String, dynamic>))
          .toList());
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadPosts({bool reset = true}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _posts = [];
      });
    }

    try {
      var query = Supabase.instance.client
          .from('threads')
          .select('*, creator:profiles(id, username, display_name, avatar_url), tags:forum_tags(*)')
          .eq('channel_id', widget.channelId);

      if (_filterTagId != null) {
        query = query.contains('tag_ids', [_filterTagId]);
      }

      final response = await query
          .order(_sort == SortMode.latestActivity ? 'last_message_at' : 'created_at',
              ascending: false)
          .range((_currentPage - 1) * 20, _currentPage * 20 - 1);

      final newPosts = (response as List)
          .map((p) => ForumPostItem.fromJson(p as Map<String, dynamic>))
          .toList();

      setState(() {
        if (reset) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _handlePostPress(ForumPostItem post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ThreadViewScreen(
          serverId: widget.serverId,
          channelId: widget.channelId,
          threadId: post.id,
        ),
      ),
    );
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(timestamp));
    final mins = diff.inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final hrs = diff.inHours;
    if (hrs < 24) return '${hrs}h ago';
    final days = diff.inDays;
    if (days < 7) return '${days}d ago';
    return '${days ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildGlassHeader(),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(FlickoColors.blurple),
              ),
            )
          : Stack(
              children: [
                // Background Gradient Glow
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.05),
                    ),
                  ),
                ),
                _buildPostList(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: Text(
          'Post',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(FlickoColors.blurple),
        elevation: 8,
      ),
    );
  }

  Widget _buildGlassHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.7),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, 
                      color: Color(FlickoColors.textPrimary), size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.forum_outlined, 
                      color: Color(FlickoColors.blurple), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _channel?['name'] ?? 'Forum',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      displacement: 100,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      color: const Color(FlickoColors.blurple),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
          SliverToBoxAdapter(child: _buildTopicAndFilters()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverSortBarDelegate(_buildSortBar()),
          ),
          if (_posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.speaker_notes_off_outlined,
                        size: 48,
                        color: Color(FlickoColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'This forum is quiet...',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to share something!',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      return _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(FlickoColors.blurple),
                                ),
                              ),
                            )
                          : const SizedBox(height: 40);
                    }

                    return AnimatedBuilder(
                      animation: _staggerController,
                      builder: (context, child) {
                        final delay = index * 0.05;
                        final double animValue = Curves.easeOutCubic.transform(
                          (_staggerController.value - delay).clamp(0.0, 1.0),
                        );
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - animValue)),
                          child: Opacity(
                            opacity: animValue,
                            child: child,
                          ),
                        );
                      },
                      child: _ForumPostCard(
                        post: _posts[index],
                        tags: _tags,
                        onPress: () => _handlePostPress(_posts[index]),
                        formatTimeAgo: _formatTimeAgo,
                      ),
                    );
                  },
                  childCount: _posts.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_channel?['topic'] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: FlickoCard(
              opacity: 0.05,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(FlickoColors.textSecondary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _channel!['topic'],
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tags.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildTagChip(
                      label: 'All',
                      isSelected: _filterTagId == null,
                      onTap: () {
                        setState(() => _filterTagId = null);
                        _loadPosts();
                      },
                    );
                  }
                  final tag = _tags[index - 1];
                  return _buildTagChip(
                    label: tag.name,
                    emoji: tag.emoji,
                    isSelected: _filterTagId == tag.id,
                    onTap: () {
                      setState(() {
                        _filterTagId = _filterTagId == tag.id ? null : tag.id;
                      });
                      _loadPosts();
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagChip({
    required String label,
    String? emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected ? const LinearGradient(colors: FlickoColors.blurpleGradient) : null,
              color: isSelected ? null : const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.transparent : const Color(FlickoColors.border),
                width: 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(FlickoColors.blurple).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(FlickoColors.textSecondary),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: const Color(FlickoColors.bgPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSortButton(
            label: 'Latest',
            isActive: _sort == SortMode.latestActivity,
            onTap: () {
              setState(() => _sort = SortMode.latestActivity);
              _loadPosts();
            },
          ),
          const SizedBox(width: 12),
          _buildSortButton(
            label: 'Newest',
            isActive: _sort == SortMode.creationDate,
            onTap: () {
              setState(() => _sort = SortMode.creationDate);
              _loadPosts();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(FlickoColors.bgSecondary) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ForumPostCard extends StatelessWidget {
  final ForumPostItem post;
  final List<ForumTag> tags;
  final VoidCallback onPress;
  final String Function(String?) formatTimeAgo;

  const _ForumPostCard({
    required this.post,
    required this.tags,
    required this.onPress,
    required this.formatTimeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final postTags = post.tags ?? [];
    final creatorName = post.creator?['display_name'] ?? post.creator?['username'] ?? 'Anonymous';
    final avatarUrl = post.creator?['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: FlickoCard(
        opacity: 0.05,
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.name,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post.firstMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              post.firstMessage!,
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textSecondary),
                                fontSize: 13,
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMessageBadge(post.messageCount),
                  ],
                ),
                if (postTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: postTags.map((tag) => _smallTag(tag)).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildAvatar(avatarUrl, creatorName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatorName,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatTimeAgo(post.lastMessageAt ?? post.createdAt),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 1.5),
      ),
      child: SafeImage(
        path: url,
        width: 24,
        height: 24,
        borderRadius: BorderRadius.circular(12),
        placeholder: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_rounded, size: 12, color: Color(FlickoColors.blurple)),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallTag(ForumTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Text(
        '${tag.emoji ?? ''} ${tag.name}'.trim(),
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textSecondary),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SliverSortBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverSortBarDelegate(this.child);

  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverSortBarDelegate oldDelegate) => true;
}

// ThreadViewScreen placeholder
class ThreadViewScreen extends StatelessWidget {
  final String serverId;
  final String channelId;
  final String threadId;

  const ThreadViewScreen({
    super.key,
    required this.serverId,
    required this.channelId,
    required this.threadId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Thread'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Premium Thread View coming soon...', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
