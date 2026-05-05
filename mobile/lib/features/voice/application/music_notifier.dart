import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/data/models/music_model.dart';
import 'package:mobile/features/data/services/music_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'music_notifier.freezed.dart';

@freezed
class MusicState with _$MusicState {
  const factory MusicState({
    @Default([]) List<MusicItem> searchResults,
    @Default([]) List<MusicItem> queue,
    MusicItem? nowPlaying,
    @Default(false) bool isPaused,
    @Default(false) bool isLoading,
    @Default(0.5) double volume,
    String? error,
  }) = _MusicState;
}

final musicNotifierProvider = StateNotifierProvider<MusicNotifier, MusicState>((ref) {
  return MusicNotifier(ref.watch(musicServiceProvider));
});

class MusicNotifier extends StateNotifier<MusicState> {
  final MusicService _musicService;

  MusicNotifier(this._musicService) : super(const MusicState());

  Future<void> search(String query, {MusicType type = MusicType.track}) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await _musicService.searchMusic(query: query, type: type);
      state = state.copyWith(searchResults: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Search failed');
    }
  }

  void addToQueue(MusicItem item) {
    final newQueue = [...state.queue, item];
    state = state.copyWith(
      queue: newQueue,
      nowPlaying: state.nowPlaying ?? item,
    );
  }

  void removeFromQueue(String id) {
    final newQueue = state.queue.where((item) => item.id != id).toList();
    state = state.copyWith(queue: newQueue);
  }

  void skipForward() {
    if (state.queue.isEmpty) return;
    
    // In a real app, we'd move to the next item
    final currentIndex = state.nowPlaying != null 
        ? state.queue.indexWhere((item) => item.id == state.nowPlaying!.id)
        : -1;
        
    if (currentIndex != -1 && currentIndex < state.queue.length - 1) {
      state = state.copyWith(nowPlaying: state.queue[currentIndex + 1]);
    } else if (state.queue.isNotEmpty) {
      // Loop or stop
      state = state.copyWith(nowPlaying: state.queue.first);
    }
  }

  void togglePlayPause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void stop() {
    state = state.copyWith(
      nowPlaying: null,
      isPaused: false,
      queue: [],
    );
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }
}
