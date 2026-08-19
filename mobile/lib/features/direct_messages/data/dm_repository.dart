import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/features/e2ee/application/e2ee_session.dart';
import 'package:mobile/data/models/user_model.dart';

final dmRepositoryProvider = Provider<DMRepository>((ref) {
  E2EESession? e2ee;
  try {
    e2ee = ref.watch(e2eeSessionProvider);
  } catch (_) {}
  return DMRepository(
    ref.watch(dioProvider),
    ref.watch(appwriteStorageServiceProvider),
    e2ee,
  );
});

class DMRepository {
  final Dio _dio;
  final AppwriteStorageService _appwriteStorage;
  final E2EESession? _e2ee;

  DMRepository(this._dio, this._appwriteStorage, this._e2ee);

  RealtimeChannel? subscribeToDMs(String userId, Function onNewMessage) {
    return RealtimeChannel();
  }

  RealtimeChannel? subscribeToConversation(String myId, String otherUserId, Function onMessage) {
    return RealtimeChannel();
  }

  void unsubscribe([dynamic channel]) {}

  Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    final response = await _dio.get('/api/v1/users/search', queryParameters: {'q': query});
    return (response.data as List)
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> fetchUserProfile(String userId) async {
    final response = await _dio.get('/api/v1/users/$userId');
    return UserModel.fromJson(response.data);
  }

  Future<List<DMMessage>> fetchRecentMessages(String userId) async {
    try {
      final response = await _dio.get('/api/v1/e2ee/envelopes/pull');
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return Future.wait(rows.map(decodeMessageRow));
    } catch (e) {
      return [];
    }
  }

  Future<List<DMMessage>> fetchMessagesWithPagination(
    String myId,
    String otherUserId, {
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get('/api/v1/e2ee/envelopes/pull', queryParameters: {
        'other_user_id': otherUserId,
        'limit': limit,
        if (before != null) 'before': before.toIso8601String(),
      });
      final rows = (response.data as List).cast<Map<String, dynamic>>();
      return Future.wait(rows.map(decodeMessageRow));
    } catch (e) {
      return [];
    }
  }

  Future<DMMessage> sendMessage({
    required String senderId,
    required String recipientId,
    required String content,
    List<DMAttachment>? attachments,
  }) async {
    final response = await _dio.post('/api/v1/e2ee/envelopes', data: {
      'recipient_id': recipientId,
      'content': content,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
    });
    return decodeMessageRow(response.data as Map<String, dynamic>);
  }

  Future<DMMessage> decodeMessageRow(Map<String, dynamic> row) async {
    return DMMessage.fromJson(row);
  }

  Future<String> uploadAttachment(File file, String userId, String conversationId) async {
    return await _appwriteStorage.uploadAttachment(file, userId, conversationId);
  }

  Future<void> editMessage(String messageId, String otherUserId, String content) async {
    await _dio.patch('/api/v1/e2ee/envelopes/$messageId', data: {'content': content});
  }

  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/api/v1/e2ee/envelopes/$messageId');
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    await _dio.post('/api/v1/e2ee/envelopes/$messageId/reactions', data: {'emoji': emoji});
  }
}
