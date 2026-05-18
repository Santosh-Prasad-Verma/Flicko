import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/music_models.dart';

/// Abstract interface — swap iTunes for Spotify backend without touching UI.
abstract class MusicRepository {
  Future<List<Track>> search(String query, {MusicType type, int limit});
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  // Use a plain Dio instance — iTunes is a public API, no auth or base URL needed.
  return ItunesMusicRepository(Dio());
});

/// iTunes Search API implementation (no auth required).
/// Replace with SpotifyMusicRepository once backend is live.
class ItunesMusicRepository implements MusicRepository {
  final Dio _dio;
  static const _baseUrl = 'https://itunes.apple.com/search';

  ItunesMusicRepository(this._dio);

  @override
  Future<List<Track>> search(
    String query, {
    MusicType type = MusicType.track,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];

    final entity = switch (type) {
      MusicType.track => 'song',
      MusicType.album => 'album',
      MusicType.artist => 'musicArtist',
    };

    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'term': query.trim(),
        'media': 'music',
        'entity': entity,
        'limit': limit,
      });

      if (response.statusCode != 200) return [];
      final results = (response.data['results'] as List?) ?? [];
      return results
          .whereType<Map<String, dynamic>>()
          .map((item) => _toTrack(item, type))
          .toList();
    } catch (e) {
      // Catch all errors including cast exceptions
      return [];
    }
  }

  Track _toTrack(Map<String, dynamic> item, MusicType type) {
    return switch (type) {
      MusicType.track => Track(
          id: item['trackId']?.toString() ?? '',
          name: item['trackName'] ?? 'Unknown Track',
          artistName: item['artistName'] ?? 'Unknown Artist',
          albumName: item['collectionName'],
          durationMs: item['trackTimeMillis'],
          imageUrl: (item['artworkUrl100'] as String?)
              ?.replaceAll('100x100bb', '400x400bb'),
          previewUrl: item['previewUrl'],
          externalUrl: item['trackViewUrl'],
        ),
      MusicType.album => Track(
          id: item['collectionId']?.toString() ?? '',
          name: item['collectionName'] ?? 'Unknown Album',
          artistName: item['artistName'] ?? 'Unknown Artist',
          imageUrl: (item['artworkUrl100'] as String?)
              ?.replaceAll('100x100bb', '400x400bb'),
          externalUrl: item['collectionViewUrl'],
        ),
      MusicType.artist => Track(
          id: item['artistId']?.toString() ?? '',
          name: item['artistName'] ?? 'Unknown Artist',
          artistName: item['artistName'] ?? 'Unknown Artist',
          externalUrl: item['artistViewUrl'],
        ),
    };
  }
}
