# Drip Bash - BlackHole-Style Music Streaming Implementation

## Overview

This document provides a complete guide for implementing BlackHole-style music search and streaming in Flicko's Sonic Drip feature. The implementation follows the same architecture used by BlackHole music app.

## Current Implementation Status

### ✅ Completed
- Basic UI for Drip Bash bottom sheet
- iTunes API integration (30-second previews)
- Invidious API integration (full-song streaming)
- Track model and repository structure

### ❌ Issues Identified
- iTunes API may return empty results for some queries
- Invidious instance `inv.nadeko.net` may be unreliable
- No fallback mechanism for failed requests
- CORS issues on web platform

---

## Step-by-Step Implementation Guide

### Step 1: Add Required Dependencies

Add to `mobile/pubspec.yaml`:

```yaml
dependencies:
  # HTTP Client
  dio: ^5.4.3+1
  
  # YouTube Video/Audio Extraction (RECOMMENDED)
  youtube_explode_dart: ^2.0.4
  
  # State Management (already included)
  flutter_riverpod: ^3.3.1
  
  # Audio Player
  just_audio: ^0.10.5
  audio_session: ^0.1.21
```

Run:
```bash
cd mobile && flutter pub get
```

---

### Step 2: Create the Music Models

File: `lib/features/voice/domain/music_models.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'music_models.freezed.dart';
part 'music_models.g.dart';

@freezed
class Track with _$Track {
  const factory Track({
    required String id,
    required String name,
    required String artistName,
    String? albumName,
    int? durationMs,
    String? imageUrl,
    String? previewUrl,
    String? externalUrl,
    required String source,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}

extension TrackExtension on Track {
  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final minutes = durationMs! ~/ 60000;
    final seconds = (durationMs! % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
```

---

### Step 3: Create the Drip Bash Repository

File: `lib/features/voice/data/drip_bash_repository.dart`

