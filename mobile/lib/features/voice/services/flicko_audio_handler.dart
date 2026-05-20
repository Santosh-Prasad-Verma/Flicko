import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Routes [just_audio] playback through `audio_service` so the system
/// surfaces media controls on the Android lock screen, in the notification
/// shade, and on iOS Control Center / Dynamic Island.
///
/// Initialise once from `main.dart`:
///
///     final flickoAudio = await AudioService.init(
///       builder: () => FlickoAudioHandler(),
///       config: const AudioServiceConfig(
///         androidNotificationChannelId: 'tech.focko.flicko.audio',
///         androidNotificationChannelName: 'Flicko Music',
///         androidNotificationOngoing: true,
///         androidStopForegroundOnPause: true,
///       ),
///     );
///
/// Then call `flickoAudio.playTrack(...)` whenever a track starts.
class FlickoAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  FlickoAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        // Auto-advance hooks can plug in here.
      }
    });
  }

  AudioPlayer get player => _player;

  /// Loads a track and announces it to the system media session.
  Future<void> playTrack({
    required String id,
    required String url,
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
    Duration? duration,
  }) async {
    final item = MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: (artworkUrl != null && artworkUrl.isNotEmpty)
          ? Uri.tryParse(artworkUrl)
          : null,
    );
    mediaItem.add(item);
    await _player.setUrl(url);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Wire to your queue notifier; left intentionally empty so consumers
    // can override or call from outside.
  }

  @override
  Future<void> skipToPrevious() async {
    // Same as skipToNext — wire to your queue notifier.
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
