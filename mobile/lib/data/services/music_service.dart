import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/music_model.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/features/voice/data/drip_bash_repository.dart';
import 'package:mobile/features/voice/domain/music_models.dart' as sonic;

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService(ref.watch(dripBashRepositoryProvider));
});

/// Music search service backed by JioSaavn + YouTube (Drip Bash).
class MusicService {
  final DripBashRepository _repo;

  MusicService(this._repo);

  /// Search for music using JioSaavn (primary) with YouTube fallback.
  Future<List<MusicItem>> searchMusic({
    required String query,
    MusicType type = MusicType.track,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Use JioSaavn as primary search provider
      final tracks = await _repo.searchSaavn(query, limit: limit);
      if (tracks.isEmpty) {
        // Fall back to YouTube search
        final ytTracks = await _repo.searchYouTube(query, limit: limit);
        return ytTracks.map((t) => _fromSonicTrack(t, type)).toList();
      }
      return tracks.map((t) => _fromSonicTrack(t, type)).toList();
    } catch (e) {
      return [];
    }
  }

  MusicItem _fromSonicTrack(sonic.Track track, MusicType type) {
    return MusicItem(
      id: track.id,
      type: type,
      name: track.name,
      artistName: track.artistName,
      albumName: track.albumName,
      durationMs: track.durationMs,
      imageUrl: track.imageUrl,
      previewUrl: track.previewUrl,
      externalUrl: track.externalUrl,
      source: track.source,
    );
  }
}
