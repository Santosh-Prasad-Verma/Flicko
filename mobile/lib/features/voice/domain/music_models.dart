/// Domain models for Sonic Drip music feature.
/// These are UI-layer models, decoupled from API response shapes.

enum MusicType { track, album, artist }

enum PlaybackStatus { idle, loading, playing, paused, error }

enum ConnectionStatus { disconnected, connecting, connected, expired }

/// A single playable music item.
class Track {
  final String id;
  final String name;
  final String artistName;
  final String? albumName;
  final int? durationMs;
  final String? imageUrl;
  final String? previewUrl;
  final String? externalUrl;
  final String source; // 'itunes' | 'spotify'

  const Track({
    required this.id,
    required this.name,
    required this.artistName,
    this.albumName,
    this.durationMs,
    this.imageUrl,
    this.previewUrl,
    this.externalUrl,
    this.source = 'itunes',
  });

  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final total = durationMs! ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Playback state snapshot.
class PlaybackState {
  final PlaybackStatus status;
  final Track? currentTrack;
  final Duration position;
  final Duration duration;
  final double volume; // 0.0 – 1.0
  final bool shuffle;
  final bool repeat;
  final String? error;

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.currentTrack,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0.7,
    this.shuffle = false,
    this.repeat = false,
    this.error,
  });

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get positionFormatted {
    final m = position.inMinutes;
    final s = position.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get durationFormatted {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  PlaybackState copyWith({
    PlaybackStatus? status,
    Track? currentTrack,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? shuffle,
    bool? repeat,
    String? error,
    bool clearTrack = false,
    bool clearError = false,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Spotify connection session (cookies only — never passwords).
class SpotifySession {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String product; // 'free' | 'premium'
  final ConnectionStatus status;
  final DateTime? expiresAt;

  const SpotifySession({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.product = 'free',
    this.status = ConnectionStatus.connected,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
