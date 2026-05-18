import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/music_models.dart';

abstract class MusicRepository {
  Future<List<Track>> search(String query, {MusicType type, int limit});
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return HybridMusicRepository(Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 12),
    responseType: ResponseType.json,
    headers: {
      'User-Agent': 'Flicko/1.0',
      'Accept': 'application/json,text/javascript,*/*',
    },
  )));
});

/// iTunes-backed music search.
/// iTunes is reliable, returns many results, and provides 30-second preview URLs
/// that play via just_audio. No auth, no rate limit issues, works globally.
class HybridMusicRepository implements MusicRepository {
  final Dio _dio;

  static const _itunesBase = 'https://itunes.apple.com/search';

  HybridMusicRepository(this._dio);

  @override
  Future<List<Track>> search(
    String query, {
    MusicType type = MusicType.track,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];
    return _searchItunes(query, type, limit);
  }

  Future<List<Track>> _searchItunes(
      String query, MusicType type, int limit) async {
    final entity = switch (type) {
      MusicType.track => 'song',
      MusicType.album => 'album',
      MusicType.artist => 'musicArtist',
    };

    try {
      dev.log('iTunes search: "$query" type=$entity', name: 'sonic-drip');

      final res = await _dio.get(
        _itunesBase,
        queryParameters: {
          'term': query.trim(),
          'media': 'music',
          'entity': entity,
          'limit': limit,
        },
        options: Options(
          // iTunes sometimes returns text/javascript content-type;
          // accept everything and parse manually if needed.
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      dev.log('iTunes status=${res.statusCode}', name: 'sonic-drip');

      if (res.statusCode != 200) {
        dev.log('iTunes non-200: ${res.data}', name: 'sonic-drip');
        return [];
      }

      Map<String, dynamic>? data;
      final raw = res.data;
      if (raw is Map<String, dynamic>) {
        data = raw;
      } else if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (e) {
          dev.log('iTunes parse error: $e', name: 'sonic-drip');
          return [];
        }
      }

      final results = (data?['results'] as List?) ?? const [];
      dev.log('iTunes raw results: ${results.length}', name: 'sonic-drip');

      final tracks = <Track>[];
      for (final item in results) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final track = _mapItunesItem(m, type);
        if (track != null) tracks.add(track);
      }

      dev.log('iTunes mapped tracks: ${tracks.length}', name: 'sonic-drip');
      return tracks;
    } on DioException catch (e) {
      dev.log('iTunes Dio error: ${e.type} ${e.message}', name: 'sonic-drip');
      rethrow;
    } catch (e, st) {
      dev.log('iTunes error: $e\n$st', name: 'sonic-drip');
      return [];
    }
  }

  Track? _mapItunesItem(Map<String, dynamic> item, MusicType type) {
    try {
      switch (type) {
        case MusicType.track:
          final id = item['trackId']?.toString();
          if (id == null || id.isEmpty) return null;
          return Track(
            id: id,
            name: (item['trackName'] as String?) ?? 'Unknown Track',
            artistName: (item['artistName'] as String?) ?? 'Unknown Artist',
            albumName: item['collectionName'] as String?,
            durationMs: (item['trackTimeMillis'] as num?)?.toInt(),
            imageUrl: (item['artworkUrl100'] as String?)
                ?.replaceAll('100x100bb', '600x600bb'),
            previewUrl: item['previewUrl'] as String?,
            externalUrl: item['trackViewUrl'] as String?,
            source: 'itunes',
          );
        case MusicType.album:
          final id = item['collectionId']?.toString();
          if (id == null || id.isEmpty) return null;
          return Track(
            id: id,
            name: (item['collectionName'] as String?) ?? 'Unknown Album',
            artistName: (item['artistName'] as String?) ?? 'Unknown Artist',
            imageUrl: (item['artworkUrl100'] as String?)
                ?.replaceAll('100x100bb', '600x600bb'),
            externalUrl: item['collectionViewUrl'] as String?,
            source: 'itunes',
          );
        case MusicType.artist:
          final id = item['artistId']?.toString();
          if (id == null || id.isEmpty) return null;
          return Track(
            id: id,
            name: (item['artistName'] as String?) ?? 'Unknown Artist',
            artistName: (item['artistName'] as String?) ?? 'Unknown Artist',
            externalUrl: item['artistViewUrl'] as String?,
            source: 'itunes',
          );
      }
    } catch (e) {
      dev.log('iTunes map error: $e', name: 'sonic-drip');
      return null;
    }
  }
}

extension TrackCopy on Track {
  Track copyWith({
    String? id,
    String? name,
    String? artistName,
    String? albumName,
    int? durationMs,
    String? imageUrl,
    String? previewUrl,
    String? externalUrl,
    String? source,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      durationMs: durationMs ?? this.durationMs,
      imageUrl: imageUrl ?? this.imageUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      source: source ?? this.source,
    );
  }
}
