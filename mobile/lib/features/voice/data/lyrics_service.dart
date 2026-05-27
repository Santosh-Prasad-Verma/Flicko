import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/music_models.dart';

/// Synced lyric line
class LyricLine {
  final Duration timestamp;
  final String text;
  final Duration? duration;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.duration,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      timestamp: Duration(milliseconds: (json['timeMs'] as num?)?.toInt() ?? 
          ((json['startTimeMs'] as num?)?.toInt() ?? 0)),
      text: json['words'] as String? ?? json['text'] as String? ?? '',
      duration: json['durationMs'] != null 
          ? Duration(milliseconds: (json['durationMs'] as num).toInt())
          : null,
    );
  }
}

/// Lyrics result
class LyricsResult {
  final String trackId;
  final String trackName;
  final String artistName;
  final List<LyricLine> lines;
  final bool isSynced;
  final String? source;

  const LyricsResult({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    this.lines = const [],
    this.isSynced = false,
    this.source,
  });

  LyricLine? getLineAt(Duration position) {
    if (!isSynced || lines.isEmpty) return null;
    
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return lines[i];
      }
    }
    return null;
  }

  int? getCurrentLineIndex(Duration position) {
    if (!isSynced || lines.isEmpty) return null;
    
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return null;
  }
}

/// Service for fetching lyrics
abstract class LyricsService {
  Future<LyricsResult?> getLyrics(Track track);
}

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  return LyricsServiceImpl();
});

/// Lyrics provider for a specific track
final trackLyricsProvider = FutureProvider.family<LyricsResult?, Track>((ref, track) async {
  final service = ref.read(lyricsServiceProvider);
  return service.getLyrics(track);
});

class LyricsServiceImpl implements LyricsService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  Future<LyricsResult?> getLyrics(Track track) async {
    // Try multiple sources in order
    LyricsResult? result;
    
    // 1. Try LRCLIB (free lyrics API)
    result = await _tryLrcLib(track);
    if (result != null && result.lines.isNotEmpty) return result;

    // 2. Try lyrics.ovh (simple, no sync)
    result = await _tryLyricsOvh(track);
    if (result != null && result.lines.isNotEmpty) return result;

    return null;
  }

  /// LRCLIB - Free synced lyrics API
  Future<LyricsResult?> _tryLrcLib(Track track) async {
    try {
      // Search for track
      final searchUrl = 'https://lrclib.net/api/search';
      final searchRes = await _dio.get(
        searchUrl,
        queryParameters: {
          'track_name': track.name,
          'artist_name': track.artistName,
        },
      );

      if (searchRes.statusCode != 200 || searchRes.data is! List) return null;

      final results = searchRes.data as List;
      if (results.isEmpty) return null;

      // Get the best match
      final bestMatch = results.first as Map<String, dynamic>;
      final id = bestMatch['id'];
      
      if (id == null) return null;

      // Get full lyrics
      final lyricsUrl = 'https://lrclib.net/api/get/$id';
      final lyricsRes = await _dio.get(lyricsUrl);

      if (lyricsRes.statusCode != 200) return null;

      final data = lyricsRes.data as Map<String, dynamic>;
      
      // Prefer synced lyrics
      final syncedLyrics = data['syncedLyrics'] as String?;
      final plainLyrics = data['plainLyrics'] as String?;

      if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
        return LyricsResult(
          trackId: track.id,
          trackName: data['trackName'] as String? ?? track.name,
          artistName: data['artistName'] as String? ?? track.artistName,
          lines: _parseLrc(syncedLyrics),
          isSynced: true,
          source: 'LRCLIB',
        );
      }

      if (plainLyrics != null && plainLyrics.isNotEmpty) {
        return LyricsResult(
          trackId: track.id,
          trackName: data['trackName'] as String? ?? track.name,
          artistName: data['artistName'] as String? ?? track.artistName,
          lines: plainLyrics.split('\n').map((line) => LyricLine(
            timestamp: Duration.zero,
            text: line.trim(),
          )).toList(),
          isSynced: false,
          source: 'LRCLIB',
        );
      }

      return null;
    } catch (e) {
      dev.log('LRCLIB error: $e', name: 'lyrics');
      return null;
    }
  }

  /// Lyrics.ovh - Simple plain lyrics
  Future<LyricsResult?> _tryLyricsOvh(Track track) async {
    try {
      final url = 'https://api.lyrics.ovh/v1/${Uri.encodeComponent(track.artistName)}/${Uri.encodeComponent(track.name)}';
      final res = await _dio.get(url);

      if (res.statusCode != 200) return null;

      final data = res.data as Map<String, dynamic>;
      final lyrics = data['lyrics'] as String?;

      if (lyrics == null || lyrics.isEmpty) return null;

      return LyricsResult(
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        lines: lyrics.split('\n').map((line) => LyricLine(
          timestamp: Duration.zero,
          text: line.trim(),
        )).toList(),
        isSynced: false,
        source: 'lyrics.ovh',
      );
    } catch (e) {
      dev.log('Lyrics.ovh error: $e', name: 'lyrics');
      return null;
    }
  }

  /// Parse LRC format synced lyrics
  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (final line in lrc.split('\n')) {
      final matches = regex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // Text is whatever follows the last timestamp.
      final lastEnd = matches.last.end;
      final text = line.substring(lastEnd).trim();
      if (text.isEmpty) continue;

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr);
        lines.add(LyricLine(
          timestamp: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: msStr.length == 2 ? ms * 10 : ms,
          ),
          text: text,
        ));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}

