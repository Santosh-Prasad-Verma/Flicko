import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../clients/dio_client.dart';

class MessageThreadService {
  final Dio _dio;

  MessageThreadService(this._dio);

  /// Create a thread from a message
  /// 
  /// [messageId] - The ID of the message to create a thread from
  /// [title] - Optional title for the thread
  /// Returns the created thread data
  Future<Map<String, dynamic>> createThread(String messageId, {String? title}) async {
    try {
      final response = await _dio.post(
        '/api/v1/messages/$messageId/thread',
        data: {
          if (title != null) 'title': title,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create thread');
      }
    } catch (e) {
      throw Exception('Failed to create thread: $e');
    }
  }

  /// Reply to a thread
  /// 
  /// [threadId] - The ID of the thread
  /// [content] - The reply content
  /// Returns the created reply data
  Future<Map<String, dynamic>> replyToThread(String threadId, String content) async {
    try {
      if (content.trim().isEmpty) {
        throw Exception('Reply content cannot be empty');
      }

      final response = await _dio.post(
        '/api/v1/threads/$threadId/replies',
        data: {'content': content.trim()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to reply to thread');
      }
    } catch (e) {
      throw Exception('Failed to reply to thread: $e');
    }
  }

  /// Get thread messages
  /// 
  /// [threadId] - The ID of the thread
  /// [limit] - Number of messages to fetch
  /// [offset] - Pagination offset
  /// Returns a list of thread messages
  Future<List<Map<String, dynamic>>> getThreadMessages(
    String threadId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/threads/$threadId/messages',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        return (response.data['messages'] as List)
            .map((m) => m as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to fetch thread messages');
      }
    } catch (e) {
      throw Exception('Failed to fetch thread messages: $e');
    }
  }

  /// Get thread details
  /// 
  /// [threadId] - The ID of the thread
  /// Returns thread details including message count
  Future<Map<String, dynamic>> getThreadDetails(String threadId) async {
    try {
      final response = await _dio.get(
        '/api/v1/threads/$threadId',
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch thread details');
      }
    } catch (e) {
      throw Exception('Failed to fetch thread details: $e');
    }
  }

  /// Follow a thread
  /// 
  /// [threadId] - The ID of the thread to follow
  /// Returns success status
  Future<bool> followThread(String threadId) async {
    try {
      final response = await _dio.post(
        '/api/v1/threads/$threadId/follow',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to follow thread');
      }
    } catch (e) {
      throw Exception('Failed to follow thread: $e');
    }
  }

  /// Unfollow a thread
  /// 
  /// [threadId] - The ID of the thread to unfollow
  /// Returns success status
  Future<bool> unfollowThread(String threadId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/threads/$threadId/follow',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to unfollow thread');
      }
    } catch (e) {
      throw Exception('Failed to unfollow thread: $e');
    }
  }

  /// Get user's followed threads
  /// 
  /// [userId] - The user's ID
  /// Returns a list of followed threads
  Future<List<Map<String, dynamic>>> getFollowedThreads(String userId) async {
    try {
      final response = await _dio.get(
        '/api/v1/users/$userId/followed-threads',
      );

      if (response.statusCode == 200) {
        return (response.data as List)
            .map((t) => t as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to fetch followed threads');
      }
    } catch (e) {
      throw Exception('Failed to fetch followed threads: $e');
    }
  }

  /// Pin a thread
  /// 
  /// [threadId] - The ID of the thread to pin
  /// Returns success status
  Future<bool> pinThread(String threadId) async {
    try {
      final response = await _dio.post(
        '/api/v1/threads/$threadId/pin',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to pin thread');
      }
    } catch (e) {
      throw Exception('Failed to pin thread: $e');
    }
  }

  /// Unpin a thread
  /// 
  /// [threadId] - The ID of the thread to unpin
  /// Returns success status
  Future<bool> unpinThread(String threadId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/threads/$threadId/pin',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to unpin thread');
      }
    } catch (e) {
      throw Exception('Failed to unpin thread: $e');
    }
  }
}

/// Provider for MessageThreadService
final messageThreadServiceProvider = Provider<MessageThreadService>((ref) {
  return MessageThreadService(ref.watch(dioProvider));
});
