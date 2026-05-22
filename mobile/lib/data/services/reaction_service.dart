import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../clients/dio_client.dart';

class ReactionService {
  final Dio _dio;

  ReactionService(this._dio);

  /// Add a reaction to a message
  /// 
  /// [messageId] - The ID of the message
  /// [emoji] - The emoji to react with
  /// Returns the updated reaction data
  Future<Map<String, dynamic>> addReaction(String messageId, String emoji) async {
    try {
      final response = await _dio.post(
        '/v1/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to add reaction');
      }
    } catch (e) {
      throw Exception('Failed to add reaction: $e');
    }
  }

  /// Remove a reaction from a message
  /// 
  /// [messageId] - The ID of the message
  /// [emoji] - The emoji to remove
  /// Returns the updated reaction data
  Future<Map<String, dynamic>> removeReaction(String messageId, String emoji) async {
    try {
      final response = await _dio.delete(
        '/v1/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to remove reaction');
      }
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  /// Toggle a reaction (add if not present, remove if present)
  /// 
  /// [messageId] - The ID of the message
  /// [emoji] - The emoji to toggle
  /// [currentUserHasReacted] - Whether the current user has already reacted
  /// Returns the updated reaction data
  Future<Map<String, dynamic>> toggleReaction(
    String messageId,
    String emoji,
    bool currentUserHasReacted,
  ) async {
    if (currentUserHasReacted) {
      return await removeReaction(messageId, emoji);
    } else {
      return await addReaction(messageId, emoji);
    }
  }

  /// Get all reactions for a message
  /// 
  /// [messageId] - The ID of the message
  /// Returns a list of reactions
  Future<List<Map<String, dynamic>>> getReactions(String messageId) async {
    try {
      final response = await _dio.get(
        '/v1/messages/$messageId/reactions',
      );

      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to fetch reactions');
      }
    } catch (e) {
      throw Exception('Failed to fetch reactions: $e');
    }
  }

  /// Get common emojis for quick reaction
  /// 
  /// Returns a list of common emoji strings
  List<String> getCommonEmojis() {
    return [
      '👍',
      '👎',
      '❤️',
      '😂',
      '😮',
      '😢',
      '😡',
      '🎉',
      '🔥',
      '👀',
      '🚀',
      '💯',
      '✨',
      '🙌',
      '💪',
    ];
  }
}

/// Provider for ReactionService
final reactionServiceProvider = Provider<ReactionService>((ref) {
  return ReactionService(ref.watch(dioProvider));
});
