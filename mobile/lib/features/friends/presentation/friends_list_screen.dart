import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/features/friends/data/friends_repository.dart';
import 'package:mobile/features/friends/domain/friends_models.dart';

/// Friends List Screen
///
/// Main friends list with online status and quick actions.
/// Routes to friend requests management at /friends/requests
///
/// Data comes from [friendsListProvider] / [pendingRequestsProvider] /
/// [blockedUsersProvider], all backed by the Supabase `friends`,
/// `friend_requests` and `blocked_users` tables. A realtime subscription
/// invalidates them so the list reflects changes made on other devices.
class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();
  FriendFilter _activeFilter = FriendFilter.all;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeToChanges();
  }

  /// Subscribes to `friends` / `friend_requests` changes so an accept, remove
  /// or block performed elsewhere shows up here without a manual refresh.
  void _subscribeToChanges() {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    _channel = repo.subscribeToFriends(userId, () {
      if (!mounted) return;
      ref.invalidate(friendsListProvider);
      ref.invalidate(pendingRequestsProvider);
    });
  }

  /// Re-reads every friends-related query. Called after any mutation so the
  /// UI reflects what actually landed in the database rather than an
  /// optimistic guess.
  void _refresh() {
    ref.invalidate(friendsListProvider);
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(blockedUsersProvider);
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      ref.read(friendsRepositoryProvider).unsubscribe(channel);
    }
    _searchController.dispose();
    super.dispose();
  }

  /// Applies the search box and the online/all filter, then sorts.
  ///
  /// Copies the incoming list before sorting: [friends] is owned by the
  /// provider's cached AsyncValue, and sorting in place would mutate it.
  List<Friend> _visibleFriends(List<Friend> friends) {
    var result = List<Friend>.of(friends);

    if (_activeFilter == FriendFilter.online) {
      result = result.where((f) => f.isOnline).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((f) =>
              f.username.toLowerCase().contains(query) ||
              (f.displayName?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Online first, then alphabetical by the name actually displayed.
    result.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return (a.displayName ?? a.username)
          .toLowerCase()
          .compareTo((b.displayName ?? b.username).toLowerCase());
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final blockedAsync = ref.watch(blockedUsersProvider);

    final friends = friendsAsync.value ?? const <Friend>[];
    final incomingCount = (requestsAsync.value ?? const <FriendRequest>[])
        .where((r) => r.isIncoming)
        .length;
    final blockedCount = (blockedAsync.value ?? const <FriendUser>[]).length;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
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
                onPressed: () => _openRequests(),
              ),
              if (incomingCount > 0)
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
                      '$incomingCount',
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
          _buildFilterTabs(
            totalCount: friends.length,
            onlineCount: friends.where((f) => f.isOnline).length,
            pendingCount: incomingCount,
            blockedCount: blockedCount,
          ),

          // Online count
          if (_activeFilter == FriendFilter.all)
            _buildOnlineCount(friends.where((f) => f.isOnline).length),

          // Body
          Expanded(
            child: _activeFilter == FriendFilter.blocked
                ? _buildBlockedList(blockedAsync)
                : _buildFriendsList(friendsAsync),
          ),
        ],
      ),
    );
  }

  /// Navigates to the requests screen and refreshes on return, since the user
  /// may have accepted or declined something while they were there.
  Future<void> _openRequests() async {
    await context.push('/friends/requests');
    if (mounted) _refresh();
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

  Widget _buildFilterTabs({
    required int totalCount,
    required int onlineCount,
    required int pendingCount,
    required int blockedCount,
  }) {
    final filters = [
      (FriendFilter.all, 'All', totalCount),
      (FriendFilter.online, 'Online', onlineCount),
      (FriendFilter.pending, 'Pending', pendingCount),
      (FriendFilter.blocked, 'Blocked', blockedCount),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label, count) = filters[index];
          final isActive = _activeFilter == filter;

          return GestureDetector(
            // Pending has no inline list of its own — it hands off to the
            // requests screen. Navigating here (rather than from a filter
            // getter during build) keeps the side effect out of build().
            onTap: () {
              if (filter == FriendFilter.pending) {
                _openRequests();
              } else {
                setState(() => _activeFilter = filter);
              }
            },
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

  Widget _buildOnlineCount(int onlineCount) {
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
            'ONLINE — $onlineCount',
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

  Widget _buildFriendsList(AsyncValue<List<Friend>> async) {
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      ),
      error: (err, _) => _buildErrorState(
        'Could not load friends',
        () => ref.invalidate(friendsListProvider),
      ),
      data: (allFriends) {
        final friends = _visibleFriends(allFriends);
        if (friends.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          color: const Color(FlickoColors.blurple),
          onRefresh: () async => ref.invalidate(friendsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: friends.length,
            itemBuilder: (context, index) => _buildFriendTile(friends[index]),
          ),
        );
      },
    );
  }

  Widget _buildBlockedList(AsyncValue<List<FriendUser>> async) {
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      ),
      error: (err, _) => _buildErrorState(
        'Could not load blocked users',
        () => ref.invalidate(blockedUsersProvider),
      ),
      data: (blocked) {
        if (blocked.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: blocked.length,
          itemBuilder: (context, index) => _buildBlockedTile(blocked[index]),
        );
      },
    );
  }

  Widget _buildBlockedTile(FriendUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          UserAvatar(imageUrl: user.avatarUrl, size: 48, status: 'offline'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? user.username,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _unblockUser(user),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(FlickoColors.textMuted)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Unblock',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return InkWell(
      onTap: () => _showFriendOptions(friend),
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
                      Flexible(
                        child: Text(
                          friend.displayName ?? friend.username,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  onPressed: () => context.go('/dms/${friend.id}'),
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

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 64,
            color: Color(FlickoColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('Retry', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
            ),
          ),
        ],
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
        title = _searchController.text.trim().isEmpty
            ? 'No friends yet'
            : 'No matches';
        subtitle = _searchController.text.trim().isEmpty
            ? 'Add friends to see them here'
            : 'No friends match that search';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: Color(FlickoColors.textMuted),
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
              onPressed: () => _openRequests(),
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
                context.go('/dms/${friend.id}');
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
                context.push('/profile/${friend.id}');
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _blockUser(friend);
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _removeFriend(friend);
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

  // ─── Mutations ────────────────────────────────────────────────────────
  //
  // Each of these reports the real outcome: the success snackbar only shows
  // once the write returns, and failures surface instead of being swallowed
  // behind an optimistic list edit.

  Future<void> _blockUser(Friend friend) async {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    try {
      await repo.blockUser(userId, friend.id);
      if (!mounted) return;
      _refresh();
      _showSnack(
        '${friend.displayName ?? friend.username} has been blocked',
        const Color(FlickoColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not block user: $e', const Color(FlickoColors.red));
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    try {
      await repo.removeFriend(userId, friend.id);
      if (!mounted) return;
      _refresh();
      _showSnack(
        '${friend.displayName ?? friend.username} removed from friends',
        const Color(FlickoColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not remove friend: $e', const Color(FlickoColors.red));
    }
  }

  Future<void> _unblockUser(FriendUser user) async {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    try {
      await repo.unblockUser(userId, user.id);
      if (!mounted) return;
      _refresh();
      _showSnack(
        '${user.displayName ?? user.username} unblocked',
        const Color(FlickoColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not unblock user: $e', const Color(FlickoColors.red));
    }
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: background,
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