```dart
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../domain/music_models.dart';

/// Drip Bash Repository - BlackHole-style music streaming
/// 
/// Implementation Strategy (following BlackHole architecture):
/// 1. Search: YouTube Music API (via youtube_explode_dart)
/// 2. Streaming: Extract adaptive audio streams from YouTube
/// 3. Fallback: JioSaavn API for Indian music
abstract class DripBashRepository {
  Future<List<Track>> searchYouTube(String query, {int limit});
  Future<List<Track>> searchSaavn(String query, {int limit});
  Future<String?> getStreamingUrl(String videoId);
  Future<String?> getSaavnStreamingUrl(String songId);
}

final dripBashRepositoryProvider = Provider<DripBashRepository>((ref) {
  return DripBashRepositoryImpl();
});

class DripBashRepositoryImpl implements DripBashRepository {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json,*/*',
    },
  ));
  
  final YoutubeExplode _yt = YoutubeExplode();

  // ─── YouTube Search & Streaming ─────────────────────────────────────────────

  @override
  Future<List<Track>> searchYouTube(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      dev.log('YouTube search: "$query"', name: 'drip-bash');

      // Use youtube_explode for reliable search
      final searchList = await _yt.search.search(query);
      final videos = searchList.toList();

      final tracks = <Track>[];
      for (final video in videos.take(limit)) {
        tracks.add(Track(
          id: video.id.value,
          name: video.title,
          artistName: video.author,
          albumName: null,
          durationMs: video.duration?.inMilliseconds,
          imageUrl: video.thumbnails.highResUrl,
          previewUrl: null, // Will fetch on demand
          externalUrl: video.url,
          source: 'youtube',
        ));
      }

      dev.log('YouTube found ${tracks.length} tracks', name: 'drip-bash');
      return tracks;
    } catch (e) {
      dev.log('YouTube search error: $e', name: 'drip-bash');
      // Fallback to Invidious API
      return _searchInvidious(query, limit);
    }
  }

  @override
  Future<String?> getStreamingUrl(String videoId) async {
    try {
      dev.log('Getting streaming URL for: $videoId', name: 'drip-bash');

      // Use youtube_explode for reliable audio extraction
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Get the best audio-only stream
      final audioStream = manifest.audioOnly
          .sortByBitrate()
          .lastOrNull;
      
      if (audioStream != null) {
        dev.log('Got audio stream: ${audioStream.bitrate}', name: 'drip-bash');
        return audioStream.url.toString();
      }
      
      // Fallback to muxed stream (video + audio)
      final muxedStream = manifest.muxed.sortByVideoQuality().lastOrNull;
      return muxedStream?.url.toString();
    } catch (e) {
      dev.log('Error getting streaming URL: $e', name: 'drip-bash');
      // Fallback to Invidious
      return _getInvidiousStreamingUrl(videoId);
    }
  }

  // ─── JioSaavn Search & Streaming ─────────────────────────────────────────────

  @override
  Future<List<Track>> searchSaavn(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      dev.log('JioSaavn search: "$query"', name: 'drip-bash');

      // JioSaavn API endpoint (from BlackHole)
      final url = 'https://saavn.dev/api/search/songs'
          '?query=${Uri.encodeComponent(query)}&limit=$limit';

      final res = await _dio.get(url);

      if (res.statusCode != 200) {
        dev.log('JioSaavn returned ${res.statusCode}', name: 'drip-bash');
        return [];
      }

      final data = res.data as Map<String, dynamic>;
      final results = (data['data']?['results'] as List?) ?? [];

      final tracks = <Track>[];
      for (final item in results) {
        if (item is! Map) continue;
        tracks.add(_mapSaavnItem(Map<String, dynamic>.from(item)));
      }

      dev.log('JioSaavn found ${tracks.length} tracks', name: 'drip-bash');
      return tracks;
    } catch (e) {
      dev.log('JioSaavn search error: $e', name: 'drip-bash');
      return [];
    }
  }

  @override
  Future<String?> getSaavnStreamingUrl(String songId) async {
    try {
      dev.log('Getting Saavn streaming URL for: $songId', name: 'drip-bash');

      // Get song details with streaming URLs
      final url = 'https://saavn.dev/api/songs/$songId';

      final res = await _dio.get(url);

      if (res.statusCode != 200) return null;

      final data = res.data as Map<String, dynamic>;
      final downloadUrl = data['data']?['downloadUrl'] as List?;

      if (downloadUrl == null || downloadUrl.isEmpty) return null;

      // Get the highest quality (320kbps)
      final highQuality = downloadUrl.last as Map<String, dynamic>?;
      return highQuality?['url'] as String?;
    } catch (e) {
      dev.log('Error getting Saavn streaming URL: $e', name: 'drip-bash');
      return null;
    }
  }

  // ─── Fallback: Invidious API ─────────────────────────────────────────────────

  Future<List<Track>> _searchInvidious(String query, int limit) async {
    try {
      dev.log('Invidious fallback search: "$query"', name: 'drip-bash');

      // Use reliable Invidious instances
      final instances = [
        'https://inv.nadeko.net',
        'https://invidious.nerdvpn.de',
        'https://invidious.jing.rocks',
      ];

      for (final instance in instances) {
        try {
          final url = '$instance/api/v1/search'
              '?q=${Uri.encodeComponent(query)}&type=video';

          final res = await _dio.get(url);

          if (res.statusCode == 200 && res.data is List) {
            final results = res.data as List;
            final tracks = <Track>[];

            for (final item in results.take(limit)) {
              if (item is! Map) continue;
              tracks.add(_mapInvidiousItem(Map<String, dynamic>.from(item)));
            }

            if (tracks.isNotEmpty) return tracks;
          }
        } catch (_) {
          continue; // Try next instance
        }
      }

      return [];
    } catch (e) {
      dev.log('Invidious search error: $e', name: 'drip-bash');
      return [];
    }
  }

  Future<String?> _getInvidiousStreamingUrl(String videoId) async {
    try {
      final instances = [
        'https://inv.nadeko.net',
        'https://invidious.nerdvpn.de',
      ];

      for (final instance in instances) {
        try {
          final url = '$instance/api/v1/videos/$videoId';
          final res = await _dio.get(url);

          if (res.statusCode != 200) continue;

          final data = res.data as Map<String, dynamic>;
          final adaptiveFormats = data['adaptiveFormats'] as List? ?? [];

          // Find best audio-only format
          String? audioUrl;
          int maxBitrate = 0;

          for (final format in adaptiveFormats) {
            final f = format as Map<String, dynamic>;
            final type = (f['type'] as String?) ?? '';
            if (!type.startsWith('audio/')) continue;

            final bitrate = (f['bitrate'] as num?)?.toInt() ?? 0;
            if (bitrate > maxBitrate) {
              maxBitrate = bitrate;
              audioUrl = f['url'] as String?;
            }
          }

          if (audioUrl != null) return audioUrl;
        } catch (_) {
          continue;
        }
      }

      return null;
    } catch (e) {
      dev.log('Error getting Invidious streaming URL: $e', name: 'drip-bash');
      return null;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Track _mapSaavnItem(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = _decodeHtml(item['name']?.toString() ?? 'Unknown');
    final artist = _decodeHtml(
      (item['artists']?['primary'] as List?)
          ?.map((a) => a['name'] as String?)
          .whereType<String>()
          .join(', ') ?? 'Unknown Artist'
    );
    final album = item['album']?['name']?.toString();
    
    // Get highest quality image
    final images = item['image'] as List?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      imageUrl = (images.last as Map?)?['url'] as String?;
    }

    // Duration in seconds
    final durationSec = item['duration'] as int?;
    final durationMs = durationSec != null ? durationSec * 1000 : null;

    return Track(
      id: id,
      name: name,
      artistName: artist,
      albumName: album,
      durationMs: durationMs,
      imageUrl: imageUrl,
      previewUrl: null, // Will fetch via getSaavnStreamingUrl
      externalUrl: item['url'] as String?,
      source: 'saavn',
    );
  }

  Track _mapInvidiousItem(Map<String, dynamic> item) {
    final videoId = item['videoId'] as String? ?? '';
    final title = item['title']?.toString() ?? 'Unknown';
    final author = item['author']?.toString() ?? 'Unknown Artist';

    // Get thumbnail
    final thumbnails = item['videoThumbnails'] as List?;
    String? imageUrl;
    if (thumbnails != null) {
      for (final t in thumbnails) {
        final quality = (t as Map)['quality'] as String?;
        if (quality == 'medium' || quality == 'high') {
          imageUrl = t['url'] as String?;
          break;
        }
      }
      imageUrl ??= thumbnails.isNotEmpty ? (thumbnails.last as Map)['url'] as String? : null;
    }

    final durationSec = item['lengthSeconds'] as int?;
    final durationMs = durationSec != null ? durationSec * 1000 : null;

    return Track(
      id: videoId,
      name: title,
      artistName: author,
      albumName: null,
      durationMs: durationMs,
      imageUrl: imageUrl,
      previewUrl: null,
      externalUrl: 'https://youtube.com/watch?v=$videoId',
      source: 'youtube',
    );
  }

  String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  void dispose() {
    _yt.close();
  }
}
```

