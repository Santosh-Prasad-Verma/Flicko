import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../clients/dio_client.dart';

/// Message Delete Service for deleting messages
/// 
/// Handles deleting messages with proper permissions and confirmation.
class MessageDeleteService {
  final Dio _dio;

  MessageDeleteService(this._dio);



  /// Delete a message
  /// 
  /// [messageId] - The ID of the message to delete
  /// Returns success status
  Future<bool> deleteMessage(String messageId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/messages/$messageId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to delete message');
      }
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Bulk delete messages
  /// 
  /// [messageIds] - List of message IDs to delete
  /// Returns success status
  Future<bool> bulkDeleteMessages(List<String> messageIds) async {
    try {
      final response = await _dio.post(
        '/api/v1/messages/bulk-delete',
        data: {'message_ids': messageIds},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to bulk delete messages');
      }
    } catch (e) {
      throw Exception('Failed to bulk delete messages: $e');
    }
  }

  /// Check if a message can be deleted
  /// 
  /// [message] - The message data
  /// [currentUserId] - The current user's ID
  /// [userPermissions] - The user's permissions
  /// Returns true if the message can be deleted
  bool canDeleteMessage(
    Map<String, dynamic> message,
    String currentUserId, {
    List<String>? userPermissions,
  }) {
    // Check if user is the author
    final authorId = message['author_id'] as String?;
    if (authorId == currentUserId) {
      return true;
    }

    // Check if user has admin/moderator permissions
    if (userPermissions != null) {
      if (userPermissions.contains('admin') || 
          userPermissions.contains('moderator') ||
          userPermissions.contains('manage_messages')) {
        return true;
      }
    }

    return false;
  }

  /// Soft delete a message (mark as deleted but keep in database)
  /// 
  /// [messageId] - The ID of the message to soft delete
  /// Returns success status
  Future<bool> softDeleteMessage(String messageId) async {
    try {
      final response = await _dio.patch(
        '/api/v1/messages/$messageId',
        data: {'deleted': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to soft delete message');
      }
    } catch (e) {
      throw Exception('Failed to soft delete message: $e');
    }
  }

  /// Restore a deleted message
  /// 
  /// [messageId] - The ID of the message to restore
  /// Returns success status
  Future<bool> restoreMessage(String messageId) async {
    try {
      final response = await _dio.patch(
        '/api/v1/messages/$messageId',
        data: {'deleted': false},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to restore message');
      }
    } catch (e) {
      throw Exception('Failed to restore message: $e');
    }
  }
}

/// Provider for MessageDeleteService
final messageDeleteServiceProvider = Provider<MessageDeleteService>((ref) {
  return MessageDeleteService(ref.watch(dioProvider));
});
