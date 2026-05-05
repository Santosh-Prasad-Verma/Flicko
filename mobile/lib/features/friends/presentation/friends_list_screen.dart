import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Friends List Screen
/// 
/// Main friends list with online status and quick actions.
/// Routes to friend requests management at /friends/requests
class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();
  FriendFilter _activeFilter = FriendFilter.all;

  // Mock data
  final List<Friend> _friends = [
    Friend(
      id: '1',
      username: 'alice',
      displayName: 'Alice',
      avatarUrl: null,
      status: 'online',
      statusMessage: 'Playing Valorant',
      isOnline: true,
    ),
    Friend(
      id: '2',
      username: 'bob',
      displayName: 'Bob',
      avatarUrl: null,
      status: 'idle',
      statusMessage: 'AFK',
      isOnline: true,
    ),
    Friend(
      id: '3',
      username: 'charlie',
      displayName: 'Charlie',
      avatarUrl: null,
      status: 'dnd',
      statusMessage: 'Do Not Disturb',
      isOnline: true,
    ),
    Friend(
      id: '4',
      username: 'dave',
      displayName: 'Dave',
      avatarUrl: null,
      status: 'offline',
      statusMessage: 'Offline',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Friend(
      id: '5',
      username: 'eve',
      displayName: 'Eve',
      avatarUrl: null,
      status: 'offline',
      statusMessage: 'Offline',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  int get _onlineCount => _friends.where((f) => f.isOnline).length;
  int get _pendingCount => 2; // Mock pending requests

  List<Friend> get _filteredFriends {
    var result = _friends;

    // Apply status filter
    switch (_activeFilter) {
      case FriendFilter.all:
        break;
      case FriendFilter.online:
        result = result.where((f) => f.isOnline).toList();
        break;
      case FriendFilter.pending:
        // Navigate to requests screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.push('/friends/requests');
        });
        return [];
      case FriendFilter.blocked:
        result = []; // Mock: no blocked users
        break;
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      result = result.where((f) =>
        f.username.toLowerCase().contains(query) ||
        (f.displayName?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    // Sort: online first, then by name
    result.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return (a.displayName ?? a.username).compareTo(b.displayName ?? b.username);
    });

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Friends',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Friend requests button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add, color: Color(FlickoColors.textPrimary)),
                onPressed: () => context.push('/friends/requests'),
              ),
              if (_pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.red),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Filter tabs
          _buildFilterTabs(),

          // Online count
          if (_activeFilter == FriendFilter.all)
            _buildOnlineCount(),

          // Friends list
          Expanded(
            child: _buildFriendsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(FlickoColors.bgSecondary),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
        ),
        decoration: InputDecoration(
          hintText: 'Search friends...',
          hintStyle: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
          ),
          prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(FlickoColors.bgTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      (FriendFilter.all, 'All', _friends.length),
      (FriendFilter.online, 'Online', _onlineCount),
      (FriendFilter.pending, 'Pending', _pendingCount),
      (FriendFilter.blocked, 'Blocked', 0),
    ];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.bgTertiary)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label, count) = filters[index];
          final isActive = _activeFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(FlickoColors.blurple)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isActive
                          ? Colors.white
                          : const Color(FlickoColors.textMuted),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.3)
                          : const Color(FlickoColors.bgTertiary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.inter(
                        color: isActive ? Colors.white : const Color(FlickoColors.textMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOnlineCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(FlickoColors.bgSecondary),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(FlickoColors.green),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ONLINE — $_onlineCount',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    final friends = _filteredFriends;

    if (friends.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return _buildFriendTile(friend);
      },
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return InkWell(
      onTap: () => context.push('/dms/${friend.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: friend.avatarUrl,
              size: 48,
              status: friend.status,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        friend.displayName ?? friend.username,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!friend.isOnline && friend.lastSeen != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatLastSeen(friend.lastSeen!),
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.statusMessage,
                    style: GoogleFonts.inter(
                      color: friend.isOnline
                          ? const Color(FlickoColors.textSecondary)
                          : const Color(FlickoColors.textMuted),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.message,
                    color: Color(FlickoColors.textMuted),
                  ),
                  onPressed: () => context.push('/dms/${friend.id}'),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Color(FlickoColors.textMuted),
                  ),
                  onPressed: () => _showFriendOptions(friend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;

    switch (_activeFilter) {
      case FriendFilter.online:
        title = 'Nobody online';
        subtitle = 'When friends are online, they\'ll appear here';
        break;
      case FriendFilter.pending:
        title = 'No pending requests';
        subtitle = 'Friend requests will appear here';
        break;
      case FriendFilter.blocked:
        title = 'No blocked users';
        subtitle = 'Blocked users will appear here';
        break;
      default:
        title = 'No friends yet';
        subtitle = 'Add friends to see them here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: const Color(FlickoColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_activeFilter == FriendFilter.all) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/friends/requests'),
              icon: const Icon(Icons.person_add),
              label: Text(
                'Add Friends',
                style: GoogleFonts.inter(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFriendOptions(Friend friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: friend.avatarUrl,
                    size: 40,
                    status: friend.status,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName ?? friend.username,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '@${friend.username}',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(FlickoColors.bgTertiary)),
            // Actions
            ListTile(
              leading: const Icon(Icons.message, color: Color(FlickoColors.textPrimary)),
              title: Text(
                'Send Message',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/dms/${friend.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(FlickoColors.textPrimary)),
              title: Text(
                'View Profile',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/u/${friend.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.call, color: Color(FlickoColors.textPrimary)),
              title: Text(
                'Start Voice Call',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              ),
              onTap: () {
                Navigator.pop(context);
                // Start voice call
              },
            ),
            const Divider(color: Color(FlickoColors.bgTertiary)),
            ListTile(
              leading: const Icon(Icons.block, color: Color(FlickoColors.red)),
              title: Text(
                'Block',
                style: GoogleFonts.inter(color: const Color(FlickoColors.red)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmDialog(friend);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(FlickoColors.red)),
              title: Text(
                'Remove Friend',
                style: GoogleFonts.inter(color: const Color(FlickoColors.red)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRemoveConfirmDialog(friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Block ${friend.displayName ?? friend.username}?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'They will no longer be able to send you messages or friend requests.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${friend.displayName ?? friend.username} has been blocked',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(FlickoColors.success),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.red),
            ),
            child: Text(
              'Block',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Remove ${friend.displayName ?? friend.username}?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this friend?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _friends.removeWhere((f) => f.id == friend.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${friend.displayName ?? friend.username} removed from friends',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(FlickoColors.success),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.red),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}d';
    } else {
      return '${(diff.inDays / 30).floor()}mo';
    }
  }
}

/// Friend filter enum
enum FriendFilter {
  all,
  online,
  pending,
  blocked,
}

/// Friend model
class Friend {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final String statusMessage;
  final bool isOnline;
  final DateTime? lastSeen;

  Friend({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    required this.statusMessage,
    required this.isOnline,
    this.lastSeen,
  });
}
