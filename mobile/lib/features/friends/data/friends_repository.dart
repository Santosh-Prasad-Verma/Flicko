import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/features/friends/domain/friends_models.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(dioProvider));
});

final friendsListProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.fetchFriends('');
});

final pendingRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.fetchPendingRequests('');
});

final blockedUsersProvider = FutureProvider.autoDispose<List<FriendUser>>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.fetchBlockedUsers('');
});

class FriendsRepository {
  final Dio _dio;

  FriendsRepository(this._dio);

  String? get currentUserId => null;

  RealtimeChannel subscribeToFriends(String userId, void Function() onUpdate) => RealtimeChannel();
  void unsubscribe([dynamic channel]) {}

  Future<List<Friend>> fetchFriends(String userId) async {
    try {
      final response = await _dio.get('/api/v1/users/@me/friends');
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return rows.map((row) => Friend.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error fetching friends: $e', name: 'FriendsRepository');
      return [];
    }
  }

  Future<List<FriendRequest>> fetchPendingRequests(String userId) async {
    try {
      final response = await _dio.get('/api/v1/users/@me/friend-requests');
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendRequest.fromJson(row, userId)).toList();
    } catch (e) {
      developer.log('Error fetching friend requests: $e', name: 'FriendsRepository');
      return [];
    }
  }

  Future<void> sendFriendRequest({
    required String senderId,
    required String receiverId,
    String? message,
  }) async {
    await _dio.post('/api/v1/users/@me/friend-requests', data: {
      'receiver_id': receiverId,
      if (message != null) 'message': message,
    });
  }

  Future<void> acceptFriendRequest({
    required String requestId,
    required String senderId,
    required String receiverId,
  }) async {
    await _dio.post('/api/v1/users/@me/friend-requests/$requestId/accept');
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _dio.post('/api/v1/users/@me/friend-requests/$requestId/decline');
  }

  Future<void> cancelFriendRequest(String requestId) async {
    await _dio.delete('/api/v1/users/@me/friend-requests/$requestId');
  }

  Future<void> removeFriend(String userId, String friendId) async {
    await _dio.delete('/api/v1/users/@me/friends/$friendId');
  }

  Future<void> blockUser(String userId, String targetUserId) async {
    await _dio.post('/api/v1/users/@me/blocked/$targetUserId');
  }

  Future<void> unblockUser(String userId, String targetUserId) async {
    await _dio.delete('/api/v1/users/@me/blocked/$targetUserId');
  }

  Future<List<FriendUser>> fetchBlockedUsers(String userId) async {
    try {
      final response = await _dio.get('/api/v1/users/@me/blocked');
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendUser.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error fetching blocked users: $e', name: 'FriendsRepository');
      return [];
    }
  }

  Future<List<FriendUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _dio.get('/api/v1/users/search', queryParameters: {'q': query});
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return rows.map((row) => FriendUser.fromJson(row)).toList();
    } catch (e) {
      developer.log('Error searching users: $e', name: 'FriendsRepository');
      return [];
    }
  }
}
