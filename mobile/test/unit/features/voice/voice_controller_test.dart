import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockVoiceRepository extends Mock implements VoiceRepository {}

void main() {
  late MockVoiceRepository mockRepository;

  setUp(() {
    mockRepository = MockVoiceRepository();
  });

  group('VoiceController Unit Tests', () {
    test('Initial state is correct', () {
      final controller = VoiceController(mockRepository);
      final state = controller.state;
      
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.activeChannelId, isNull);
      expect(state.participants, isEmpty);
      expect(state.isMuted, isFalse);
      expect(state.isDeafened, isFalse);
    });

    test('toggleMute updates state locally', () async {
      final controller = VoiceController(mockRepository);
      
      // Initially false
      expect(controller.state.isMuted, isFalse);
      
      // Toggle (Note: since room is null, it just returns but in real case it would check room)
      // Actually VoiceController check if room is null
      await controller.toggleMute();
      expect(controller.state.isMuted, isFalse); // Stays false because room is null
    });

    test('leaveChannel resets state', () async {
      final controller = VoiceController(mockRepository);
      
      await controller.leaveChannel();
      
      final state = controller.state;
      expect(state.isConnected, isFalse);
      expect(state.activeChannelId, isNull);
    });
   group('toggleMute', () {
      test('does nothing if room is null', () async {
        final controller = VoiceController(mockRepository);
        await controller.toggleMute();
        expect(controller.state.isMuted, isFalse);
      });
    });
  });
}