/// Widget for displaying synced lyrics
class SyncedLyricsWidget extends ConsumerWidget {
  final Track track;
  final Duration position;
  final Function(Duration)? onSeek;

  const SyncedLyricsWidget({
    super.key,
    required this.track,
    required this.position,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(trackLyricsProvider(track));

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || lyrics.lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined, color: const Color(0xFF71717A), size: 48),
                const SizedBox(height: 12),
                Text(
                  'No lyrics available',
                  style: TextStyle(color: const Color(0xFF71717A)),
                ),
              ],
            ),
          );
        }

        if (!lyrics.isSynced) {
          return _PlainLyricsView(lyrics: lyrics);
        }

        return _SyncedLyricsView(
          lyrics: lyrics,
          position: position,
          onSeek: onSeek,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF52B788)),
      ),
      error: (_, __) => Center(
        child: Text('Failed to load lyrics', style: TextStyle(color: const Color(0xFF71717A))),
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  final LyricsResult lyrics;

  const _PlainLyricsView({required this.lyrics});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '${lyrics.trackName}\n${lyrics.artistName}',
            style: const TextStyle(
              color: Color(0xFFFBF9FA),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SelectableText(
            lyrics.lines.map((l) => l.text).join('\n'),
            style: const TextStyle(
              color: Color(0xFFFBF9FA),
              fontSize: 16,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SyncedLyricsView extends StatefulWidget {
  final LyricsResult lyrics;
  final Duration position;
  final Function(Duration)? onSeek;

  const _SyncedLyricsView({
    required this.lyrics,
    required this.position,
    this.onSeek,
  });

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int? _lastLineIndex;
  String? _lastTrackId;

  @override
  void didUpdateWidget(_SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll memory when the song changes.
    if (widget.lyrics.trackId != _lastTrackId) {
      _lastTrackId = widget.lyrics.trackId;
      _lastLineIndex = null;
    }

    final currentIndex = widget.lyrics.getCurrentLineIndex(widget.position);

    if (currentIndex != null && currentIndex != _lastLineIndex) {
      _lastLineIndex = currentIndex;

      // Auto-scroll to current line
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          const itemHeight = 50.0;
          final offset = currentIndex * itemHeight -
              MediaQuery.of(context).size.height / 2 +
              itemHeight;
          _scrollController.animateTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 200),
      itemCount: widget.lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lyrics.lines[index];
        final currentIndex = widget.lyrics.getCurrentLineIndex(widget.position);
        final isActive = currentIndex == index;
        final isPast = currentIndex != null && index < currentIndex;

        return GestureDetector(
          onTap: widget.onSeek != null
              ? () => widget.onSeek!(line.timestamp)
              : null,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isActive 
                  ? const Color(0xFF52B788)
                  : isPast 
                      ? const Color(0xFF71717A)
                      : const Color(0xFFFBF9FA),
              fontSize: isActive ? 20 : 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: Text(line.text),
            ),
          ),
        );
      },
    );
  }
}
