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

  const SonicDripState({
    this.playback = const PlaybackState(),
    this.queue = const [],
    this.searchResults = const [],
    this.isSearching = false,
    this.searchError,
  });

  bool get isPlaying => playback.status == PlaybackStatus.playing;
  bool get isPaused => playback.status == PlaybackStatus.paused;

  SonicDripState copyWith({
    PlaybackState? playback,
    List<Track>? queue,
    List<Track>? searchResults,
    bool? isSearching,
    String? searchError,
    bool clearSearchError = false,
  }) {
    return SonicDripState(
      playback: playback ?? this.playback,
      queue: queue ?? this.queue,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
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
    // Register sleep timer trigger callback
    ref.read(sleepTimerProvider.notifier).setCallback(() {
      dev.log('Sleep timer callback triggered in SonicDripNotifier', name: 'sonic-drip');
      pause();
    });
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
        final sleepState = ref.read(sleepTimerProvider);
        if (sleepState.isActive && sleepState.endTime == null) {
          ref.read(sleepTimerProvider.notifier).triggerAfterTrack();
        } else {
          skipNext();
        }
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

  void pause() {
    if (state.playback.currentTrack == null) return;
    _player?.pause();
    state = state.copyWith(
      playback: state.playback.copyWith(status: PlaybackStatus.paused),
    );
  }

  void skipNext() {
    final queue = state.queue;
    if (queue.isEmpty) {
      dev.log('skipNext: queue is empty, checking autoplay', name: 'sonic-drip');
      if (state.playback.autoplay && state.playback.currentTrack != null) {
        _fetchRecommendationsAndPlayNext(state.playback.currentTrack);
      }
      return;
    }
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
    } else if (state.playback.autoplay) {
      dev.log('skipNext: end of queue, triggering autoplay fetch', name: 'sonic-drip');
      _fetchRecommendationsAndPlayNext(state.playback.currentTrack);
      return;
    }
    if (next != null) {
      _playTrack(next, queue);
    } else {
      dev.log('skipNext: no next track available', name: 'sonic-drip');
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.idle),
      );
    }
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

  void toggleAutoplay() {
    state = state.copyWith(
      playback: state.playback.copyWith(autoplay: !state.playback.autoplay),
    );
  }


  void stop() {
    _player?.stop();
    state = state.copyWith(playback: const PlaybackState());
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
        return track; // Already has a streaming URL
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

  bool _fetchingRecommendations = false;

  Future<void> _fetchAndAppendRecommendations(Track currentTrack) async {
    if (_fetchingRecommendations) return;
    _fetchingRecommendations = true;
    try {
      dev.log('Autoplay: prefetching recommendations for ${currentTrack.name} (${currentTrack.source})', name: 'sonic-drip');
      final recs = await _repo.getRecommendations(currentTrack.id, currentTrack.source, limit: 10);
      dev.log('Autoplay: received ${recs.length} recommendations', name: 'sonic-drip');
      if (recs.isNotEmpty) {
        final existingIds = state.queue.map((t) => t.id).toSet();
        final List<Track> filtered = recs.where((t) => !existingIds.contains(t.id) && t.id != currentTrack.id).toList();
        if (filtered.isNotEmpty) {
          dev.log('Autoplay: appending ${filtered.length} new recommended tracks to queue', name: 'sonic-drip');
          state = state.copyWith(queue: [...state.queue, ...filtered]);
        } else {
          dev.log('Autoplay: all ${recs.length} recommendations already in queue', name: 'sonic-drip');
        }
      } else {
        dev.log('Autoplay: recommendation service returned empty results', name: 'sonic-drip');
      }
    } catch (e, st) {
      dev.log('Autoplay recommendations error: $e\n$st', name: 'sonic-drip');
    } finally {
      _fetchingRecommendations = false;
    }
  }

  Future<void> _fetchRecommendationsAndPlayNext(Track? currentTrack) async {
    if (currentTrack == null) return;
    if (_fetchingRecommendations) {
      dev.log('Autoplay: already fetching recommendations, skipping', name: 'sonic-drip');
      return;
    }
    _fetchingRecommendations = true;
    state = state.copyWith(playback: state.playback.copyWith(status: PlaybackStatus.loading));
    try {
      dev.log('Autoplay: queue ended, fetching recommendations for ${currentTrack.name} (${currentTrack.source})', name: 'sonic-drip');
      final recs = await _repo.getRecommendations(currentTrack.id, currentTrack.source, limit: 10);
      dev.log('Autoplay: got ${recs.length} recommendations', name: 'sonic-drip');
      if (recs.isNotEmpty) {
        final existingIds = state.queue.map((t) => t.id).toSet();
        final List<Track> filtered = recs.where((t) => !existingIds.contains(t.id) && t.id != currentTrack.id).toList();
        if (filtered.isNotEmpty) {
          dev.log('Autoplay: ${filtered.length} new tracks, attempting playback', name: 'sonic-drip');
          final newQueue = [...state.queue, ...filtered];
          // Try each recommended track until one plays successfully
          for (final nextTrack in filtered) {
            try {
              await _playTrack(nextTrack, newQueue);
              // If _playTrack succeeded (status is playing or loading), we're done
              if (state.playback.status == PlaybackStatus.playing ||
                  state.playback.status == PlaybackStatus.loading) {
                return;
              }
            } catch (e) {
              dev.log('Autoplay: failed to play ${nextTrack.name}, trying next: $e', name: 'sonic-drip');
            }
          }
          // All tracks failed
          dev.log('Autoplay: all recommended tracks failed to play', name: 'sonic-drip');
        } else {
          dev.log('Autoplay: all recommendations already in queue', name: 'sonic-drip');
        }
      } else {
        dev.log('Autoplay: recommendation service returned empty', name: 'sonic-drip');
      }
      state = state.copyWith(playback: state.playback.copyWith(status: PlaybackStatus.idle));
    } catch (e) {
      dev.log('Autoplay instant fetch error: $e', name: 'sonic-drip');
      state = state.copyWith(playback: state.playback.copyWith(status: PlaybackStatus.idle));
    } finally {
      _fetchingRecommendations = false;
    }
  }

  Future<void> _playTrack(Track track, List<Track> queue) async {
    state = state.copyWith(
      queue: queue,
      playback: state.playback.copyWith(
        status: PlaybackStatus.loading,
        currentTrack: track,
      ),
    );

    Track? resolvedTrack = track;
    if (track.previewUrl == null) {
      dev.log('_playTrack: resolving streaming URL for ${track.name} (${track.source})', name: 'sonic-drip');
      resolvedTrack = await _resolveDripBashUrl(track);
      if (resolvedTrack == null) {
        dev.log('_playTrack: failed to resolve URL for ${track.name}', name: 'sonic-drip');
        // Don't get stuck - set idle so skipNext can try the next track
        state = state.copyWith(
          playback: state.playback.copyWith(status: PlaybackStatus.idle),
        );
        return;
      }
    }

    final previewUrl = resolvedTrack.previewUrl;
    final updatedQueue = state.queue.map((t) => t.id == resolvedTrack!.id ? resolvedTrack : t).toList();

    state = state.copyWith(
      queue: updatedQueue,
      playback: PlaybackState(
        status: previewUrl != null ? PlaybackStatus.loading : PlaybackStatus.idle,
        currentTrack: resolvedTrack,
        position: Duration.zero,
        duration: resolvedTrack.durationMs != null
            ? Duration(milliseconds: resolvedTrack.durationMs!)
            : Duration.zero,
        volume: state.playback.volume,
        shuffle: state.playback.shuffle,
        repeat: state.playback.repeat,
        autoplay: state.playback.autoplay,
      ),
    );

    if (previewUrl != null) {
      try {
        await _player?.setUrl(previewUrl);
        _player?.play();
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.playing,
            duration: _player?.duration ?? Duration.zero,
          ),
        );
        dev.log('_playTrack: now playing ${resolvedTrack.name}', name: 'sonic-drip');
        if (state.playback.autoplay) {
          _fetchAndAppendRecommendations(resolvedTrack);
        }
      } catch (e) {
        dev.log('_playTrack: playback error for ${resolvedTrack.name}: $e', name: 'sonic-drip');
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.error,
            error: 'Preview not available: $e',
          ),
        );
      }
    } else {
      dev.log('_playTrack: no preview URL available for ${resolvedTrack.name}', name: 'sonic-drip');
    }
  }
}
