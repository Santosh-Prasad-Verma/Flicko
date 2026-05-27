import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/drip_bash_repository.dart';
import '../data/music_repository.dart';
import '../data/sleep_timer_service.dart';
import '../domain/music_models.dart';
import '../services/flicko_audio_handler.dart';
import 'music_library_notifier.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SonicDripState &&
          other.playback == playback &&
          _listEq(other.queue, queue) &&
          _listEq(other.searchResults, searchResults) &&
          other.isSearching == isSearching &&
          other.searchError == searchError);

  @override
  int get hashCode => Object.hash(
        playback,
        Object.hashAll(queue),
        Object.hashAll(searchResults),
        isSearching,
        searchError,
      );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final sonicDripProvider =
    NotifierProvider<SonicDripNotifier, SonicDripState>(SonicDripNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SonicDripNotifier extends Notifier<SonicDripState> {
  late final MusicRepository _repo;

  /// We try to use the FlickoAudioHandler that drives the system media
  /// session (lock screen, notification, Bluetooth, CarPlay). If it's not
  /// registered yet we fall back to a private AudioPlayer so the screen
  /// still works in tests / pre-init flows.
  FlickoAudioHandler? _handler;
  AudioPlayer? _localPlayer;

  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  Timer? _searchDebounce;
  int _searchSeq = 0;
  bool _advancing = false;
  bool _fetchingRecommendations = false;

  static const _volumeKey = 'sonic_drip_volume';

  AudioPlayer get _player => _handler?.player ?? (_localPlayer ??= AudioPlayer());

  @override
  SonicDripState build() {
    _repo = ref.watch(musicRepositoryProvider);
    _handler = GetIt.I.isRegistered<FlickoAudioHandler>()
        ? GetIt.I<FlickoAudioHandler>()
        : null;

    // Wire notification next/prev buttons → notifier methods.
    _handler?.onSkipNext = () async => skipNext();
    _handler?.onSkipPrevious = () async => skipPrevious();

    _setupPlayerListeners();
    _restoreVolume();

    // Register sleep timer trigger callback exactly once.
    final sleepNotifier = ref.read(sleepTimerProvider.notifier);
    sleepNotifier.setCallback(() {
      dev.log('Sleep timer triggered → pause', name: 'sonic-drip');
      pause();
    });

    ref.onDispose(() {
      _searchDebounce?.cancel();
      _positionSub?.cancel();
      _playerStateSub?.cancel();
      _handler?.onSkipNext = null;
      _handler?.onSkipPrevious = null;
      _localPlayer?.dispose();
    });
    return const SonicDripState();
  }

  Future<void> _restoreVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_volumeKey);
      if (v != null) {
        _player.setVolume(v.clamp(0.0, 1.0));
        state = state.copyWith(
          playback: state.playback.copyWith(volume: v.clamp(0.0, 1.0)),
        );
      }
    } catch (_) {}
  }

  void _setupPlayerListeners() {
    _positionSub = _player.positionStream.listen((position) {
      if (state.playback.status == PlaybackStatus.playing) {
        final duration = state.playback.duration;
        state = state.copyWith(
          playback: state.playback.copyWith(
            position: position,
            duration: duration == Duration.zero
                ? (_player.duration ?? Duration.zero)
                : duration,
          ),
        );
      }
    });

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed &&
          !_advancing) {
        _advancing = true;
        final sleepState = ref.read(sleepTimerProvider);
        if (sleepState.isActive && sleepState.endTime == null) {
          ref.read(sleepTimerProvider.notifier).triggerAfterTrack();
          _advancing = false;
        } else {
          // skipNext is sync in shape but does a lot — schedule unblock.
          skipNext();
          Future.microtask(() => _advancing = false);
        }
      }
      if (playerState.playing &&
          state.playback.status != PlaybackStatus.playing) {
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.playing,
            duration: _player.duration ?? Duration.zero,
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
      // Bump seq so any in-flight response is discarded.
      _searchSeq++;
      state = state.copyWith(searchResults: [], clearSearchError: true);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query, type: type);
    });
  }

  Future<void> _doSearch(String query, {MusicType type = MusicType.track}) async {
    final mySeq = ++_searchSeq;
    state = state.copyWith(isSearching: true, clearSearchError: true);
    try {
      final results = await _repo.search(query, type: type);
      // Drop stale responses (user already typed something else / cleared).
      if (mySeq != _searchSeq) return;
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      if (mySeq != _searchSeq) return;
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
    _player.stop();
    // Preserve user prefs (volume/shuffle/repeat/autoplay) when clearing.
    state = state.copyWith(
      queue: [],
      playback: PlaybackState(
        volume: state.playback.volume,
        shuffle: state.playback.shuffle,
        repeat: state.playback.repeat,
        autoplay: state.playback.autoplay,
      ),
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
      _player.pause();
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.paused),
      );
    } else {
      _player.play();
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.playing),
      );
    }
  }

  void pause() {
    if (state.playback.currentTrack == null) return;
    _player.pause();
    state = state.copyWith(
      playback: state.playback.copyWith(status: PlaybackStatus.paused),
    );
  }

  void skipNext() {
    final queue = state.queue;
    if (queue.isEmpty) {
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
      _fetchRecommendationsAndPlayNext(state.playback.currentTrack);
      return;
    }
    if (next != null) {
      _playTrack(next, queue);
    } else {
      state = state.copyWith(
        playback: state.playback.copyWith(status: PlaybackStatus.idle),
      );
    }
  }

  void skipPrevious() {
    final queue = state.queue;
    if (queue.isEmpty) return;
    if (state.playback.position.inSeconds > 3) {
      _player.seek(Duration.zero);
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
    final p = progress.clamp(0.0, 1.0);
    final duration = _player.duration ?? state.playback.duration;
    if (duration == Duration.zero) return;
    final position = Duration(
      milliseconds: (duration.inMilliseconds * p).round(),
    );
    _player.seek(position);
    state = state.copyWith(
      playback: state.playback.copyWith(position: position),
    );
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _player.setVolume(clamped);
    state = state.copyWith(
      playback: state.playback.copyWith(volume: clamped),
    );
    // Persist (fire-and-forget).
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(_volumeKey, clamped))
        .catchError((_) {});
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

  void clearError() {
    if (state.playback.status == PlaybackStatus.error) {
      state = state.copyWith(
        playback: state.playback.copyWith(
          status: PlaybackStatus.idle,
          clearError: true,
        ),
      );
    }
  }

  void stop() {
    _player.stop();
    state = state.copyWith(
      playback: PlaybackState(
        volume: state.playback.volume,
        shuffle: state.playback.shuffle,
        repeat: state.playback.repeat,
        autoplay: state.playback.autoplay,
      ),
    );
  }

  // ── Drip Bash (Saavn/YouTube full-song streaming) ──────────────────────────

  Future<void> addDripBashTrack(Track track) async {
    final wasIdle = state.playback.status == PlaybackStatus.idle;
    final resolvedTrack = await _resolveDripBashUrl(track, updateStatus: wasIdle);
    if (resolvedTrack == null) return;

    final alreadyInQueue = state.queue.any((t) => t.id == resolvedTrack.id);
    if (alreadyInQueue) return;

    final newQueue = [...state.queue, resolvedTrack];

    if (wasIdle) {
      _playTrack(resolvedTrack, newQueue);
    } else {
      state = state.copyWith(queue: newQueue);
    }
  }

  Future<void> playDripBash(Track track) async {
    final resolvedTrack = await _resolveDripBashUrl(track);
    if (resolvedTrack == null) return;

    final queue = state.queue.any((t) => t.id == resolvedTrack.id)
        ? state.queue
        : [...state.queue, resolvedTrack];
    _playTrack(resolvedTrack, queue);
  }

  /// Add all album tracks to the queue WITHOUT resolving each URL upfront.
  /// Each track's previewUrl is resolved lazily inside [_playTrack] when its
  /// turn comes. Avoids 30 serial network round-trips on a 30-track album.
  Future<void> addAlbumToQueue(List<Track> albumTracks) async {
    if (albumTracks.isEmpty) return;
    final wasIdle = state.playback.status == PlaybackStatus.idle;

    // Filter dupes and append. Preserve order.
    final existingIds = state.queue.map((t) => t.id).toSet();
    final newTracks =
        albumTracks.where((t) => !existingIds.contains(t.id)).toList();
    if (newTracks.isEmpty) return;

    final newQueue = [...state.queue, ...newTracks];
    state = state.copyWith(queue: newQueue);

    if (wasIdle) {
      // Resolve only the first track now; the rest resolve as they play.
      _playTrack(newTracks.first, newQueue);
    }
  }

  Future<Track?> _resolveDripBashUrl(Track track, {bool updateStatus = true}) async {
    try {
      final repo = ref.read(dripBashRepositoryProvider);
      String? streamUrl;

      if (track.previewUrl != null) return track;

      if (track.source == 'youtube') {
        if (updateStatus) {
          state = state.copyWith(
            playback: state.playback.copyWith(status: PlaybackStatus.loading),
          );
        }
        streamUrl = await repo.getStreamingUrl(track.id);
      } else if (track.source == 'saavn') {
        if (updateStatus) {
          state = state.copyWith(
            playback: state.playback.copyWith(status: PlaybackStatus.loading),
          );
        }
        streamUrl = await repo.getSaavnStreamingUrl(track.id);
      }

      if (streamUrl == null) {
        dev.log('Failed to resolve URL for: ${track.name}', name: 'drip-bash');
        if (updateStatus) {
          state = state.copyWith(
            playback: state.playback.copyWith(
              status: PlaybackStatus.error,
              error: 'Could not get streaming URL',
            ),
          );
        }
        return null;
      }

      return track.copyWith(previewUrl: streamUrl);
    } catch (e) {
      dev.log('Error resolving Drip Bash URL: $e', name: 'drip-bash');
      if (updateStatus) {
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.error,
            error: 'Stream error: $e',
          ),
        );
      }
      return null;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _fetchAndAppendRecommendations(Track currentTrack) async {
    if (_fetchingRecommendations) return;
    _fetchingRecommendations = true;
    try {
      var recs = await _repo.getRecommendations(currentTrack.id, currentTrack.source, limit: 10);
      if (recs.isEmpty) {
        String query = currentTrack.artistName;
        if (query.isEmpty || query.toLowerCase() == 'unknown artist') {
          final words = currentTrack.name.split(' ');
          query = words.take(2).join(' ');
        }
        if (query.trim().isNotEmpty) {
          recs = await _repo.search(query, type: MusicType.track, limit: 10);
        }
      }
      if (recs.isNotEmpty) {
        final existingIds = state.queue.map((t) => t.id).toSet();
        final filtered = recs
            .where((t) => !existingIds.contains(t.id) && t.id != currentTrack.id)
            .toList();
        if (filtered.isNotEmpty) {
          state = state.copyWith(queue: [...state.queue, ...filtered]);
        }
      }
    } catch (e, st) {
      dev.log('Autoplay recommendations error: $e\n$st', name: 'sonic-drip');
    } finally {
      _fetchingRecommendations = false;
    }
  }

  Future<void> _fetchRecommendationsAndPlayNext(Track? currentTrack) async {
    if (currentTrack == null) return;
    if (_fetchingRecommendations) return;
    _fetchingRecommendations = true;
    state = state.copyWith(playback: state.playback.copyWith(status: PlaybackStatus.loading));
    try {
      var recs = await _repo.getRecommendations(currentTrack.id, currentTrack.source, limit: 10);
      if (recs.isEmpty) {
        String query = currentTrack.artistName;
        if (query.isEmpty || query.toLowerCase() == 'unknown artist') {
          final words = currentTrack.name.split(' ');
          query = words.take(2).join(' ');
        }
        if (query.trim().isNotEmpty) {
          recs = await _repo.search(query, type: MusicType.track, limit: 10);
        }
      }
      if (recs.isNotEmpty) {
        final existingIds = state.queue.map((t) => t.id).toSet();
        final filtered = recs
            .where((t) => !existingIds.contains(t.id) && t.id != currentTrack.id)
            .toList();
        if (filtered.isNotEmpty) {
          final newQueue = [...state.queue, ...filtered];
          for (final nextTrack in filtered) {
            try {
              await _playTrack(nextTrack, newQueue);
              if (state.playback.status == PlaybackStatus.playing ||
                  state.playback.status == PlaybackStatus.loading) {
                return;
              }
            } catch (e) {
              dev.log('Autoplay: failed to play ${nextTrack.name}, trying next: $e', name: 'sonic-drip');
            }
          }
        }
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
      resolvedTrack = await _resolveDripBashUrl(track);
      if (resolvedTrack == null) {
        state = state.copyWith(
          playback: state.playback.copyWith(status: PlaybackStatus.idle),
        );
        return;
      }
    }

    final previewUrl = resolvedTrack.previewUrl;
    final updatedQueue = state.queue
        .map((t) => t.id == resolvedTrack!.id ? resolvedTrack : t)
        .toList();

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
        if (_handler != null) {
          await _handler!.playTrack(
            id: resolvedTrack.id,
            url: previewUrl,
            title: resolvedTrack.name,
            artist: resolvedTrack.artistName,
            album: resolvedTrack.albumName,
            artworkUrl: resolvedTrack.imageUrl,
            duration: resolvedTrack.durationMs != null
                ? Duration(milliseconds: resolvedTrack.durationMs!)
                : null,
          );
        } else {
          await _player.setUrl(previewUrl);
          _player.play();
        }
        state = state.copyWith(
          playback: state.playback.copyWith(
            status: PlaybackStatus.playing,
            duration: _player.duration ?? Duration.zero,
          ),
        );
        // Record listen history (fire-and-forget).
        try {
          ref.read(musicLibraryProvider.notifier).addToHistory(resolvedTrack);
        } catch (_) {}
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
    }
  }
}

// ─── Track copyWith — uses the public extension from music_repository.dart ───