---

### Step 4: Create the Audio Player Service

File: `lib/features/voice/application/drip_bash_player.dart`

```dart
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dripBashPlayerProvider = Provider<DripBashPlayer>((ref) {
  return DripBashPlayer();
});

class DripBashPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _initialized = true;
  }

  Future<void> play(String url) async {
    await init();
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Future<void> seek(Duration position) => _player.seek(position);
  
  void dispose() => _player.dispose();
}
```

---

### Step 5: Update Drip Bash Sheet UI

File: `lib/features/voice/presentation/widgets/drip_bash_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../domain/music_models.dart';
import '../../data/drip_bash_repository.dart';
import '../../application/sonic_drip_notifier.dart';

class DripBashSheet extends ConsumerStatefulWidget {
  const DripBashSheet({super.key});

  @override
  ConsumerState<DripBashSheet> createState() => _DripBashSheetState();
}

class _DripBashSheetState extends ConsumerState<DripBashSheet> {
  final _searchController = TextEditingController();
  List<Track> _results = [];
  bool _isLoading = false;
  String _selectedSource = 'youtube'; // 'youtube' or 'saavn'
  Timer? _debounce;

  static const _lime = Color(0xFF52B788);
  static const _black = Color(0xFF000000);
  static const _surface = Color(0xFF0A0A0A);

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(dripBashRepositoryProvider);
      final results = _selectedSource == 'youtube'
          ? await repo.searchYouTube(query)
          : await repo.searchSaavn(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _black,
        border: Border(top: BorderSide(color: _lime, width: 3)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRIP_BASH',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedSource == 'youtube' 
                              ? 'YOUTUBE_FULL_SONG' 
                              : 'JIOSAAVN_320KBPS',
                          style: GoogleFonts.robotoMono(
                            color: _lime,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSourceToggle(),
                ],
              ),
            ),

            // Search Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: _lime, offset: Offset(3, 3))],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'SEARCH_SONGS...',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    prefixIcon: const Icon(Icons.search, color: _lime, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                            child: const Icon(Icons.close, color: Colors.white54, size: 20),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            // Results
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: _lime),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) => _TrackTile(
                    track: _results[index],
                    onTap: () => _addToQueue(_results[index]),
                  ),
                ),
              )
            else if (_searchController.text.isNotEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, color: Colors.white24, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'NO_RESULTS_FOUND',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try a different search term',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sourceBtn('YTM', 'youtube'),
          _sourceBtn('SAAVN', 'saavn'),
        ],
      ),
    );
  }

  Widget _sourceBtn(String label, String source) {
    final selected = _selectedSource == source;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSource = source);
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? _lime : Colors.transparent,
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Future<void> _addToQueue(Track track) async {
    final repo = ref.read(dripBashRepositoryProvider);
    String? streamingUrl;

    // Get streaming URL
    if (track.source == 'youtube') {
      streamingUrl = await repo.getStreamingUrl(track.id);
    } else if (track.source == 'saavn') {
      streamingUrl = await repo.getSaavnStreamingUrl(track.id);
    }

    if (streamingUrl != null && mounted) {
      // Update track with streaming URL
      final playableTrack = Track(
        id: track.id,
        name: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        durationMs: track.durationMs,
        imageUrl: track.imageUrl,
        previewUrl: streamingUrl,
        externalUrl: track.externalUrl,
        source: track.source,
      );

      ref.read(sonicDripProvider.notifier).addToQueue(playableTrack);
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get streaming URL')),
      );
    }
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF52B788), width: 1),
              ),
              child: track.imageUrl != null
                  ? Image.network(
                      track.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note,
                        color: Color(0xFF52B788),
                      ),
                    )
                  : const Icon(Icons.music_note, color: Color(0xFF52B788)),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duration & Source
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  track.durationFormatted,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF52B788),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: track.source == 'saavn' 
                      ? const Color(0xFF52B788) 
                      : Colors.red,
                  child: Text(
                    track.source == 'saavn' ? 'SAAVN' : 'YTM',
                    style: GoogleFonts.spaceMono(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## API Reference

### 1. YouTube (via youtube_explode_dart)

**Search:**
```dart
final yt = YoutubeExplode();
final results = await yt.search.search('query');
```

**Get Streaming URL:**
```dart
final manifest = await yt.videos.streamsClient.getManifest(videoId);
final audioUrl = manifest.audioOnly.sortByBitrate().last.url;
```

### 2. JioSaavn (via saavn.dev API)

**Search:**
```
GET https://saavn.dev/api/search/songs?query={query}&limit=20
```

**Get Song Details:**
```
GET https://saavn.dev/api/songs/{songId}
```

Response includes `downloadUrl` array with streaming URLs at different qualities.

### 3. Invidious (Fallback)

**Search:**
```
GET {instance}/api/v1/search?q={query}&type=video
```

**Get Video Details:**
```
GET {instance}/api/v1/videos/{videoId}
```

Response includes `adaptiveFormats` array with audio streams.

---

## Reliable Invidious Instances

Use these as fallbacks when youtube_explode fails:

1. `https://inv.nadeko.net`
2. `https://invidious.nerdvpn.de`
3. `https://invidious.jing.rocks`
4. `https://invidious.nerdvpn.de`

