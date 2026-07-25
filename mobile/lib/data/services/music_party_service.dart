import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/models/music_party_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final musicPartyServiceProvider = Provider<MusicPartyService>((ref) {
  return MusicPartyService(ref.watch(dioProvider));
});

class MusicPartyService {
  final Dio _dio;

  MusicPartyService(this._dio);

  // ── Sessions ─────────────────────────────────────────────────

  Future<MusicPartySession?> createSession({
    required String roomId,
    String rotationMode = 'manual',
    double voteSkipThreshold = 0.5,
    int maxListeners = 25,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions',
        data: {
          'room_id': roomId,
          'rotation_mode': rotationMode,
          'settings': {
            'vote_skip_threshold': voteSkipThreshold,
            'max_listeners': maxListeners,
            'allow_dupes': true,
          },
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error creating music party session: $e');
    }
    return null;
  }

  Future<MusicPartySession?> getSession(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.get('/mp/sessions/$sessionId');
      if (response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error getting music party session: $e');
    }
    return null;
  }

  Future<MusicPartySession?> updateSession(
    String sessionId, {
    String? rotationMode,
    double? voteSkipThreshold,
    int? maxListeners,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final data = <String, dynamic>{};
      if (rotationMode != null) data['rotation_mode'] = rotationMode;
      if (voteSkipThreshold != null) data['vote_skip_threshold'] = voteSkipThreshold;
      if (maxListeners != null) data['max_listeners'] = maxListeners;

      final response = await _dio.patch('/mp/sessions/$sessionId', data: data);
      if (response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error updating music party session: $e');
    }
    return null;
  }

  Future<bool> endSession(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.delete('/mp/sessions/$sessionId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error ending music party session: $e');
    }
    return false;
  }

  // ── Participants ─────────────────────────────────────────────

  Future<MusicPartyJoinResponse?> joinSession({
    required String sessionId,
    String spotifyTier = 'none',
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions/$sessionId/join',
        data: {'spotify_tier': spotifyTier},
      );

      if (response.statusCode == 200) {
        return MusicPartyJoinResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error joining music party session: $e');
    }
    return null;
  }

  Future<bool> leaveSession(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.post('/mp/sessions/$sessionId/leave');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error leaving music party session: $e');
    }
    return false;
  }

  // ── Queue ────────────────────────────────────────────────────

  Future<MusicPartyQueueItem?> addToQueue({
    required String sessionId,
    required String spotifyUri,
    String? title,
    String? artist,
    int? durationMs,
    String? albumArtUrl,
    String? previewUrl,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions/$sessionId/queue',
        data: {
          'spotify_uri': spotifyUri,
          if (title != null) 'title': title,
          if (artist != null) 'artist': artist,
          if (durationMs != null) 'duration_ms': durationMs,
          if (albumArtUrl != null) 'album_art_url': albumArtUrl,
          if (previewUrl != null) 'preview_url': previewUrl,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return MusicPartyQueueItem.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error adding to music party queue: $e');
    }
    return null;
  }

  Future<List<MusicPartyQueueItem>> getQueue(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return [];

      final response = await _dio.get('/mp/sessions/$sessionId/queue');
      if (response.statusCode == 200) {
        final list = response.data as List;
        return list
            .map((e) => MusicPartyQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting music party queue: $e');
    }
    return [];
  }

  Future<bool> reorderQueueItem(String sessionId, String itemId, double position) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.patch(
        '/mp/sessions/$sessionId/queue/$itemId',
        data: {'position': position},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error reordering queue item: $e');
    }
    return false;
  }

  Future<bool> removeQueueItem(String sessionId, String itemId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.delete('/mp/sessions/$sessionId/queue/$itemId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error removing queue item: $e');
    }
    return false;
  }

  // ── Playback Control ─────────────────────────────────────────

  Future<MusicPartySession?> play(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post('/mp/sessions/$sessionId/play');
      if (response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error starting playback: $e');
    }
    return null;
  }

  Future<MusicPartySession?> skip(String sessionId, {String reason = 'dj'}) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions/$sessionId/skip',
        data: {'reason': reason},
      );
      if (response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error skipping track: $e');
    }
    return null;
  }

  Future<MusicPartySession?> handoffDJ(String sessionId, String toUserId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions/$sessionId/dj',
        data: {'to_user_id': toUserId},
      );
      if (response.statusCode == 200) {
        return MusicPartySession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error handing off DJ: $e');
    }
    return null;
  }

  // ── Anchor ───────────────────────────────────────────────────

  Future<bool> pushAnchor({
    required String sessionId,
    required String trackUri,
    required int positionMs,
    required bool playing,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return false;
      final response = await _dio.post(
        '/mp/sessions/$sessionId/anchor',
        data: {
          'track_uri': trackUri,
          'position_ms': positionMs,
          'playing': playing,
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error pushing anchor: $e');
    }
    return false;
  }

  Future<MusicPartyAnchor?> getAnchor(String sessionId) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.get('/mp/sessions/$sessionId/anchor');
      if (response.statusCode == 200) {
        return MusicPartyAnchor.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error getting anchor: $e');
    }
    return null;
  }

  // ── Vibes ────────────────────────────────────────────────────

  Future<SkipVoteStatus?> addVibe({
    required String sessionId,
    required String queueItemId,
    required String kind,
  }) async {
    try {
      if (!AppConfig.hasApiBaseUrl) return null;

      final response = await _dio.post(
        '/mp/sessions/$sessionId/vibe',
        data: {
          'queue_item_id': queueItemId,
          'kind': kind,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return SkipVoteStatus.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      debugPrint('Error adding vibe: $e');
    }
    return null;
  }
}
