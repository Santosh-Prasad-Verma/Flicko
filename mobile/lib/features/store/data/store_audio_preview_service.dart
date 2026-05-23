import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPreviewState { idle, loading, playing, paused, error }

class AudioPreviewStatus {
  final String? productId;
  final AudioPreviewState state;
  final String? errorMessage;

  const AudioPreviewStatus({
    this.productId,
    this.state = AudioPreviewState.idle,
    this.errorMessage,
  });

  AudioPreviewStatus copyWith({
    String? productId,
    AudioPreviewState? state,
    String? errorMessage,
  }) {
    return AudioPreviewStatus(
      productId: productId ?? this.productId,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final storeAudioPreviewProvider = NotifierProvider<StoreAudioPreviewNotifier, AudioPreviewStatus>(StoreAudioPreviewNotifier.new);

class StoreAudioPreviewNotifier extends Notifier<AudioPreviewStatus> {
  late AudioPlayer _player;

  @override
  AudioPreviewStatus build() {
    _player = AudioPlayer();
    
    ref.onDispose(() {
      _player.dispose();
    });

    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = const AudioPreviewStatus(state: AudioPreviewState.idle);
      }
    });

    return const AudioPreviewStatus();
  }

  Future<void> playPreview(String productId, String audioUrl) async {
    try {
      if (state.productId == productId && state.state == AudioPreviewState.playing) {
        await pause();
        return;
      }

      if (state.productId == productId && state.state == AudioPreviewState.paused) {
        state = state.copyWith(state: AudioPreviewState.playing);
        // ignore: unawaited_futures
        _player.play();
        return;
      }

      await _player.stop();
      state = AudioPreviewStatus(productId: productId, state: AudioPreviewState.loading);

      await _player.setUrl(audioUrl);
      state = state.copyWith(state: AudioPreviewState.playing);
      // ignore: unawaited_futures
      _player.play();
    } catch (e) {
      state = AudioPreviewStatus(productId: productId, state: AudioPreviewState.error, errorMessage: e.toString());
    }
  }

  Future<void> pause() async {
    if (state.state == AudioPreviewState.playing) {
      await _player.pause();
      state = state.copyWith(state: AudioPreviewState.paused);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AudioPreviewStatus();
  }
}
