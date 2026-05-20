import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../clients/dio_client.dart';

/// Message Edit Service for editing messages
/// 
/// Handles editing messages with proper validation and timestamp tracking.
class MessageEditService {
  final Dio _dio;

  MessageEditService(this._dio);



  /// Edit a message
  /// 
  /// [messageId] - The ID of the message to edit
  /// [newContent] - The new content for the message
  /// Returns the updated message data
  Future<Map<String, dynamic>> editMessage(String messageId, String newContent) async {
    try {
      // Validate content
      if (newContent.trim().isEmpty) {
        throw Exception('Message content cannot be empty');
      }

      if (newContent.length > 4000) {
        throw Exception('Message content too long (max 4000 characters)');
      }

      final response = await _dio.patch(
        '/api/v1/messages/$messageId',
        data: {
          'content': newContent.trim(),
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to edit message');
      }
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  /// Check if a message can be edited
  /// 
  /// [message] - The message data
  /// [currentUserId] - The current user's ID
  /// [timeLimit] - Time limit in minutes (default: 15 minutes)
  /// Returns true if the message can be edited
  bool canEditMessage(Map<String, dynamic> message, String currentUserId, {int timeLimit = 15}) {
    // Check if user is the author
    final authorId = message['author_id'] as String?;
    if (authorId != currentUserId) {
      return false;
    }

    // Check if message is too old
    final createdAt = message['created_at'] as String?;
    if (createdAt == null) return false;

    final creationTime = DateTime.parse(createdAt);
    final now = DateTime.now();
    final timeDiff = now.difference(creationTime).inMinutes;

    return timeDiff <= timeLimit;
  }

  /// Get edit history for a message
  /// 
  /// [messageId] - The ID of the message
  /// Returns a list of edit history entries
  Future<List<Map<String, dynamic>>> getEditHistory(String messageId) async {
    try {
      final response = await _dio.get(
        '/api/v1/messages/$messageId/edit-history',
      );

      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to fetch edit history');
      }
    } catch (e) {
      throw Exception('Failed to fetch edit history: $e');
    }
  }

  /// Validate message content before editing
  /// 
  /// [content] - The message content to validate
  /// Returns a validation result with error message if invalid
  ({bool isValid, String? error}) validateContent(String content) {
    if (content.trim().isEmpty) {
      return (isValid: false, error: 'Message content cannot be empty');
    }

    if (content.length > 4000) {
      return (isValid: false, error: 'Message content too long (max 4000 characters)');
    }

    // Check for potential XSS or injection attempts
    if (content.contains('<script>') || content.contains('javascript:')) {
      return (isValid: false, error: 'Invalid content detected');
    }

    return (isValid: true, error: null);
  }
}

/// Provider for MessageEditService
final messageEditServiceProvider = Provider<MessageEditService>((ref) {
  return MessageEditService(ref.watch(dioProvider));
});
