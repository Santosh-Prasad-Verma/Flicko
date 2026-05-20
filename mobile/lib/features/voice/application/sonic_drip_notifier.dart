import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../data/music_repository.dart';
import '../data/drip_bash_repository.dart';
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
  AudioPlayer? _player;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  Timer? _searchDebounce;

  @override
  SonicDripState build() {
    _repo = ref.watch(musicRepositoryProvider);
    _player = AudioPlayer();
    _setupPlayerListeners();
    ref.onDispose(() {
      _searchDebounce?.cancel();
      _positionSub?.cancel();
      _playerStateSub?.cancel();
      _player?.dispose();
    });
    return const SonicDripState();
  }

  void _setupPlayerListeners() {
    // Update position in real time
    _positionSub = _player?.positionStream.listen((position) {
      if (state.playback.status == PlaybackStatus.playing) {
        final duration = state.playback.duration;
        state = state.copyWith(
          playback: state.playback.copyWith(
            position: position,
            duration: duration == Duration.zero
                ? (_player?.duration ?? Duration.zero)
                : duration,
          ),
        );
      }
    });

    // Handle track completion
    _playerStateSub = _player?.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        skipNext();
      }
      if (playerState.playing &&
          state.playback.status != PlaybackStatus.playing) {
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.playing,
            duration: _player?.duration ?? Duration.zero,
          ),
        );
      }
    });
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
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        searchError: 'Search failed: ${e.toString()}',
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
    _player?.stop();
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
      _player?.pause();
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.paused),
      );
    } else {
      _player?.play();
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
    if (state.playback.position.inSeconds > 3) {
      _player?.seek(Duration.zero);
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
    final duration = _player?.duration ?? state.playback.duration;
    if (duration == Duration.zero) return;
    final position = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    _player?.seek(position);
    state = state.copyWith(
      playback: state.playback.copyWith(position: position),
    );
  }

  void setVolume(double volume) {
    _player?.setVolume(volume.clamp(0.0, 1.0));
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
    _player?.stop();
    state = state.copyWith(playback: const PlaybackState());
  }

  // ── Session ─────────────────────────────────────────────────────────────────

  void saveSession(SpotifySession session) {
    state = state.copyWith(session: session);
  }

  void disconnectSpotify() {
    state = state.copyWith(clearSession: true);
  }

  // ── Drip Bash (Saavn/YouTube full-song streaming) ──────────────────────────

  /// Add a track from Drip Bash, resolving its streaming URL first.
  Future<void> addDripBashTrack(Track track) async {
    final resolvedTrack = await _resolveDripBashUrl(track);
    if (resolvedTrack == null) return;

    final alreadyInQueue = state.queue.any((t) => t.id == resolvedTrack.id);
    if (alreadyInQueue) return;

    final newQueue = [...state.queue, resolvedTrack];

    if (state.playback.status == PlaybackStatus.idle) {
      _playTrack(resolvedTrack, newQueue);
    } else {
      state = state.copyWith(queue: newQueue);
    }
  }

  /// Play a track from Drip Bash immediately (resolves URL + starts playback).
  Future<void> playDripBash(Track track) async {
    final resolvedTrack = await _resolveDripBashUrl(track);
    if (resolvedTrack == null) return;

    final queue = state.queue.any((t) => t.id == resolvedTrack.id)
        ? state.queue
        : [...state.queue, resolvedTrack];
    _playTrack(resolvedTrack, queue);
  }

  /// Add all tracks from an album to the queue via Drip Bash.
  Future<void> addAlbumToQueue(List<Track> albumTracks) async {
    for (final track in albumTracks) {
      final resolved = await _resolveDripBashUrl(track);
      if (resolved != null) {
        final alreadyInQueue = state.queue.any((t) => t.id == resolved.id);
        if (!alreadyInQueue) {
          final newQueue = [...state.queue, resolved];
          if (state.playback.status == PlaybackStatus.idle) {
            _playTrack(resolved, newQueue);
          } else {
            state = state.copyWith(queue: newQueue);
          }
        }
      }
    }
  }

  Future<Track?> _resolveDripBashUrl(Track track) async {
    try {
      final repo = ref.read(dripBashRepositoryProvider);
      String? streamUrl;

      if (track.source == 'youtube') {
        state = state.copyWith(
          playback: state.playback.copyWith(status: PlaybackStatus.loading),
        );
        streamUrl = await repo.getStreamingUrl(track.id);
      } else if (track.source == 'saavn') {
        state = state.copyWith(
          playback: state.playback.copyWith(status: PlaybackStatus.loading),
        );
        streamUrl = await repo.getSaavnStreamingUrl(track.id);
      } else if (track.previewUrl != null) {
        return track; // Already has a URL (e.g. iTunes preview)
      }

      if (streamUrl == null) {
        dev.log('Failed to resolve URL for: ${track.name}', name: 'drip-bash');
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.error,
            error: 'Could not get streaming URL',
          ),
        );
        return null;
      }

      return track.copyWith(previewUrl: streamUrl);
    } catch (e) {
      dev.log('Error resolving Drip Bash URL: $e', name: 'drip-bash');
      state = state.copyWith(
        playback: state.playback.copyWith(
          status: PlaybackStatus.error,
          error: 'Stream error: $e',
        ),
      );
      return null;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _playTrack(Track track, List<Track> queue) {
    final previewUrl = track.previewUrl;
    state = state.copyWith(
      queue: queue,
      playback: PlaybackState(
        status: previewUrl != null ? PlaybackStatus.loading : PlaybackStatus.idle,
        currentTrack: track,
        position: Duration.zero,
        duration: track.durationMs != null
            ? Duration(milliseconds: track.durationMs!)
            : Duration.zero,
        volume: state.playback.volume,
        shuffle: state.playback.shuffle,
        repeat: state.playback.repeat,
      ),
    );

    if (previewUrl != null) {
      _player?.setUrl(previewUrl).then((_) {
        _player?.play();
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.playing,
            duration: _player?.duration ?? Duration.zero,
          ),
        );
      }).catchError((e) {
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.error,
            error: 'Preview not available',
          ),
        );
      });
    }
  }
}
