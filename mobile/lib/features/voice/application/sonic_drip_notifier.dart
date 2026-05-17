import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SonicDripState {
  final PlaybackState playback;
  final List<Track> queue;
  final List<Track> searchResults;
  final bool isSearching;
  final String? searchError;
  final SpotifySession? session;

  const SonicDripState({
    this.playback = const PlaybackState(),
    this.queue = const [],
    this.searchResults = const [],
    this.isSearching = false,
    this.searchError,
    this.session,
  });

  bool get hasSession => session != null;
  bool get isPlaying => playback.status == PlaybackStatus.playing;
  bool get isPaused => playback.status == PlaybackStatus.paused;

  SonicDripState copyWith({
    PlaybackState? playback,
    List<Track>? queue,
    List<Track>? searchResults,
    bool? isSearching,
    String? searchError,
    SpotifySession? session,
    bool clearSearchError = false,
    bool clearSession = false,
  }) {
    return SonicDripState(
      playback: playback ?? this.playback,
      queue: queue ?? this.queue,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
      session: clearSession ? null : (session ?? this.session),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final sonicDripProvider =
    NotifierProvider<SonicDripNotifier, SonicDripState>(SonicDripNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SonicDripNotifier extends Notifier<SonicDripState> {
  late final MusicRepository _repo;
  Timer? _progressTimer;
  Timer? _searchDebounce;

  @override
  SonicDripState build() {
    _repo = ref.watch(musicRepositoryProvider);
    ref.onDispose(() {
      _progressTimer?.cancel();
      _searchDebounce?.cancel();
    });
    return const SonicDripState();
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  /// Debounced search — waits 400ms after last keystroke.
  void searchDebounced(String query, {MusicType type = MusicType.track}) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], clearSearchError: true);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query, type: type);
    });
  }

  Future<void> _doSearch(String query, {MusicType type = MusicType.track}) async {
    state = state.copyWith(isSearching: true, clearSearchError: true);
    try {
      final results = await _repo.search(query, type: type);
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (_) {
      state = state.copyWith(
        isSearching: false,
        searchError: 'Search failed. Check your connection.',
      );
    }
  }

  // ── Queue ───────────────────────────────────────────────────────────────────

  void addToQueue(Track track) {
    final alreadyInQueue = state.queue.any((t) => t.id == track.id);
    if (alreadyInQueue) return;

    final newQueue = [...state.queue, track];

    // Auto-play if nothing is playing
    if (state.playback.status == PlaybackStatus.idle) {
      _playTrack(track, newQueue);
    } else {
      state = state.copyWith(queue: newQueue);
    }
  }

  void removeFromQueue(String trackId) {
    final newQueue = state.queue.where((t) => t.id != trackId).toList();
    state = state.copyWith(queue: newQueue);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final list = [...state.queue];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    state = state.copyWith(queue: list);
  }

  void clearQueue() {
    _stopProgressTimer();
    state = state.copyWith(
      queue: [],
      playback: const PlaybackState(),
    );
  }

  // ── Playback ────────────────────────────────────────────────────────────────

  void play(Track track) {
    final queue = state.queue.contains(track)
        ? state.queue
        : [...state.queue, track];
    _playTrack(track, queue);
  }

  void togglePlayPause() {
    if (state.playback.currentTrack == null) return;

    if (state.isPlaying) {
      _stopProgressTimer();
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.paused),
      );
    } else {
      _startProgressTimer();
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.playing),
      );
    }
  }

  void skipNext() {
    final queue = state.queue;
    if (queue.isEmpty) return;

    final currentId = state.playback.currentTrack?.id;
    final currentIndex = queue.indexWhere((t) => t.id == currentId);

    Track? next;
    if (state.playback.shuffle) {
      // Pick random track that isn't current
      final others = queue.where((t) => t.id != currentId).toList();
      if (others.isNotEmpty) {
        others.shuffle();
        next = others.first;
      }
    } else if (currentIndex < queue.length - 1) {
      next = queue[currentIndex + 1];
    } else if (state.playback.repeat) {
      next = queue.first;
    }

    if (next != null) _playTrack(next, queue);
  }

  void skipPrevious() {
    final queue = state.queue;
    if (queue.isEmpty) return;

    // If more than 3 seconds in, restart current track
    if (state.playback.position.inSeconds > 3) {
      state = state.copyWith(
        playback: state.playback.copyWith(position: Duration.zero),
      );
      return;
    }

    final currentId = state.playback.currentTrack?.id;
    final currentIndex = queue.indexWhere((t) => t.id == currentId);

    if (currentIndex > 0) {
      _playTrack(queue[currentIndex - 1], queue);
    } else if (state.playback.repeat) {
      _playTrack(queue.last, queue);
    }
  }

  void seekTo(double progress) {
    final duration = state.playback.duration;
    if (duration == Duration.zero) return;
    final newPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    state = state.copyWith(
      playback: state.playback.copyWith(position: newPosition),
    );
  }

  void setVolume(double volume) {
    state = state.copyWith(
      playback: state.playback.copyWith(volume: volume.clamp(0.0, 1.0)),
    );
  }

  void toggleShuffle() {
    state = state.copyWith(
      playback: state.playback.copyWith(shuffle: !state.playback.shuffle),
    );
  }

  void toggleRepeat() {
    state = state.copyWith(
      playback: state.playback.copyWith(repeat: !state.playback.repeat),
    );
  }

  void stop() {
    _stopProgressTimer();
    state = state.copyWith(
      playback: const PlaybackState(),
    );
  }

  // ── Session ─────────────────────────────────────────────────────────────────

  /// Called after WebView captures Spotify session cookies.
  void saveSession(SpotifySession session) {
    state = state.copyWith(session: session);
  }

  void disconnectSpotify() {
    state = state.copyWith(clearSession: true);
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _playTrack(Track track, List<Track> queue) {
    _stopProgressTimer();

    final duration = track.durationMs != null
        ? Duration(milliseconds: track.durationMs!)
        : const Duration(minutes: 3, seconds: 30);

    state = state.copyWith(
      queue: queue,
      playback: PlaybackState(
        status: PlaybackStatus.playing,
        currentTrack: track,
        position: Duration.zero,
        duration: duration,
        volume: state.playback.volume,
        shuffle: state.playback.shuffle,
        repeat: state.playback.repeat,
      ),
    );

    _startProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isPlaying) return;

      final newPosition = state.playback.position + const Duration(seconds: 1);

      if (newPosition >= state.playback.duration) {
        // Track ended — auto-advance
        _stopProgressTimer();
        skipNext();
      } else {
        state = state.copyWith(
          playback: state.playback.copyWith(position: newPosition),
        );
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
}
