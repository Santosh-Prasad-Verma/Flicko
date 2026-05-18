import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/dio_client.dart';
import '../domain/music_models.dart';

/// Client for the Go backend's Sonic Drip endpoints.
/// All Spotify interactions go through the backend — never directly from Flutter.
class SpotifyApiClient {
  final Dio _dio;

  SpotifyApiClient(this._dio);

  // ── Session ────────────────────────────────────────────────────────────────

  /// Save Spotify session cookies captured from the WebView.
  Future<void> saveSession({
    required Map<String, String> cookies,
    required String displayName,
    String product = 'free',
  }) async {
    AppConfig.requireBackendBaseUrl();
    await _dio.post('/music/session', data: {
      'cookies': cookies,
      'display_name': displayName,
      'product': product,
    });
  }

  /// Get session info (no cookies returned).
  Future<Map<String, dynamic>> getSession() async {
    AppConfig.requireBackendBaseUrl();
    final response = await _dio.get('/music/session');
    return response.data as Map<String, dynamic>;
  }

  /// Disconnect Spotify.
  Future<void> deleteSession() async {
    AppConfig.requireBackendBaseUrl();
    await _dio.delete('/music/session');
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Search the Spotify catalog.
  Future<List<Track>> search(String query, {int limit = 25}) async {
    AppConfig.requireBackendBaseUrl();
    final response = await _dio.get('/music/search', queryParameters: {
      'q': query,
      'limit': limit,
    });

    final tracks = (response.data['tracks'] as List?) ?? [];
    return tracks
        .map((t) => _trackFromJson(t as Map<String, dynamic>))
        .toList();
  }

  // ── Player ─────────────────────────────────────────────────────────────────

  /// Play a track. Generates an idempotency key automatically.
  Future<void> play(String trackId, {String deviceId = ''}) async {
    AppConfig.requireBackendBaseUrl();
    await _dio.post('/music/player/play', data: {
      'track_id': trackId,
      'idempotency_key': _uuid(),
      'device_id': deviceId,
    });
  }

  Future<void> pause() {
    AppConfig.requireBackendBaseUrl();
    return _dio.post('/music/player/pause');
  }

  Future<void> resume() {
    AppConfig.requireBackendBaseUrl();
    return _dio.post('/music/player/resume');
  }

  Future<void> skipNext() {
    AppConfig.requireBackendBaseUrl();
    return _dio.post('/music/player/skip-next');
  }

  Future<void> seek(int positionMs) async {
    AppConfig.requireBackendBaseUrl();
    await _dio.post('/music/player/seek', data: {'position_ms': positionMs});
  }

  Future<void> setVolume(double volume) async {
    AppConfig.requireBackendBaseUrl();
    await _dio.post('/music/player/volume', data: {'volume': volume});
  }

  Future<Map<String, dynamic>> getState() async {
    AppConfig.requireBackendBaseUrl();
    final response = await _dio.get('/music/player/state');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    AppConfig.requireBackendBaseUrl();
    final response = await _dio.get('/music/player/devices');
    return List<Map<String, dynamic>>.from(response.data['devices'] ?? []);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Track _trackFromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      artistName: json['artist'] ?? 'Unknown',
      albumName: json['album'],
      durationMs: json['duration_ms'],
      imageUrl: json['image_url'],
      source: 'spotify',
    );
  }

  String _uuid() {
    // Simple UUID v4 without external package
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${now.toRadixString(16)}-${(now * 31).toRadixString(16)}';
  }
}

final spotifyApiClientProvider = Provider<SpotifyApiClient>((ref) {
  return SpotifyApiClient(ref.watch(dioProvider));
});
