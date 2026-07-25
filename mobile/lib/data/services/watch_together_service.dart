import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/models/watch_together_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final watchTogetherServiceProvider = Provider<WatchTogetherService>((ref) {
  return WatchTogetherService(ref.watch(dioProvider));
});

class WatchTogetherService {
  final Dio _dio;

  WatchTogetherService(this._dio);

  Future<WatchTogetherSession?> createSession({
    required String roomId,
    required String url,
    required String title,
    required String kind,
    int maxViewers = 12,
    bool allowSeekByViewer = true,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/api/v1/wt/sessions',
        data: {
          'room_id': roomId,
          'media': {
            'kind': kind,
            'url': url,
            'title': title,
          },
          'settings': {
            'max_viewers': maxViewers,
            'allow_seek_by_viewer': allowSeekByViewer,
          },
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return WatchTogetherSession.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      debugPrint('Error creating watch together session: $e');
    }
    return null;
  }

  Future<WatchTogetherJoinResponse?> joinSession({
    required String sessionId,
    required String username,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/api/v1/wt/sessions/$sessionId/join',
        queryParameters: {'username': username},
      );

      if (response.statusCode == 200) {
        return WatchTogetherJoinResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      debugPrint('Error joining watch together session: $e');
    }
    return null;
  }

  Future<bool> leaveSession(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.post('/api/v1/wt/sessions/$sessionId/leave');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error leaving watch together session: $e');
    }
    return false;
  }

  Future<bool> endSession(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.delete('/api/v1/wt/sessions/$sessionId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error ending watch together session: $e');
    }
    return false;
  }

  Future<bool> pushAnchor({
    required String sessionId,
    required int positionMs,
    required bool playing,
    double rate = 1.0,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.post(
        '/api/v1/wt/sessions/$sessionId/anchor',
        data: {
          'position_ms': positionMs,
          'playing': playing,
          'rate': rate,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error pushing sync anchor: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getAnchor(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;
      final response = await _dio.get('/api/v1/wt/sessions/$sessionId/anchor');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      debugPrint('Error getting sync anchor: $e');
    }
    return null;
  }

  Future<bool> transferHost(String sessionId, String toUserId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.post(
        '/api/v1/wt/sessions/$sessionId/host',
        data: {
          'to_user_id': toUserId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error transferring host: $e');
    }
    return false;
  }
}
