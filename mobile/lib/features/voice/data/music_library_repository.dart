import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/music_models.dart';

/// Music library item types
enum LibraryItemType { liked, playlist, album, artist, history }

/// A user playlist
class UserPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final List<String> trackIds;
  final int trackCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  const UserPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.trackIds = const [],
    this.trackCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      trackIds: (json['track_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      trackCount: json['track_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'cover_url': coverUrl,
    'track_ids': trackIds,
    'track_count': trackIds.length,
    'created_at': createdAt.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'is_public': isPublic,
  };

  UserPlaylist copyWith({
    String? name,
    String? description,
    String? coverUrl,
    List<String>? trackIds,
    bool? isPublic,
  }) {
    return UserPlaylist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      trackIds: trackIds ?? this.trackIds,
      trackCount: (trackIds ?? this.trackIds).length,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

/// Music library state
class MusicLibrary {
  final List<Track> likedSongs;
  final List<UserPlaylist> playlists;
  final List<Track> history;
  final Set<String> likedIds;
  final bool isLoading;

  const MusicLibrary({
    this.likedSongs = const [],
    this.playlists = const [],
    this.history = const [],
    this.likedIds = const {},
    this.isLoading = false,
  });

  bool isLiked(String trackId) => likedIds.contains(trackId);

  MusicLibrary copyWith({
    List<Track>? likedSongs,
    List<UserPlaylist>? playlists,
    List<Track>? history,
    Set<String>? likedIds,
    bool? isLoading,
  }) {
    return MusicLibrary(
      likedSongs: likedSongs ?? this.likedSongs,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      likedIds: likedIds ?? this.likedIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Repository for music library management
abstract class MusicLibraryRepository {
  Future<MusicLibrary> getLibrary();
  Future<void> likeSong(Track track);
  Future<void> unlikeSong(String trackId);
  Future<void> addToHistory(Track track);
  Future<UserPlaylist> createPlaylist(String name, {String? description});
  Future<void> updatePlaylist(UserPlaylist playlist);
  Future<void> deletePlaylist(String playlistId);
  Future<void> addToPlaylist(String playlistId, Track track);
  Future<void> removeFromPlaylist(String playlistId, String trackId);
  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex);
}

final musicLibraryRepositoryProvider = Provider<MusicLibraryRepository>((ref) {
  return MusicLibraryRepositoryImpl();
});

/// Implementation with local storage + Supabase sync
class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  static const _likedKey = 'music_liked_songs';
  static const _playlistsKey = 'music_playlists';
  static const _historyKey = 'music_history';
  static const _maxHistory = 50;

  SharedPreferences? _prefs;
  final _client = Supabase.instance.client;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<MusicLibrary> getLibrary() async {
    try {
      final prefs = await _getPrefs();
      
      // Load liked songs
      final likedJson = prefs.getString(_likedKey);
      List<Track> likedSongs = [];
      Set<String> likedIds = {};
      if (likedJson != null) {
        final List<dynamic> list = json.decode(likedJson);
        likedSongs = list.map((e) => _trackFromJson(e)).toList();
        likedIds = likedSongs.map((t) => t.id).toSet();
      }

      // Load playlists
      final playlistsJson = prefs.getString(_playlistsKey);
      List<UserPlaylist> playlists = [];
      if (playlistsJson != null) {
        final List<dynamic> list = json.decode(playlistsJson);
        playlists = list.map((e) => UserPlaylist.fromJson(e)).toList();
      }

      // Load history
      final historyJson = prefs.getString(_historyKey);
      List<Track> history = [];
      if (historyJson != null) {
        final List<dynamic> list = json.decode(historyJson);
        history = list.map((e) => _trackFromJson(e)).toList();
      }

      // Sync with Supabase if logged in. Merge instead of overwrite so offline
      // edits are preserved.
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final remote = await _fetchPlaylistsFromSupabase(userId);
        if (remote != null) {
          playlists = _mergePlaylists(playlists, remote);
          await prefs.setString(
            _playlistsKey,
            json.encode(playlists.map((p) => p.toJson()).toList()),
          );
        }
      }

      return MusicLibrary(
        likedSongs: likedSongs,
        playlists: playlists,
        history: history,
        likedIds: likedIds,
      );
    } catch (e) {
      dev.log('Error loading library: $e', name: 'music-library');
      return const MusicLibrary();
    }
  }

  @override
  Future<void> likeSong(Track track) async {
    try {
      final prefs = await _getPrefs();
      final likedJson = prefs.getString(_likedKey);
      List<Map<String, dynamic>> liked = [];
      if (likedJson != null) {
        liked = List<Map<String, dynamic>>.from(json.decode(likedJson));
      }
      
      // Add if not already liked
      if (!liked.any((e) => e['id'] == track.id)) {
        liked.insert(0, _trackToJson(track));
        await prefs.setString(_likedKey, json.encode(liked));
      }

      // Sync to Supabase
      await _syncLikedToSupabase(track.id, true);
    } catch (e) {
      dev.log('Error liking song: $e', name: 'music-library');
    }
  }

  @override
  Future<void> unlikeSong(String trackId) async {
    try {
      final prefs = await _getPrefs();
      final likedJson = prefs.getString(_likedKey);
      if (likedJson != null) {
        final List<dynamic> liked = json.decode(likedJson);
        liked.removeWhere((e) => e['id'] == trackId);
        await prefs.setString(_likedKey, json.encode(liked));
      }

      // Sync to Supabase
      await _syncLikedToSupabase(trackId, false);
    } catch (e) {
      dev.log('Error unliking song: $e', name: 'music-library');
    }
  }

  @override
  Future<void> addToHistory(Track track) async {
    try {
      final prefs = await _getPrefs();
      final historyJson = prefs.getString(_historyKey);
      List<Map<String, dynamic>> history = [];
      if (historyJson != null) {
        history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      }
      
      // Remove if already exists (to move to front)
      history.removeWhere((e) => e['id'] == track.id);
      
      // Add to front
      history.insert(0, _trackToJson(track));
      
      // Limit history size
      if (history.length > _maxHistory) {
        history = history.sublist(0, _maxHistory);
      }
      
      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      dev.log('Error adding to history: $e', name: 'music-library');
    }
  }

  @override
  Future<UserPlaylist> createPlaylist(String name, {String? description}) async {
    final playlist = UserPlaylist(
      id: 'playlist_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      List<Map<String, dynamic>> playlists = [];
      if (playlistsJson != null) {
        playlists = List<Map<String, dynamic>>.from(json.decode(playlistsJson));
      }
      
      playlists.add(playlist.toJson());
      await prefs.setString(_playlistsKey, json.encode(playlists));

      // Sync to Supabase
      await _syncPlaylistToSupabase(playlist);
    } catch (e) {
      dev.log('Error creating playlist: $e', name: 'music-library');
    }

    return playlist;
  }

  @override
  Future<void> updatePlaylist(UserPlaylist playlist) async {
    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      if (playlistsJson != null) {
        final List<dynamic> playlists = json.decode(playlistsJson);
        final index = playlists.indexWhere((e) => e['id'] == playlist.id);
        if (index >= 0) {
          playlists[index] = playlist.toJson();
          await prefs.setString(_playlistsKey, json.encode(playlists));
        }
      }

      await _syncPlaylistToSupabase(playlist);
    } catch (e) {
      dev.log('Error updating playlist: $e', name: 'music-library');
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      if (playlistsJson != null) {
        final List<dynamic> playlists = json.decode(playlistsJson);
        playlists.removeWhere((e) => e['id'] == playlistId);
        await prefs.setString(_playlistsKey, json.encode(playlists));
      }

      // Delete from Supabase
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client.from('music_playlists').delete().eq('id', playlistId);
      }
    } catch (e) {
      dev.log('Error deleting playlist: $e', name: 'music-library');
    }
  }

  @override
  Future<void> addToPlaylist(String playlistId, Track track) async {
    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      if (playlistsJson != null) {
        final List<dynamic> playlists = json.decode(playlistsJson);
        final index = playlists.indexWhere((e) => e['id'] == playlistId);
        if (index >= 0) {
          final playlist = UserPlaylist.fromJson(playlists[index]);
          final trackIds = [...playlist.trackIds];
          if (!trackIds.contains(track.id)) {
            trackIds.add(track.id);
            final updated = playlist.copyWith(trackIds: trackIds);
            playlists[index] = updated.toJson();
            await prefs.setString(_playlistsKey, json.encode(playlists));
          }
        }
      }
    } catch (e) {
      dev.log('Error adding to playlist: $e', name: 'music-library');
    }
  }

  @override
  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      if (playlistsJson != null) {
        final List<dynamic> playlists = json.decode(playlistsJson);
        final index = playlists.indexWhere((e) => e['id'] == playlistId);
        if (index >= 0) {
          final playlist = UserPlaylist.fromJson(playlists[index]);
          final trackIds = playlist.trackIds.where((id) => id != trackId).toList();
          final updated = playlist.copyWith(trackIds: trackIds);
          playlists[index] = updated.toJson();
          await prefs.setString(_playlistsKey, json.encode(playlists));
        }
      }
    } catch (e) {
      dev.log('Error removing from playlist: $e', name: 'music-library');
    }
  }

  @override
  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex) async {
    try {
      final prefs = await _getPrefs();
      final playlistsJson = prefs.getString(_playlistsKey);
      if (playlistsJson != null) {
        final List<dynamic> playlists = json.decode(playlistsJson);
        final index = playlists.indexWhere((e) => e['id'] == playlistId);
        if (index >= 0) {
          final playlist = UserPlaylist.fromJson(playlists[index]);
          final trackIds = [...playlist.trackIds];
          if (oldIndex < trackIds.length && newIndex <= trackIds.length) {
            final item = trackIds.removeAt(oldIndex);
            trackIds.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
            final updated = playlist.copyWith(trackIds: trackIds);
            playlists[index] = updated.toJson();
            await prefs.setString(_playlistsKey, json.encode(playlists));
          }
        }
      }
    } catch (e) {
      dev.log('Error reordering playlist: $e', name: 'music-library');
    }
  }

  // Sync helpers
  Future<List<UserPlaylist>?> _fetchPlaylistsFromSupabase(String userId) async {
    try {
      final data = await _client
          .from('music_playlists')
          .select()
          .eq('user_id', userId);
      if (data.isEmpty) return [];
      return data
          .map<UserPlaylist>((row) => UserPlaylist.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      dev.log('Error fetching playlists from Supabase: $e', name: 'music-library');
      return null;
    }
  }

  /// Merge local + remote by id, keeping the row with the newer updatedAt.
  /// Local-only rows (offline-created) are preserved.
  List<UserPlaylist> _mergePlaylists(
    List<UserPlaylist> local,
    List<UserPlaylist> remote,
  ) {
    final byId = <String, UserPlaylist>{};
    for (final p in local) {
      byId[p.id] = p;
    }
    for (final r in remote) {
      final existing = byId[r.id];
      if (existing == null || r.updatedAt.isAfter(existing.updatedAt)) {
        byId[r.id] = r;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _syncLikedToSupabase(String trackId, bool liked) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (liked) {
        await _client.from('music_likes').upsert({
          'user_id': userId,
          'track_id': trackId,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _client.from('music_likes')
            .delete()
            .eq('user_id', userId)
            .eq('track_id', trackId);
      }
    } catch (e) {
      dev.log('Error syncing liked to Supabase: $e', name: 'music-library');
    }
  }

  Future<void> _syncPlaylistToSupabase(UserPlaylist playlist) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('music_playlists').upsert({
        'id': playlist.id,
        'user_id': userId,
        'name': playlist.name,
        'description': playlist.description,
        'cover_url': playlist.coverUrl,
        'track_ids': playlist.trackIds,
        'is_public': playlist.isPublic,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      dev.log('Error syncing playlist to Supabase: $e', name: 'music-library');
    }
  }

  // JSON helpers
  Map<String, dynamic> _trackToJson(Track track) => {
    'id': track.id,
    'name': track.name,
    'artistName': track.artistName,
    'albumName': track.albumName,
    'durationMs': track.durationMs,
    'imageUrl': track.imageUrl,
    'previewUrl': track.previewUrl,
    'externalUrl': track.externalUrl,
    'source': track.source,
  };

  Track _trackFromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    name: json['name'] as String,
    artistName: json['artistName'] as String,
    albumName: json['albumName'] as String?,
    durationMs: json['durationMs'] as int?,
    imageUrl: json['imageUrl'] as String?,
    previewUrl: json['previewUrl'] as String?,
    externalUrl: json['externalUrl'] as String?,
    source: json['source'] as String? ?? 'saavn',
  );
}

// Typo fix helper
Future<SharedPreferences> _getPrefs() async {
  return await SharedPreferences.getInstance();
}
