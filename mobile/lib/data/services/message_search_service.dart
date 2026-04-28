import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';

/// Message Search Service for searching messages
/// 
/// Handles searching messages across channels, servers, and DMs.
class MessageSearchService {
  final Dio _dio;
  final String _apiBaseUrl;

  MessageSearchService()
      : _dio = Dio(),
        _apiBaseUrl = AppConfig.apiBaseUrl;

  /// Search messages
  /// 
  /// [query] - The search query
  /// [channelId] - Optional channel ID to limit search to
  /// [serverId] - Optional server ID to limit search to
  /// [userId] - Optional user ID to search for messages by specific user
  /// [limit] - Number of results to return
  /// [offset] - Pagination offset
  /// Returns a list of matching messages
  Future<List<Map<String, dynamic>>> searchMessages({
    required String query,
    String? channelId,
    String? serverId,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty) {
        throw Exception('Search query cannot be empty');
      }

      final queryParams = <String, dynamic>{
        'q': query.trim(),
        'limit': limit,
        'offset': offset,
      };

      if (channelId != null) queryParams['channel_id'] = channelId;
      if (serverId != null) queryParams['server_id'] = serverId;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _dio.get(
        '$_apiBaseUrl/messages/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return (response.data['messages'] as List)
            .map((m) => m as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to search messages');
      }
    } catch (e) {
      throw Exception('Failed to search messages: $e');
    }
  }

  /// Advanced search with filters
  /// 
  /// [query] - The search query
  /// [filters] - Search filters (hasImage, hasLink, etc.)
  /// [startDate] - Optional start date filter
  /// [endDate] - Optional end date filter
  /// [limit] - Number of results to return
  /// [offset] - Pagination offset
  /// Returns a list of matching messages
  Future<List<Map<String, dynamic>>> advancedSearch({
    required String query,
    Map<String, dynamic>? filters,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty) {
        throw Exception('Search query cannot be empty');
      }

      final queryParams = <String, dynamic>{
        'q': query.trim(),
        'limit': limit,
        'offset': offset,
      };

      if (filters != null) {
        queryParams.addAll(filters);
      }

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      final response = await _dio.get(
        '$_apiBaseUrl/messages/search/advanced',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return (response.data['messages'] as List)
            .map((m) => m as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to perform advanced search');
      }
    } catch (e) {
      throw Exception('Failed to perform advanced search: $e');
    }
  }

  /// Get search suggestions
  /// 
  /// [query] - The search query
  /// Returns a list of search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final response = await _dio.get(
        '$_apiBaseUrl/messages/search/suggestions',
        queryParameters: {'q': query.trim()},
      );

      if (response.statusCode == 200) {
        return (response.data['suggestions'] as List)
            .map((s) => s as String)
            .toList();
      } else {
        throw Exception('Failed to fetch search suggestions');
      }
    } catch (e) {
      throw Exception('Failed to fetch search suggestions: $e');
    }
  }

  /// Get recent searches for the current user
  /// 
  /// Returns a list of recent search queries
  Future<List<String>> getRecentSearches() async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/messages/search/recent',
      );

      if (response.statusCode == 200) {
        return (response.data['recent_searches'] as List)
            .map((s) => s as String)
            .toList();
      } else {
        throw Exception('Failed to fetch recent searches');
      }
    } catch (e) {
      throw Exception('Failed to fetch recent searches: $e');
    }
  }

  /// Save a search query to recent searches
  /// 
  /// [query] - The search query to save
  /// Returns success status
  Future<bool> saveRecentSearch(String query) async {
    try {
      if (query.trim().isEmpty) {
        return false;
      }

      final response = await _dio.post(
        '$_apiBaseUrl/messages/search/recent',
        data: {'query': query.trim()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to save recent search');
      }
    } catch (e) {
      throw Exception('Failed to save recent search: $e');
    }
  }

  /// Clear recent searches
  /// 
  /// Returns success status
  Future<bool> clearRecentSearches() async {
    try {
      final response = await _dio.delete(
        '$_apiBaseUrl/messages/search/recent',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to clear recent searches');
      }
    } catch (e) {
      throw Exception('Failed to clear recent searches: $e');
    }
  }

  /// Validate search query
  /// 
  /// [query] - The search query to validate
  /// Returns validation result
  ({bool isValid, String? error}) validateQuery(String query) {
    if (query.trim().isEmpty) {
      return (isValid: false, error: 'Search query cannot be empty');
    }

    if (query.length > 500) {
      return (isValid: false, error: 'Search query too long (max 500 characters)');
    }

    return (isValid: true, error: null);
  }
}

/// Provider for MessageSearchService
final messageSearchServiceProvider = Provider<MessageSearchService>((ref) {
  return MessageSearchService();
});
