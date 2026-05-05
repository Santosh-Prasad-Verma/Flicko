import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/models/auth_state.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

class MockVoiceRepository extends Mock implements VoiceRepository {}
class MockRef extends Mock implements Ref {}
class MockAuthNotifier extends Mock implements AuthNotifier {}

void main() {
  late MockVoiceRepository mockRepository;
  late MockRef mockRef;

  setUp(() {
    mockRepository = MockVoiceRepository();
    mockRef = MockRef();
    
    // Default mock for auth state
    when(() => mockRef.read(authNotifierProvider)).thenReturn(const AuthState.unauthenticated());
  });

  group('VoiceController Unit Tests', () {
    test('Initial state is disconnected', () {
      final controller = VoiceController(mockRepository, mockRef);
      final state = controller.debugState;
      
      expect(state.status, VoiceStatus.disconnected);
      expect(state.currentChannelId, isNull);
      expect(state.participants, isEmpty);
      expect(state.localMuted, isFalse);
      expect(state.localDeafened, isFalse);
    });

    test('toggleMute updates state locally when not connected', () async {
      final controller = VoiceController(mockRepository, mockRef);
      
      // Initially false
      expect(controller.debugState.localMuted, isFalse);
      
      // Toggle
      await controller.toggleMute();
      expect(controller.debugState.localMuted, isTrue);
      
      // Toggle back
      await controller.toggleMute();
      expect(controller.debugState.localMuted, isFalse);
    });

    test('toggleDeafen updates state locally when not connected', () async {
      final controller = VoiceController(mockRepository, mockRef);
      
      // Initially false
      expect(controller.debugState.localDeafened, isFalse);
      
      // Toggle
      await controller.toggleDeafen();
      expect(controller.debugState.localDeafened, isTrue);
      
      // Toggle back
      await controller.toggleDeafen();
      expect(controller.debugState.localDeafened, isFalse);
    });

    test('leaveChannel resets state', () {
      final controller = VoiceController(mockRepository, mockRef);
      
      // Set some state manually (if we could, but we'll use a mocked scenario)
      controller.leaveChannel();
      
      final state = controller.debugState;
      expect(state.status, VoiceStatus.disconnected);
      expect(state.currentChannelId, isNull);
    });
  });
}

// Helper to access state during tests since it's protected in StateNotifier
extension VoiceControllerTest on VoiceController {
  VoiceControllerState get debugState => state;
}
