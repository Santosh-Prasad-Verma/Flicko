import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/friends/domain/friends_models.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(supabaseClientProvider));
});

/// Accepted friends of the signed-in user.
///
/// Returns an empty list when nobody is signed in rather than throwing, so the
/// screens render their empty state instead of an error during sign-out.
final friendsListProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final userId = repo.currentUserId;
  if (userId == null) return const [];
  return repo.fetchFriends(userId);
});

/// Pending friend requests (incoming *and* outgoing) for the signed-in user.
/// Split by `isIncoming` at the call site.
final pendingRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final userId = repo.currentUserId;
  if (userId == null) return const [];
  return repo.fetchPendingRequests(userId);
});

/// Users the signed-in user has blocked.
final blockedUsersProvider =
    FutureProvider.autoDispose<List<FriendUser>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final userId = repo.currentUserId;
  if (userId == null) return const [];
  return repo.fetchBlockedUsers(userId);
});

class FriendsRepository {
  final SupabaseClient _client;

  FriendsRepository(this._client);

  /// The signed-in user's id, or null when unauthenticated.
  String? get currentUserId => _client.auth.currentUser?.id;

  String? get _currentUserId => currentUserId;

  // ─── Friends list ─────────────────────────────────────────────────────

  /// Fetches accepted friends for [userId] by querying the `friends` table
  /// and joining profiles on `friend_id`.
  Future<List<Friend>> fetchFriends(String userId) async {
    try {
      final response = await _client
          .from('friends')
          .select('*, profile:profiles!friend_id(*)')
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((row) => Friend.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error fetching friends: $e', name: 'FriendsRepository');
      return [];
    }
  }

  // ─── Friend requests ──────────────────────────────────────────────────

  /// Fetches pending friend requests for [userId] (both incoming and outgoing).
  Future<List<FriendRequest>> fetchPendingRequests(String userId) async {
    try {
      final response = await _client
          .from('friend_requests')
          .select(
            '*, sender_profile:profiles!sender_id(*), receiver_profile:profiles!receiver_id(*)',
          )
          .eq('status', 'pending')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendRequest.fromJson(row, userId)).toList();
    } catch (e) {
      developer.log('Error fetching friend requests: $e',
          name: 'FriendsRepository');
      return [];
    }
  }

  /// Sends a friend request from [senderId] to [receiverId].
  Future<void> sendFriendRequest({
    required String senderId,
    required String receiverId,
    String? message,
  }) async {
    await _client.from('friend_requests').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      if (message != null) 'message': message,
      'status': 'pending',
    });
  }

  /// Accepts a friend request: updates status, inserts `friends` + `friendships`.
  /// Mirrors the notification screen's `_handleAcceptFriend` pattern.
  Future<void> acceptFriendRequest({
    required String requestId,
    required String senderId,
    required String receiverId,
  }) async {
    // 1. Update the request status.
    await _client
        .from('friend_requests')
        .update({
          'status': 'accepted',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // 2. Insert into the friends table (trigger auto-creates the converse row).
    await _client.from('friends').insert({
      'user_id': receiverId,
      'friend_id': senderId,
      'status': 'accepted',
    });

    // 3. Insert into the friendships table (trigger auto-creates the converse row).
    await _client.from('friendships').insert({
      'user_id': receiverId,
      'friend_id': senderId,
    });
  }

  /// Declines a friend request.
  Future<void> declineFriendRequest(String requestId) async {
    await _client.from('friend_requests').update({
      'status': 'declined',
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  /// Cancels an outgoing friend request (by deleting it).
  Future<void> cancelFriendRequest(String requestId) async {
    await _client.from('friend_requests').delete().eq('id', requestId);
  }

  // ─── Remove friend ────────────────────────────────────────────────────

  /// Removes a friend. Deleting from `friends` triggers the converse-row cleanup.
  /// Also removes from `friendships`.
  Future<void> removeFriend(String userId, String friendId) async {
    // Delete from friends (trigger removes converse)
    await _client
        .from('friends')
        .delete()
        .eq('user_id', userId)
        .eq('friend_id', friendId);

    // Delete from friendships (trigger removes converse)
    await _client
        .from('friendships')
        .delete()
        .eq('user_id', userId)
        .eq('friend_id', friendId);
  }

  /// Blocks a user and removes them from friends/friendships.
  Future<void> blockUser(String userId, String targetUserId) async {
    try {
      await _client.from('blocked_users').upsert({
        'user_id': userId,
        'blocked_user_id': targetUserId,
      });
    } catch (_) {}

    await removeFriend(userId, targetUserId);
  }

  /// Unblocks a user.
  Future<void> unblockUser(String userId, String targetUserId) async {
    await _client
        .from('blocked_users')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', targetUserId);
  }

  /// Fetches the profiles of everyone [userId] has blocked.
  ///
  /// Done as two queries rather than a PostgREST embed on purpose:
  /// `blocked_users.blocked_user_id` has a foreign key to `auth.users`, not
  /// `public.profiles`, so `select('*, profiles(*)')` cannot resolve a
  /// relationship and errors out. Fetch the ids, then the profiles.
  Future<List<FriendUser>> fetchBlockedUsers(String userId) async {
    try {
      final blockRows = await _client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('user_id', userId);

      final ids = (blockRows as List)
          .map((r) => (r as Map<String, dynamic>)['blocked_user_id'] as String?)
          .whereType<String>()
          .toList();

      if (ids.isEmpty) return [];

      final profiles =
          await _client.from('profiles').select('*').inFilter('id', ids);

      final rows = (profiles as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendUser.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error fetching blocked users: $e',
          name: 'FriendsRepository');
      return [];
    }
  }

  // ─── Search users ─────────────────────────────────────────────────────

  /// Searches profiles by username or display_name. Excludes the current user.
  Future<List<FriendUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final userId = _currentUserId;
      final response = await _client
          .from('profiles')
          .select('*')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', userId ?? '')
          .limit(20);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendUser.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error searching users: $e', name: 'FriendsRepository');
      return [];
    }
  }

  // ─── Real-time subscriptions ──────────────────────────────────────────

  /// Subscribes to real-time changes on the `friends` table for [userId].
  RealtimeChannel subscribeToFriends(String userId, void Function() onUpdate) {
    developer.log(
      '[SupabaseRealtime] Subscribing to friends for user: $userId',
      name: 'FriendsRepository',
    );
    return _client
        .channel('public:friends:user:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friends',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            developer.log(
              '[SupabaseRealtime] Friends table change: ${payload.eventType}',
              name: 'FriendsRepository',
            );
            onUpdate();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            developer.log(
              '[SupabaseRealtime] Friend requests table change (receiver): ${payload.eventType}',
              name: 'FriendsRepository',
            );
            onUpdate();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (payload) {
            developer.log(
              '[SupabaseRealtime] Friend requests table change (sender): ${payload.eventType}',
              name: 'FriendsRepository',
            );
            onUpdate();
          },
        )
        .subscribe((status, error) {
          developer.log(
            '[SupabaseRealtime] Friends subscription status: $status, error: $error',
            name: 'FriendsRepository',
          );
        });
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