---

## Error Handling Strategy

```dart
Future<List<Track>> search(String query) async {
  // Try primary source (youtube_explode)
  try {
    return await searchYouTube(query);
  } catch (e) {
    log('YouTube failed: $e');
  }
  
  // Try fallback (Invidious)
  try {
    return await searchInvidious(query);
  } catch (e) {
    log('Invidious failed: $e');
  }
  
  // Try JioSaavn for Indian music
  try {
    return await searchSaavn(query);
  } catch (e) {
    log('Saavn failed: $e');
  }
  
  return []; // All sources failed
}
```

---

## Testing

Run this to verify the implementation:

```bash
cd mobile && flutter test test/features/voice/drip_bash_test.dart
```

---

## Troubleshooting

### Issue: "No results found" always

**Solutions:**
1. Check internet connection
2. Verify youtube_explode is properly installed
3. Check if APIs are accessible from your region
4. Enable debug logging to see actual errors

### Issue: Streaming URL returns null

**Solutions:**
1. YouTube may require signature decryption - youtube_explode handles this
2. Some videos may be region-locked
3. Try different Invidious instances

### Issue: CORS errors on web

**Solutions:**
1. Use a CORS proxy
2. Deploy your own Invidious instance
3. Use server-side API calls

---

## Next Steps

1. **Add youtube_explode_dart dependency** - This is the key to reliable streaming
2. **Update the repository** with the new implementation
3. **Test thoroughly** with different search queries
4. **Add caching** for search results and streaming URLs
5. **Implement download feature** for offline playback
