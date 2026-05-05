import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Provider for AudioService
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

/// Audio Service
/// 
/// Manages audio playback for voice calls, soundboard, and other audio features.
/// Ensures proper audio session configuration and background audio support.
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  AudioSession? _session;
  
  bool _initialized = false;
  bool _isInCall = false;

  // Streams
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _processingStateController = StreamController<ProcessingState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _callStateController = StreamController<bool>.broadcast();

  /// Stream of playing state
  Stream<bool> get onPlayingChanged => _playingController.stream;
  
  /// Stream of position updates
  Stream<Duration> get onPositionChanged => _positionController.stream;
  
  /// Stream of duration updates
  Stream<Duration?> get onDurationChanged => _durationController.stream;
  
  /// Stream of processing state
  Stream<ProcessingState> get onProcessingStateChanged => _processingStateController.stream;
  
  /// Stream of volume changes
  Stream<double> get onVolumeChanged => _volumeController.stream;
  
  /// Stream of call state changes
  Stream<bool> get onCallStateChanged => _callStateController.stream;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Configure audio session for voice calls
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Listen to audio session interruptions
      _session!.interruptionEventStream.listen(_handleInterruption);

      // Set up player listeners
      _player.playingStream.listen((playing) {
        _playingController.add(playing);
      });

      _player.positionStream.listen((position) {
        _positionController.add(position);
      });

      _player.durationStream.listen((duration) {
        _durationController.add(duration);
      });

      _player.processingStateStream.listen((state) {
        _processingStateController.add(state);
      });

      _player.volumeStream.listen((volume) {
        _volumeController.add(volume);
      });

      _initialized = true;
      debugPrint('✅ AudioService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing AudioService: $e');
    }
  }

  /// Handle audio session interruptions
  void _handleInterruption(AudioInterruptionEvent event) {
    debugPrint('🔊 Audio interruption: ${event.type}');
    
    if (event.begin) {
      // Another app is starting audio
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Lower volume temporarily
          setVolume(0.3);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // Pause playback
          if (_player.playing) {
            _player.pause();
          }
          break;
      }
    } else {
      // Interruption ended
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Restore volume
          setVolume(1.0);
          break;
        case AudioInterruptionType.pause:
          // Resume playback if we were playing
          _player.play();
          break;
        case AudioInterruptionType.unknown:
          break;
      }
    }
  }

  /// Start a voice call session
  Future<void> startCallSession() async {
    if (!_initialized) await initialize();

    _isInCall = true;
    _callStateController.add(true);

    // Configure for voice call
    await _session!.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    await _session!.setActive(true);
    debugPrint('📞 Call session started');
  }

  /// End voice call session
  Future<void> endCallSession() async {
    _isInCall = false;
    _callStateController.add(false);

    await _session?.setActive(false);
    
    // Reset to default configuration
    await _session?.configure(const AudioSessionConfiguration.music());
    
    debugPrint('📞 Call session ended');
  }

  /// Play audio from URL (for soundboard, voice messages, etc.)
  Future<void> playUrl(String url) async {
    if (!_initialized) await initialize();

    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint('❌ Error playing URL: $e');
    }
  }

  /// Play audio from file path
  Future<void> playFile(String filePath) async {
    if (!_initialized) await initialize();

    try {
      await _player.setFilePath(filePath);
      await _player.play();
    } catch (e) {
      debugPrint('❌ Error playing file: $e');
    }
  }

  /// Play audio from bytes (for received voice messages)
  Future<void> playBytes(List<int> bytes, {String? mimeType}) async {
    if (!_initialized) await initialize();

    try {
      await _player.setAudioSource(
        CustomAudioSource(bytes, mimeType: mimeType),
      );
      await _player.play();
    } catch (e) {
      debugPrint('❌ Error playing bytes: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.play();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Set loop mode
  Future<void> setLoopMode(LoopMode loopMode) async {
    await _player.setLoopMode(loopMode);
  }

  /// Get current position
  Duration get position => _player.position;

  /// Get current duration
  Duration? get duration => _player.duration;

  /// Check if playing
  bool get isPlaying => _player.playing;

  /// Check if in call
  bool get isInCall => _isInCall;

  /// Enable background playback
  Future<void> enableBackgroundPlayback() async {
    await _player.setAndroidAudioAttributes(const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      flags: AndroidAudioFlags.audibilityEnforced,
      usage: AndroidAudioUsage.voiceCommunication,
    ));
  }

  /// Disable background playback
  Future<void> disableBackgroundPlayback() async {
    await _player.setAndroidAudioAttributes(const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.unknown,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.unknown,
    ));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
    _playingController.close();
    _positionController.close();
    _durationController.close();
    _processingStateController.close();
    _volumeController.close();
    _callStateController.close();
  }
}

/// Custom audio source for playing bytes
class CustomAudioSource extends StreamAudioSource {
  final List<int> bytes;
  final String? mimeType;

  CustomAudioSource(this.bytes, {this.mimeType});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.fromIterable([bytes.sublist(start, end)]),
      contentType: mimeType ?? 'audio/mpeg',
    );
  }
}

/// Audio playback state
class AudioPlaybackState {
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final double volume;
  final ProcessingState processingState;
  final bool isInCall;

  AudioPlaybackState({
    required this.isPlaying,
    required this.position,
    this.duration,
    required this.volume,
    required this.processingState,
    required this.isInCall,
  });

  factory AudioPlaybackState.initial() {
    return AudioPlaybackState(
      isPlaying: false,
      position: Duration.zero,
      duration: null,
      volume: 1.0,
      processingState: ProcessingState.idle,
      isInCall: false,
    );
  }

  AudioPlaybackState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    ProcessingState? processingState,
    bool? isInCall,
  }) {
    return AudioPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      processingState: processingState ?? this.processingState,
      isInCall: isInCall ?? this.isInCall,
    );
  }
}
