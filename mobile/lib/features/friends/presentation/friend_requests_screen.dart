import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/friends/data/friends_repository.dart';
import 'package:mobile/features/friends/domain/friends_models.dart';

/// Friend Requests Screen
///
/// Manage friend requests — view incoming, outgoing, and add new friends.
///
/// Incoming/outgoing lists come from [pendingRequestsProvider], split on
/// `isIncoming`. The Add Friend tab searches `profiles` through
/// [FriendsRepository.searchUsers]. Accept/decline/cancel/send all write to
/// Supabase and then invalidate the provider, so what you see is what was
/// actually persisted.
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  final _searchController = TextEditingController();
  FriendTab _activeTab = FriendTab.incoming;

  /// Ids currently mid-mutation, so their buttons can show progress and not be
  /// double-tapped into duplicate writes.
  final Set<String> _busyIds = {};

  // Search state for the Add Friend tab.
  Timer? _debounce;
  List<FriendUser> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    if (_activeTab != FriendTab.add) return;

    // Debounce so typing doesn't fire a query per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = trimmed;
    });

    final results = await ref.read(friendsRepositoryProvider).searchUsers(trimmed);

    if (!mounted) return;
    // Ignore results from a query the user has already typed past.
    if (_lastQuery != trimmed) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final all = requestsAsync.value ?? const <FriendRequest>[];
    final incoming = all.where((r) => r.isIncoming).toList();
    final outgoing = all.where((r) => !r.isIncoming).toList();

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
            onPressed: () => setState(() => _activeTab = FriendTab.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Tab bar
          _buildTabBar(incoming.length, outgoing.length),

          // Content
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
              ),
              error: (err, _) => _buildErrorState(),
              data: (_) => _buildContent(incoming, outgoing),
            ),
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
        onChanged: _onSearchChanged,
        onSubmitted: _runSearch,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
        ),
        decoration: InputDecoration(
          hintText: _activeTab == FriendTab.add
              ? 'Search by username or display name'
              : 'Search requests...',
          hintStyle: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
          ),
          prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
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

  Widget _buildTabBar(int incomingCount, int outgoingCount) {
    final tabs = [
      (FriendTab.incoming, 'Incoming', incomingCount),
      (FriendTab.outgoing, 'Outgoing', outgoingCount),
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
            onTap: () {
              setState(() => _activeTab = tab);
              // Entering Add Friend with text already in the box should show
              // results rather than an empty list.
              if (tab == FriendTab.add && _searchController.text.trim().isNotEmpty) {
                _runSearch(_searchController.text);
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
                          color: Colors.white,
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

  Widget _buildContent(List<FriendRequest> incoming, List<FriendRequest> outgoing) {
    switch (_activeTab) {
      case FriendTab.incoming:
        return _buildRequestList(_filterRequests(incoming), isIncoming: true);
      case FriendTab.outgoing:
        return _buildRequestList(_filterRequests(outgoing), isIncoming: false);
      case FriendTab.add:
        return _buildAddFriend();
    }
  }

  /// Applies the search box to a request list (matches username/display name).
  List<FriendRequest> _filterRequests(List<FriendRequest> requests) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return requests;
    return requests
        .where((r) =>
            r.user.username.toLowerCase().contains(query) ||
            (r.user.displayName?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  Widget _buildRequestList(List<FriendRequest> requests, {required bool isIncoming}) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: isIncoming ? Icons.inbox : Icons.send,
        title: isIncoming ? 'No pending requests' : 'No outgoing requests',
        subtitle: isIncoming
            ? 'When someone sends you a friend request, it will appear here'
            : 'Friend requests you send will appear here',
      );
    }

    return RefreshIndicator(
      color: const Color(FlickoColors.blurple),
      onRefresh: () async => ref.invalidate(pendingRequestsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: requests.length,
        itemBuilder: (context, index) =>
            _buildRequestTile(requests[index], isIncoming: isIncoming),
      ),
    );
  }

  Widget _buildAddFriend() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'Find people',
        subtitle: 'Search for someone by username or display name',
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off,
        title: 'No users found',
        subtitle: 'Nobody matches "$query"',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildSearchResultTile(_searchResults[index]),
    );
  }

  Widget _buildSearchResultTile(FriendUser user) {
    final busy = _busyIds.contains(user.id);

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            ElevatedButton(
              onPressed: busy ? null : () => _sendRequest(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Add',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(FriendRequest request, {required bool isIncoming}) {
    final busy = _busyIds.contains(request.id);

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(FlickoColors.blurple),
                  ),
                ),
              )
            else if (isIncoming) ...[
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Color(FlickoColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            'Could not load requests',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(pendingRequestsProvider),
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

  // ─── Mutations ────────────────────────────────────────────────────────

  /// Runs [action] with [id] marked busy, then refreshes and reports.
  ///
  /// Errors are surfaced to the user rather than swallowed — a failed accept
  /// used to still show "Accepted!" and drop the row from the list.
  Future<void> _mutate(
    String id,
    Future<void> Function() action, {
    required String successMessage,
    required String failurePrefix,
  }) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));

    try {
      await action();
      if (!mounted) return;
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendsListProvider);
      _showSnack(successMessage, const Color(FlickoColors.success));
    } catch (e) {
      if (!mounted) return;
      _showSnack('$failurePrefix: $e', const Color(FlickoColors.red));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    await _mutate(
      request.id,
      () => repo.acceptFriendRequest(
        requestId: request.id,
        // The request is incoming, so the other user sent it and the signed-in
        // user is the receiver.
        senderId: request.user.id,
        receiverId: userId,
      ),
      successMessage: 'You are now friends with ${request.user.username}',
      failurePrefix: 'Could not accept request',
    );
  }

  Future<void> _declineRequest(FriendRequest request) async {
    final repo = ref.read(friendsRepositoryProvider);
    await _mutate(
      request.id,
      () => repo.declineFriendRequest(request.id),
      successMessage: 'Declined request from ${request.user.username}',
      failurePrefix: 'Could not decline request',
    );
  }

  Future<void> _cancelRequest(FriendRequest request) async {
    final repo = ref.read(friendsRepositoryProvider);
    await _mutate(
      request.id,
      () => repo.cancelFriendRequest(request.id),
      successMessage: 'Cancelled request to ${request.user.username}',
      failurePrefix: 'Could not cancel request',
    );
  }

  Future<void> _sendRequest(FriendUser user) async {
    final repo = ref.read(friendsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null) return;

    await _mutate(
      user.id,
      () => repo.sendFriendRequest(senderId: userId, receiverId: user.id),
      successMessage: 'Friend request sent to ${user.username}',
      failurePrefix: 'Could not send request',
    );
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: background,
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
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
