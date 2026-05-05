import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class DMListScreen extends ConsumerWidget {
  const DMListScreen({super.key});

  // ── Design tokens ──
  static const _bgPrimary = Color(0xFF000000);
  static const _bgCard = Color(0xFF0A0A0A);
  static const _bgSurface = Color(0xFF111111);
  static const _greenPunch = Color(0xFF10B981);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9CA3AF);
  static const _border = Color(0xFF1A1A1A);

  Future<List<Map<String, dynamic>>> _fetchRealProfiles(String? currentUserId) async {
    if (currentUserId == null) return [];
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .neq('id', currentUserId)
          .limit(30);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmState = ref.watch(dmControllerProvider);
    final conversations = dmState.conversations;

    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.maybeWhen(
      authenticated: (user, profile) => user.id,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: _bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _textPrimary, size: 26),
          onPressed: () {},
        ),
        centerTitle: true,
        title: Text(
          'FLICKO',
          style: GoogleFonts.outfit(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _textSecondary, size: 26),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large INBOX Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Text(
                  'INBOX',
                  style: GoogleFonts.outfit(
                    color: _textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _greenPunch.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _greenPunch.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.outfit(
                      color: _greenPunch,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Active User Stories - with real users
          SizedBox(
            height: 104,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchRealProfiles(currentUserId),
              builder: (context, snapshot) {
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildNewStoryButton(),
                    ],
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length + 1,
                  itemBuilder: (context, index) {
                    if (index == users.length) {
                      return _buildNewStoryButton();
                    }
                    final u = users[index];
                    final id = u['id'] as String? ?? '';
                    final username = u['username'] as String? ?? u['full_name'] as String? ?? 'User';
                    final avatarUrl = u['avatar_url'] as String?;
                    return _buildActiveItem(
                      context: context,
                      userId: id,
                      name: username,
                      imageUrl: avatarUrl,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Subtle divider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            height: 1,
            color: _border,
          ),
          const SizedBox(height: 8),

          // Messages List View
          Expanded(
            child: conversations.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      return _buildMessageTile(
                        context: context,
                        userId: conv.id,
                        name: conv.participant.username,
                        time: 'Just now',
                        message: conv.lastMessage,
                      );
                    },
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchRealProfiles(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: _greenPunch));
                      }
                      final users = snapshot.data ?? [];
                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 56, color: _textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No conversations yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a new conversation',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final u = users[index];
                          final id = u['id'] as String? ?? '';
                          final username = u['username'] as String? ?? u['full_name'] as String? ?? 'User';
                          final avatarUrl = u['avatar_url'] as String?;
                          return _buildMessageTile(
                            context: context,
                            userId: id,
                            name: username,
                            time: 'Active',
                            message: 'Tap to send a direct message',
                            imageUrl: avatarUrl,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FloatingActionButton(
          backgroundColor: _greenPunch,
          foregroundColor: Colors.black,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () {},
          child: const Icon(Icons.edit, size: 24),
        ),
      ),
    );
  }

  Widget _buildActiveItem({
    required BuildContext context,
    required String userId,
    required String name,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: () => context.push('/dms/$userId'),
      onLongPress: () => context.push('/u/$userId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border, width: 1),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.person, color: _textSecondary, size: 28)
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _greenPunch,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bgPrimary, width: 2),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewStoryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _greenPunch.withValues(alpha: 0.4),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(Icons.add, color: _greenPunch, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'New',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _greenPunch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile({
    required BuildContext context,
    required String userId,
    required String name,
    required String time,
    required String message,
    String? imageUrl,
    int unreadCount = 0,
  }) {
    return GestureDetector(
      onTap: () => context.push('/dms/$userId'),
      onLongPress: () => context.push('/u/$userId'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(
          children: [
            // Avatar on the left
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1),
                image: imageUrl != null && imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? const Icon(Icons.person, color: _textSecondary, size: 24)
                  : null,
            ),
            const SizedBox(width: 14),

            // Content in the center
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: _greenPunch,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount.toString(),
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
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
