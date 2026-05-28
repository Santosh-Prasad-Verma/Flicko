import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
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
  AudioHandler? _delegate;
  List<StreamSubscription>? _delegateSubscriptions;

  /// External callbacks wired by [SonicDripNotifier] so the notification's
  /// Next/Previous buttons can drive the queue.
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  FlickoAudioHandler() {
    _configureSession();
    _player.playbackEventStream.listen(_broadcastState);
  }

  AudioPlayer get player => _player;

  AudioHandler? get delegate => _delegate;

  void setDelegate(AudioHandler? delegate) {
    if (_delegate == delegate) return;
    _delegate = delegate;

    if (_delegateSubscriptions != null) {
      for (final sub in _delegateSubscriptions!) {
        sub.cancel();
      }
      _delegateSubscriptions = null;
    }

    if (delegate != null) {
      if (_player.playing) {
        _player.pause();
      }

      _delegateSubscriptions = [
        delegate.mediaItem.listen((item) {
          if (_delegate == delegate) {
            mediaItem.add(item);
          }
        }),
        delegate.playbackState.listen((state) {
          if (_delegate == delegate) {
            playbackState.add(state);
          }
        }),
        delegate.queue.listen((q) {
          if (_delegate == delegate) {
            queue.add(q);
          }
        }),
      ];
    } else {
      mediaItem.add(null);
      _broadcastState(_player.playbackEvent);
    }
  }

  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // configure() can throw on some emulators; non-fatal
    }
  }

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
    setDelegate(null);
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
  Future<void> play() {
    if (_delegate != null) {
      return _delegate!.play();
    }
    return _player.play();
  }

  @override
  Future<void> pause() {
    if (_delegate != null) {
      return _delegate!.pause();
    }
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    if (_delegate != null) {
      await _delegate!.stop();
    } else {
      await _player.stop();
    }
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    if (_delegate != null) {
      return _delegate!.seek(position);
    }
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_delegate != null) {
      return _delegate!.skipToNext();
    }
    if (onSkipNext != null) {
      await onSkipNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_delegate != null) {
      return _delegate!.skipToPrevious();
    }
    if (onSkipPrevious != null) {
      await onSkipPrevious!();
    }
  }

  @override
  Future<void> fastForward() {
    if (_delegate != null) {
      return _delegate!.fastForward();
    }
    return super.fastForward();
  }

  @override
  Future<void> rewind() {
    if (_delegate != null) {
      return _delegate!.rewind();
    }
    return super.rewind();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) {
    if (_delegate != null) {
      return _delegate!.click(button);
    }
    return super.click(button);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) {
    if (_delegate != null) {
      return _delegate!.customAction(name, extras);
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> skipToQueueItem(int index) {
    if (_delegate != null) {
      return _delegate!.skipToQueueItem(index);
    }
    return super.skipToQueueItem(index);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) {
    if (_delegate != null) {
      return _delegate!.addQueueItem(mediaItem);
    }
    return super.addQueueItem(mediaItem);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) {
    if (_delegate != null) {
      return _delegate!.addQueueItems(mediaItems);
    }
    return super.addQueueItems(mediaItems);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) {
    if (_delegate != null) {
      return _delegate!.insertQueueItem(index, mediaItem);
    }
    return super.insertQueueItem(index, mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) {
    if (_delegate != null) {
      return _delegate!.updateQueue(queue);
    }
    return super.updateQueue(queue);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) {
    if (_delegate != null) {
      return _delegate!.updateMediaItem(mediaItem);
    }
    return super.updateMediaItem(mediaItem);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) {
    if (_delegate != null) {
      return _delegate!.removeQueueItem(mediaItem);
    }
    return super.removeQueueItem(mediaItem);
  }

  @override
  Future<void> removeQueueItemAt(int index) {
    if (_delegate != null) {
      return _delegate!.removeQueueItemAt(index);
    }
    return super.removeQueueItemAt(index);
  }

  void _broadcastState(PlaybackEvent event) {
    if (_delegate != null) return;
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
