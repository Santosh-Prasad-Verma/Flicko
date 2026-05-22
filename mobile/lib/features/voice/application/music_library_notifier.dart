import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/music_library_repository.dart';
import '../domain/music_models.dart';

/// Provider for music library
final musicLibraryProvider =
    NotifierProvider<MusicLibraryNotifier, MusicLibrary>(MusicLibraryNotifier.new);

class MusicLibraryNotifier extends Notifier<MusicLibrary> {
  late MusicLibraryRepository _repo;

  @override
  MusicLibrary build() {
    _repo = ref.watch(musicLibraryRepositoryProvider);
    Future.microtask(() => loadLibrary());
    return const MusicLibrary();
  }

  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);
    final library = await _repo.getLibrary();
    state = library.copyWith(isLoading: false);
  }

  // Likes
  Future<void> likeSong(Track track) async {
    await _repo.likeSong(track);
    final newLiked = [track, ...state.likedSongs];
    final newIds = {...state.likedIds, track.id};
    state = state.copyWith(likedSongs: newLiked, likedIds: newIds);
  }

  Future<void> unlikeSong(String trackId) async {
    await _repo.unlikeSong(trackId);
    final newLiked = state.likedSongs.where((t) => t.id != trackId).toList();
    final newIds = state.likedIds.difference({trackId});
    state = state.copyWith(likedSongs: newLiked, likedIds: newIds);
  }

  void toggleLike(Track track) {
    if (state.isLiked(track.id)) {
      unlikeSong(track.id);
    } else {
      likeSong(track);
    }
  }

  // History
  Future<void> addToHistory(Track track) async {
    await _repo.addToHistory(track);
    final newHistory = [track, ...state.history.where((t) => t.id != track.id)];
    if (newHistory.length > 50) {
      state = state.copyWith(history: newHistory.sublist(0, 50));
    } else {
      state = state.copyWith(history: newHistory);
    }
  }

  // Playlists
  Future<UserPlaylist> createPlaylist(String name, {String? description}) async {
    final playlist = await _repo.createPlaylist(name, description: description);
    state = state.copyWith(playlists: [...state.playlists, playlist]);
    return playlist;
  }

  Future<void> updatePlaylist(UserPlaylist playlist) async {
    await _repo.updatePlaylist(playlist);
    final newPlaylists = state.playlists.map((p) => 
      p.id == playlist.id ? playlist : p
    ).toList();
    state = state.copyWith(playlists: newPlaylists);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _repo.deletePlaylist(playlistId);
    final newPlaylists = state.playlists.where((p) => p.id != playlistId).toList();
    state = state.copyWith(playlists: newPlaylists);
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    await _repo.addToPlaylist(playlistId, track);
    final newPlaylists = state.playlists.map((p) {
      if (p.id == playlistId) {
        final trackIds = [...p.trackIds];
        if (!trackIds.contains(track.id)) {
          trackIds.add(track.id);
        }
        return p.copyWith(trackIds: trackIds);
      }
      return p;
    }).toList();
    state = state.copyWith(playlists: newPlaylists);
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    await _repo.removeFromPlaylist(playlistId, trackId);
    final newPlaylists = state.playlists.map((p) {
      if (p.id == playlistId) {
        return p.copyWith(trackIds: p.trackIds.where((id) => id != trackId).toList());
      }
      return p;
    }).toList();
    state = state.copyWith(playlists: newPlaylists);
  }

  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex) async {
    await _repo.reorderPlaylist(playlistId, oldIndex, newIndex);
    final newPlaylists = state.playlists.map((p) {
      if (p.id == playlistId) {
        final trackIds = [...p.trackIds];
        if (oldIndex < trackIds.length && newIndex <= trackIds.length) {
          final item = trackIds.removeAt(oldIndex);
          trackIds.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
        }
        return p.copyWith(trackIds: trackIds);
      }
      return p;
    }).toList();
    state = state.copyWith(playlists: newPlaylists);
  }
}
