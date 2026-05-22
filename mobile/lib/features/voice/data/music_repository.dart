import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'drip_bash_repository.dart';
import '../domain/music_models.dart';

abstract class MusicRepository {
  Future<List<Track>> search(String query, {MusicType type, int limit});
  Future<List<Track>> getRecommendations(String trackId, String source, {int limit});
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return DripBashMusicRepository(ref.watch(dripBashRepositoryProvider));
});

/// Music search repository backed by JioSaavn + YouTube (Drip Bash).
/// Replaced the old iTunes-only implementation.
class DripBashMusicRepository implements MusicRepository {
  final DripBashRepository _repo;

  DripBashMusicRepository(this._repo);

  @override
  Future<List<Track>> search(
    String query, {
    MusicType type = MusicType.track,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      dev.log('Drip Bash search: "$query" type=$type', name: 'sonic-drip');

      // Use JioSaavn as primary, fall back to YouTube
      List<Track> results;
      if (type == MusicType.track) {
        results = await _repo.searchSaavn(query, limit: limit);
        if (results.isEmpty) {
          results = await _repo.searchYouTube(query, limit: limit);
        }
      } else {
        // For albums/artists, use categorized search
        final categorized = await _repo.searchSaavnCategorized(query);
        final targetTitle = switch (type) {
          MusicType.album => 'Albums',
          MusicType.artist => 'Artists',
          MusicType.track => 'Songs',
        };
        final category = categorized.categories
            .where((c) => c.title == targetTitle)
            .firstOrNull;
        results = category?.items ?? [];

        // Fall back to generic song search if no category match
        if (results.isEmpty) {
          results = await _repo.searchSaavn(query, limit: limit);
        }
      }

      dev.log('Drip Bash results: ${results.length}', name: 'sonic-drip');
      return results;
    } catch (e, st) {
      dev.log('Drip Bash search error: $e\n$st', name: 'sonic-drip');
      return [];
    }
  }

  @override
  Future<List<Track>> getRecommendations(String trackId, String source, {int limit = 10}) async {
    try {
      if (source == 'youtube') {
        return await _repo.getYouTubeRecommendations(trackId, limit: limit);
      } else {
        return await _repo.getSaavnRecommendations(trackId, limit: limit);
      }
    } catch (e, st) {
      dev.log('Failed to fetch recommendations: $e\n$st', name: 'sonic-drip');
      return [];
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
