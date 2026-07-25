import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';

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

class _ForumChannelScreenState extends ConsumerState<ForumChannelScreen> {
  SortMode _sort = SortMode.latestActivity;
  String? _filterTagId;
  bool _createVisible = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<ForumPostItem> _posts = [];
  List<ForumTag> _tags = [];
  Map<String, dynamic>? _channel;
  int _currentPage = 1;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadChannel(),
      _loadTags(),
      _loadPosts(),
    ]);
    setState(() => _isLoading = false);
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
        _hasNextPage = newPosts.length == 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _handlePostPress(ForumPostItem post) {
    // Navigate to thread view
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

  void _handleLoadMore() {
    if (_hasNextPage && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      _loadPosts(reset: false);
    }
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
    return '${days}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: FeedSkeleton(),
                    )
                  : _buildPostList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _createVisible = true),
        backgroundColor: const Color(FlickoColors.blurple),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.newspaper, color: Color(FlickoColors.textMuted), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _channel?['name'] ?? 'Forum',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopicAndFilters()),
          SliverToBoxAdapter(child: _buildSortBar()),
          if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet — be the first!',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _posts.length) {
                    return _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(FlickoColors.blurple),
                              ),
                            ),
                          )
                        : const SizedBox();
                  }
                  return _ForumPostCard(
                    post: _posts[index],
                    tags: _tags,
                    onPress: () => _handlePostPress(_posts[index]),
                    formatTimeAgo: _formatTimeAgo,
                  );
                },
                childCount: _posts.length + 1,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              _channel!['topic'],
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
            ),
          ),
        if (_tags.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
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
                  label: '${tag.emoji ?? ''} ${tag.name}'.trim(),
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
      ],
    );
  }

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(FlickoColors.blurple)
                : const Color(FlickoColors.bgTertiary),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : const Color(FlickoColors.textSecondary),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildSortButton(
            label: 'Latest Activity',
            isActive: _sort == SortMode.latestActivity,
            onTap: () {
              setState(() => _sort = SortMode.latestActivity);
              _loadPosts();
            },
          ),
          _buildSortButton(
            label: 'Creation Date',
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(FlickoColors.blurple) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isActive
                  ? const Color(FlickoColors.blurple)
                  : const Color(FlickoColors.textMuted),
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
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
    final creatorName =
        post.creator?['display_name'] ?? post.creator?['username'] ?? 'Unknown';

    return GestureDetector(
      onTap: onPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.name,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.firstMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                post.firstMessage!,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (postTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: postTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgTertiary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${tag.emoji ?? ''} ${tag.name}'.trim(),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  creatorName,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 12,
                      color: Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.messageCount}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '·',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatTimeAgo(post.lastMessageAt ?? post.createdAt),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for Thread View - will be implemented separately
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
      ),
      body: const Center(
        child: Text('Thread View - Coming Soon'),
      ),
    );
  }
}
