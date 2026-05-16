import 'package:audio_session/audio_session.dart';
import 'dart:developer' as dev;

class AudioSessionService {
  static Future<void> configure() async {
    final session = await AudioSession.instance;
    
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
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

    // Handle interruptions (phone calls, Siri, etc.)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        dev.log('Audio interruption began: ${event.type}');
        // VoiceController will handle the actual audio track pausing
      } else {
        dev.log('Audio interruption ended');
        // VoiceController will handle the actual audio track resuming
      }
    });

    dev.log('AudioSession configured for Voice Chat');
  }

  static Future<bool> activate() async {
    final session = await AudioSession.instance;
    return await session.setActive(true);
  }

  static Future<void> deactivate() async {
    final session = await AudioSession.instance;
    await session.setActive(false);
  }
}
