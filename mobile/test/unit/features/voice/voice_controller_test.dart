import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockVoiceRepository extends Mock implements VoiceRepository {}
class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockVoiceRepository mockRepository;
  late MockAudioPlayer mockAudioPlayer;

  setUp(() {
    mockRepository = MockVoiceRepository();
    mockAudioPlayer = MockAudioPlayer();
    
    // Stub the dispose method to avoid mocktail errors
    when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
  });

  group('VoiceController Unit Tests', () {
    test('Initial state is disconnected', () {
      final container = ProviderContainer(
        overrides: [
          voiceRepositoryProvider.overrideWithValue(mockRepository),
          audioPlayerProvider.overrideWithValue(mockAudioPlayer),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(voiceControllerProvider);

      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.isMuted, isFalse);
      expect(state.isDeafened, isFalse);
      expect(state.participants, isEmpty);
      expect(state.activeChannelId, isNull);
    });

    test('leaveChannel resets state', () async {
      final container = ProviderContainer(
        overrides: [
          voiceRepositoryProvider.overrideWithValue(mockRepository),
          audioPlayerProvider.overrideWithValue(mockAudioPlayer),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceControllerProvider.notifier);
      await controller.leaveChannel();

      final state = container.read(voiceControllerProvider);
      expect(state.isConnected, isFalse);
      expect(state.activeChannelId, isNull);
    });
  });
}
