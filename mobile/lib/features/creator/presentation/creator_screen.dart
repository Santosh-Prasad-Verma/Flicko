import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  // Mock posts data
  final List<Map<String, dynamic>> _posts = [
    {
      'type': 'tweet',
      'content': 'Just shipped a new feature on Flicko 🚀 Real-time voice channels are now live!',
      'likes': 142,
      'comments': 23,
      'reposts': 18,
      'time': '2h',
    },
    {
      'type': 'image',
      'content': 'Check out the new UI we\'ve been working on 👀',
      'likes': 389,
      'comments': 47,
      'reposts': 62,
      'time': '5h',
    },
    {
      'type': 'video',
      'content': 'Full walkthrough of the Flicko bot system — 8 bots, zero setup needed.',
      'likes': 1204,
      'comments': 98,
      'reposts': 211,
      'time': '1d',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Text('Creator Hub',
            style: GoogleFonts.epilogue(
                color: _white, fontWeight: FontWeight.w900, fontSize: 18,
                fontStyle: FontStyle.italic)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text('PRO',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
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
              fontWeight: FontWeight.w700, fontSize: 13),
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
          _buildPostsFeed(),
          _buildVideosFeed(),
          _buildAnalytics(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neon,
        foregroundColor: Colors.black,
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: Text('CREATE',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildPostsFeed() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildPostCard(_posts[index]),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isVideo = post['type'] == 'video';
    final isImage = post['type'] == 'image';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person, color: _neon, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You',
                        style: GoogleFonts.spaceGrotesk(
                            color: _white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(post['time'],
                        style: GoogleFonts.inter(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              if (isVideo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text('VIDEO',
                      style: GoogleFonts.spaceMono(
                          color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                )
              else if (isImage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                  ),
                  child: Text('IMAGE',
                      style: GoogleFonts.spaceMono(
                          color: const Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(post['content'],
              style: GoogleFonts.inter(color: _white.withValues(alpha: 0.85), fontSize: 15, height: 1.5)),
          if (isImage || isVideo) ...[
            const SizedBox(height: 12),
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111113),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Center(
                child: Icon(
                  isVideo ? Icons.play_circle_fill_rounded : Icons.image_rounded,
                  color: _muted,
                  size: 48,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _postAction(Icons.favorite_border_rounded, '${post['likes']}'),
              const SizedBox(width: 24),
              _postAction(Icons.chat_bubble_outline_rounded, '${post['comments']}'),
              const SizedBox(width: 24),
              _postAction(Icons.repeat_rounded, '${post['reposts']}'),
              const Spacer(),
              _postAction(Icons.share_outlined, ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _postAction(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, color: _muted, size: 20),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(count, style: GoogleFonts.inter(color: _muted, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildVideosFeed() {
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
              bottom: 8, left: 8, right: 8,
              child: Text('Video ${index + 1}',
                  style: GoogleFonts.spaceGrotesk(
                      color: _white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: Colors.black54,
                child: Text('${(index + 1) * 47}K',
                    style: GoogleFonts.spaceMono(color: _white, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    final stats = [
      {'label': 'TOTAL VIEWS', 'value': '24.8K', 'icon': Icons.visibility_rounded, 'color': _neon},
      {'label': 'FOLLOWERS', 'value': '1,204', 'icon': Icons.people_rounded, 'color': const Color(0xFF00E5FF)},
      {'label': 'LIKES', 'value': '8,391', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFFF6B6B)},
      {'label': 'REPOSTS', 'value': '2,107', 'icon': Icons.repeat_rounded, 'color': const Color(0xFFFFD700)},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('THIS WEEK',
            style: GoogleFonts.epilogue(
                color: _white, fontWeight: FontWeight.w900,
                fontSize: 20, fontStyle: FontStyle.italic)),
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
                      Text(s['value'] as String,
                          style: GoogleFonts.epilogue(
                              color: _white, fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      Text(s['label'] as String,
                          style: GoogleFonts.spaceMono(
                              color: _muted, fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('TOP POST',
            style: GoogleFonts.epilogue(
                color: _white, fontWeight: FontWeight.w900,
                fontSize: 16, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        _buildPostCard(_posts[2]),
      ],
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('CREATE',
                  style: GoogleFonts.epilogue(
                      color: _white, fontSize: 24,
                      fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              _createOption(ctx, Icons.edit_note_rounded, 'POST', 'Share a thought or update', const Color(0xFF52B788)),
              const SizedBox(height: 12),
              _createOption(ctx, Icons.videocam_rounded, 'VIDEO', 'Upload a video clip', Colors.red),
              const SizedBox(height: 12),
              _createOption(ctx, Icons.image_rounded, 'PHOTO', 'Share an image', const Color(0xFF00E5FF)),
              const SizedBox(height: 12),
              _createOption(ctx, Icons.poll_rounded, 'POLL', 'Ask your audience', const Color(0xFFFFD700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createOption(BuildContext ctx, IconData icon, String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$title creation coming soon!')));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        color: _white, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(subtitle,
                    style: GoogleFonts.inter(color: _muted, fontSize: 13)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: _muted, size: 16),
          ],
        ),
      ),
    );
  }
}
