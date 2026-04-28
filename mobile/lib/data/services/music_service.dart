import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/music_model.dart';
import 'package:mobile/data/clients/dio_client.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService(ref.watch(dioProvider));
});

class MusicService {
  final Dio _dio;

  MusicService(this._dio);

  static const String _baseUrl = 'https://itunes.apple.com/search';

  /// Search for music using iTunes API
  Future<List<MusicItem>> searchMusic({
    required String query,
    MusicType type = MusicType.track,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    final String entity;
    switch (type) {
      case MusicType.track:
        entity = 'song';
        break;
      case MusicType.album:
        entity = 'album';
        break;
      case MusicType.artist:
        entity = 'musicArtist';
        break;
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'term': query.trim(),
          'media': 'music',
          'entity': entity,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['results'] is List) {
          return (data['results'] as List).map((item) => _normalizeItem(item, type)).toList();
        }
      }
      return [];
    } catch (e) {
      // Log error in production
      return [];
    }
  }

  MusicItem _normalizeItem(Map<String, dynamic> item, MusicType type) {
    switch (type) {
      case MusicType.track:
        return MusicItem(
          id: item['trackId']?.toString() ?? '',
          type: MusicType.track,
          name: item['trackName'] ?? 'Unknown Track',
          artistName: item['artistName'] ?? 'Unknown Artist',
          albumName: item['collectionName'],
          durationMs: item['trackTimeMillis'],
          imageUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100', '300x300'),
          previewUrl: item['previewUrl'],
          externalUrl: item['trackViewUrl'],
        );
      case MusicType.album:
        return MusicItem(
          id: item['collectionId']?.toString() ?? '',
          type: MusicType.album,
          name: item['collectionName'] ?? 'Unknown Album',
          artistName: item['artistName'] ?? 'Unknown Artist',
          imageUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100', '300x300'),
          externalUrl: item['collectionViewUrl'],
        );
      case MusicType.artist:
        return MusicItem(
          id: item['artistId']?.toString() ?? '',
          type: MusicType.artist,
          name: item['artistName'] ?? 'Unknown Artist',
          artistName: item['artistName'] ?? 'Unknown Artist',
          externalUrl: item['artistViewUrl'],
        );
    }
  }
}
