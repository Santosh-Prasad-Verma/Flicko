import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Friend Requests Screen
/// 
/// Manage friend requests - view incoming, outgoing, and add new friends.
/// Mirrors the React Native friends management screen.
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  final _searchController = TextEditingController();
  FriendTab _activeTab = FriendTab.incoming;
  bool _isLoading = false;

  // Mock data
  final List<FriendRequest> _incomingRequests = [
    FriendRequest(
      id: 'req1',
      user: FriendUser(
        id: 'user2',
        username: 'bob',
        displayName: 'Bob',
        avatarUrl: null,
        status: 'online',
      ),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: 'pending',
    ),
    FriendRequest(
      id: 'req2',
      user: FriendUser(
        id: 'user3',
        username: 'charlie',
        displayName: 'Charlie',
        avatarUrl: null,
        status: 'offline',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: 'pending',
    ),
  ];

  final List<FriendRequest> _outgoingRequests = [
    FriendRequest(
      id: 'req3',
      user: FriendUser(
        id: 'user4',
        username: 'dave',
        displayName: 'Dave',
        avatarUrl: null,
        status: 'idle',
      ),
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'pending',
    ),
  ];

  final List<FriendUser> _suggestedFriends = [
    FriendUser(
      id: 'user5',
      username: 'eve',
      displayName: 'Eve',
      avatarUrl: null,
      status: 'online',
      mutualFriends: 3,
    ),
    FriendUser(
      id: 'user6',
      username: 'frank',
      displayName: 'Frank',
      avatarUrl: null,
      status: 'dnd',
      mutualFriends: 1,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(FlickoColors.textPrimary)),
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Tab bar
          _buildTabBar(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
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
          hintText: _activeTab == FriendTab.add
              ? 'Search by username (e.g., username#1234)'
              : 'Search friends...',
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

  Widget _buildTabBar() {
    final tabs = [
      (FriendTab.incoming, 'Incoming', _incomingRequests.length),
      (FriendTab.outgoing, 'Outgoing', _outgoingRequests.length),
      (FriendTab.add, 'Add Friend', null),
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
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (tab, label, count) = tabs[index];
          final isActive = _activeTab == tab;

          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
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
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(FlickoColors.red),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          color: isActive ? Colors.white : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case FriendTab.incoming:
        return _buildIncomingRequests();
      case FriendTab.outgoing:
        return _buildOutgoingRequests();
      case FriendTab.add:
        return _buildAddFriend();
    }
  }

  Widget _buildIncomingRequests() {
    if (_incomingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        title: 'No pending requests',
        subtitle: 'When someone sends you a friend request, it will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        return _buildRequestTile(request, isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingRequests() {
    if (_outgoingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send,
        title: 'No outgoing requests',
        subtitle: 'Friend requests you send will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _outgoingRequests.length,
      itemBuilder: (context, index) {
        final request = _outgoingRequests[index];
        return _buildRequestTile(request, isIncoming: false);
      },
    );
  }

  Widget _buildAddFriend() {
    final query = _searchController.text.toLowerCase();
    final filteredSuggestions = query.isEmpty
        ? _suggestedFriends
        : _suggestedFriends.where((f) =>
            f.username.toLowerCase().contains(query) ||
            (f.displayName?.toLowerCase().contains(query) ?? false)
          ).toList();

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (_searchController.text.isNotEmpty)
          _buildSearchResult(),
        
        if (filteredSuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Suggested Friends',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...filteredSuggestions.map((user) => _buildSuggestedUserTile(user)),
        ],
      ],
    );
  }

  Widget _buildSearchResult() {
    return Card(
      color: const Color(FlickoColors.bgSecondary),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Result',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const UserAvatar(size: 48, status: 'online'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchController.text,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Found user',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Friend request sent!',
                          style: GoogleFonts.inter(),
                        ),
                        backgroundColor: const Color(FlickoColors.success),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                  ),
                  child: Text(
                    'Add Friend',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(FriendRequest request, {required bool isIncoming}) {
    return InkWell(
      onTap: () => context.push('/profile/${request.user.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: request.user.avatarUrl,
              size: 48,
              status: request.user.status,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.user.displayName ?? request.user.username,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@${request.user.username}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sent ${_formatTime(request.createdAt)}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isIncoming) ...[
              // Accept button
              ElevatedButton(
                onPressed: () => _acceptRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.green),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  'Accept',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Decline button
              OutlinedButton(
                onPressed: () => _declineRequest(request),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(FlickoColors.red)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  'Decline',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.red),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              // Cancel button
              OutlinedButton(
                onPressed: () => _cancelRequest(request),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(FlickoColors.textMuted)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedUserTile(FriendUser user) {
    return InkWell(
      onTap: () => context.push('/profile/${user.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: user.avatarUrl,
              size: 48,
              status: user.status,
            ),
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
                  if (user.mutualFriends != null)
                    Text(
                      '${user.mutualFriends} mutual friend${user.mutualFriends == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Friend request sent to ${user.username}!',
                      style: GoogleFonts.inter(),
                    ),
                    backgroundColor: const Color(FlickoColors.success),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
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
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Add Friend',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter username#1234',
            hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            filled: true,
            fillColor: const Color(FlickoColors.bgTertiary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
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
              setState(() => _activeTab = FriendTab.add);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
            ),
            child: Text(
              'Search',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptRequest(FriendRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Accepted friend request from ${request.user.username}',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(FlickoColors.success),
      ),
    );
    setState(() {
      _incomingRequests.remove(request);
    });
  }

  void _declineRequest(FriendRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Declined friend request from ${request.user.username}',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(FlickoColors.bgSecondary),
      ),
    );
    setState(() {
      _incomingRequests.remove(request);
    });
  }

  void _cancelRequest(FriendRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cancelled friend request to ${request.user.username}',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(FlickoColors.bgSecondary),
      ),
    );
    setState(() {
      _outgoingRequests.remove(request);
    });
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Friend tab enum
enum FriendTab {
  incoming,
  outgoing,
  add,
}

/// Friend request model
class FriendRequest {
  final String id;
  final FriendUser user;
  final DateTime createdAt;
  final String status;

  FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
    required this.status,
  });
}

/// Friend user model
class FriendUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final int? mutualFriends;

  FriendUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.mutualFriends,
  });
}
