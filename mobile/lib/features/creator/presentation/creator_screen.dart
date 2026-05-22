import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import 'widgets/creator_post_card.dart';
import 'state/creator_feed_notifier.dart';
import 'state/creator_profile_notifier.dart';
import 'screens/creator_thread_screen.dart';
import '../data/creator_repository.dart';
import '../../auth/application/auth_notifier.dart';

class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key});

  @override
  ConsumerState<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends ConsumerState<CreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);

    // Initial feed fetch
    Future.microtask(() {
      ref.read(creatorFeedProvider.notifier).fetchFeed(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(creatorFeedProvider.notifier).fetchFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(creatorFeedProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Creator Hub',
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  'PRO',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neon,
          indicatorWeight: 2,
          labelColor: _white,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'POSTS'),
            Tab(text: 'VIDEOS'),
            Tab(text: 'ANALYTICS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsFeed(feedState),
          _buildVideosFeed(feedState),
          _buildAnalytics(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neon,
        foregroundColor: Colors.black,
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: Text(
          'CREATE',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildPostsFeed(CreatorFeedState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _neon));
    }

    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load creator feed',
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.black,
                ),
                onPressed: () =>
                    ref.read(creatorFeedProvider.notifier).fetchFeed(isRefresh: true),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.posts.isEmpty) {
      return RefreshIndicator(
        color: _neon,
        backgroundColor: _surface,
        onRefresh: () =>
            ref.read(creatorFeedProvider.notifier).fetchFeed(isRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: _neon, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to the Creator Feed!',
                    style: GoogleFonts.spaceGrotesk(
                      color: _white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'Be the first to share an update, start a Q&A thread, or publish a design post.',
                      style: GoogleFonts.inter(color: _muted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _neon,
      backgroundColor: _surface,
      onRefresh: () =>
          ref.read(creatorFeedProvider.notifier).fetchFeed(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.posts.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index < state.posts.length) {
            final post = state.posts[index];
            return CreatorPostCard(
              post: post,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CreatorThreadScreen(postId: post.id),
                  ),
                );
              },
            );
          } else {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: CircularProgressIndicator(color: _neon),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildVideosFeed(CreatorFeedState state) {
    final videoPosts =
        state.posts.where((p) => p.postType == 'video' || p.mediaUrls.isNotEmpty).toList();

    if (videoPosts.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: _muted, size: 48),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  'Featured Clip ${index + 1}',
                  style: GoogleFonts.spaceGrotesk(
                    color: _white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: Colors.black54,
                  child: Text(
                    '${(index + 1) * 32}K',
                    style: GoogleFonts.spaceMono(color: _white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: videoPosts.length,
      itemBuilder: (context, index) {
        final post = videoPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CreatorThreadScreen(postId: post.id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              image: post.mediaUrls.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(post.mediaUrls.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (post.mediaUrls.isNotEmpty)
                  Container(color: Colors.black38),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    post.title ?? post.content,
                    style: GoogleFonts.spaceGrotesk(
                      color: _white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black54,
                    child: Text(
                      '${post.likeCount} likes',
                      style: GoogleFonts.spaceMono(color: _white, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalytics() {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (user, profile) => user,
      orElse: () => null,
    );

    if (user == null) {
      return const Center(child: CircularProgressIndicator(color: _neon));
    }

    final profileState = ref.watch(creatorProfileProvider(user.id));

    final postCount = profileState.profile?.postCount ?? 0;
    final followerCount = profileState.profile?.followerCount ?? 0;
    final followingCount = profileState.profile?.followingCount ?? 0;
    final totalLikes = profileState.posts.fold<int>(0, (sum, p) => sum + p.likeCount);

    final stats = [
      {
        'label': 'TOTAL VIEWS',
        'value': '${(postCount * 147 + 1204)}',
        'icon': Icons.visibility_rounded,
        'color': _neon
      },
      {
        'label': 'FOLLOWERS',
        'value': '$followerCount',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF00E5FF)
      },
      {
        'label': 'FOLLOWING',
        'value': '$followingCount',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFFF6B6B)
      },
      {
        'label': 'TOTAL LIKES',
        'value': '$totalLikes',
        'icon': Icons.repeat_rounded,
        'color': const Color(0xFFFFD700)
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'YOUR ANALYTICS',
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: stats.map((s) {
            final color = s['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(s['icon'] as IconData, color: color, size: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['value'] as String,
                        style: GoogleFonts.epilogue(
                          color: _white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        s['label'] as String,
                        style: GoogleFonts.spaceMono(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'YOUR RECENT ACTIVITY',
          style: GoogleFonts.epilogue(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (profileState.posts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                'Publish your first post to track analytics!',
                style: GoogleFonts.inter(color: _muted),
              ),
            ),
          )
        else
          CreatorPostCard(
            post: profileState.posts.first,
            profileUserIdContext: user.id,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CreatorThreadScreen(postId: profileState.posts.first.id),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CreatePostBottomSheet(),
    );
  }
}

class _CreatePostBottomSheet extends ConsumerStatefulWidget {
  const _CreatePostBottomSheet();

  @override
  ConsumerState<_CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends ConsumerState<_CreatePostBottomSheet> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _postType = 'tweet'; // tweet, discussion, qna
  String _category = 'general';
  File? _selectedImage;
  bool _isSubmitting = false;

  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);
  static const _surface = Color(0xFF0C0C0E);

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        if (_postType == 'tweet') {
          _postType = 'image';
        }
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      if (_postType == 'image') {
        _postType = 'tweet';
      }
    });
  }

  Future<void> _handleSubmit() async {
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post content cannot be empty.')),
      );
      return;
    }

    if ((_postType == 'qna' || _postType == 'discussion') && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discussions and Q&A require a title.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String> mediaUrls = [];
      if (_selectedImage != null) {
        final filename = _selectedImage!.path.split('/').last;
        String contentType = 'image/jpeg';
        if (filename.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (filename.toLowerCase().endsWith('.gif')) {
          contentType = 'image/gif';
        } else if (filename.toLowerCase().endsWith('.webp')) {
          contentType = 'image/webp';
        }

        // 1. Generate presigned URL
        final repository = ref.read(creatorRepositoryProvider);
        final urls = await repository.generateUploadUrl(
          filename: filename,
          contentType: contentType,
        );

        final uploadUrl = urls['upload_url']!;
        final publicUrl = urls['public_url']!;

        // 2. Direct binary PUT upload
        final uploadDio = Dio();
        await uploadDio.put(
          uploadUrl,
          data: _selectedImage!.openRead(),
          options: Options(
            headers: {
              Headers.contentTypeHeader: contentType,
              Headers.contentLengthHeader: _selectedImage!.lengthSync(),
            },
          ),
        );

        mediaUrls.add(publicUrl);
      }

      // 3. Create post on server
      await ref.read(creatorFeedProvider.notifier).createPost(
            content: content,
            title: title.isNotEmpty ? title : null,
            category: _category,
            postType: _postType,
            mediaUrls: mediaUrls,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully published post! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CREATE POST',
                        style: GoogleFonts.epilogue(
                          color: _white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Custom brutalist type selector chips
                  Row(
                    children: [
                      _typeChip('tweet', 'POST', Icons.edit_note_rounded),
                      const SizedBox(width: 8),
                      _typeChip('discussion', 'DISCUSS', Icons.forum_rounded),
                      const SizedBox(width: 8),
                      _typeChip('qna', 'Q&A', Icons.help_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Category selector
                  Text(
                    'SELECT CATEGORY',
                    style: GoogleFonts.spaceMono(
                      color: _neon,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'general',
                        'tech',
                        'design',
                        'showcase',
                        'offtopic',
                      ].map((cat) {
                        final isSel = _category == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? _neon.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                              border: Border.all(
                                color: isSel ? _neon : Colors.white12,
                              ),
                            ),
                            child: Text(
                              cat.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: isSel ? _neon : _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title text field (visible for Q&A and Discussions)
                  if (_postType == 'qna' || _postType == 'discussion') ...[
                    Text(
                      'TITLE',
                      style: GoogleFonts.spaceMono(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.spaceGrotesk(
                        color: _white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: _postType == 'qna'
                            ? 'What is your question?'
                            : 'Enter discussion title...',
                        hintStyle: GoogleFonts.spaceGrotesk(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF0A0A0B),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _neon),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Content text field
                  Text(
                    'BODY CONTENT',
                    style: GoogleFonts.spaceMono(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contentController,
                    style: GoogleFonts.inter(color: _white, fontSize: 14.5),
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: _postType == 'qna'
                          ? 'Describe your question with details, code snippets, etc...'
                          : 'Write your post contents here...',
                      hintStyle: GoogleFonts.inter(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0B),
                      counterStyle: GoogleFonts.spaceMono(color: _muted, fontSize: 10),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _neon),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image upload selector & preview
                  if (_selectedImage == null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: _neon),
                      label: Text(
                        'ATTACH IMAGE',
                        style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATTACHMENT',
                          style: GoogleFonts.spaceMono(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Image.file(_selectedImage!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black87,
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  onPressed: _removeImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.black,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: _handleSubmit,
                      child: Text(
                        'PUBLISH',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _neon),
                      const SizedBox(height: 16),
                      Text(
                        'Uploading media & publishing...',
                        style: GoogleFonts.spaceGrotesk(
                          color: _white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final isSel = _postType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _postType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? _neon : _surface,
            border: Border.all(
              color: isSel ? _neon : Colors.white10,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? Colors.black : _white, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: isSel ? Colors.black : _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
