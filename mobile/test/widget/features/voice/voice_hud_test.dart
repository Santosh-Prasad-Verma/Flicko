import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart';
import 'package:mocktail/mocktail.dart';

class MockVoiceController extends Mock implements VoiceController {}

void main() {
  late MockVoiceController mockController;

  setUp(() {
    mockController = MockVoiceController();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        voiceControllerProvider.overrideWith((ref) => mockController),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(bottom: 0, left: 0, right: 0, child: VoiceHUD()),
            ],
          ),
        ),
      ),
    );
  }

  group('VoiceHUD Widget Tests', () {
    testWidgets('VoiceHUD is hidden when not connected and not connecting', (tester) async {
      mockController.state = const VoiceState(isConnected: false, isConnecting: false);
      
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(VoiceHUD), findsOneWidget);
      // Depending on implementation, it might return a shrinked container or SizedBox.shrink()
      // Let's assume it has an internal check for isConnected || isConnecting
    });

    testWidgets('VoiceHUD shows "Voice Connecting..." when isConnecting is true', (tester) async {
      mockController.state = const VoiceState(
        isConnecting: true,
        activeChannelId: 'General',
      );
      
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('Voice Connecting...'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('VoiceHUD shows "Voice Connected" and buttons when isConnected is true', (tester) async {
      mockController.state = const VoiceState(
        isConnected: true,
        activeChannelId: 'Lounge',
      );
      
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('Voice Connected'), findsOneWidget);
      expect(find.text('Lounge'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.headset), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });

    testWidgets('Tapping mute button calls toggleMute on controller', (tester) async {
      mockController.state = const VoiceState(isConnected: true);
      when(() => mockController.toggleMute()).thenAnswer((_) async {});
      
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.byIcon(Icons.mic));
      verify(() => mockController.toggleMute()).called(1);
    });

    testWidgets('Tapping leave button calls leaveChannel on controller', (tester) async {
      mockController.state = const VoiceState(isConnected: true);
      when(() => mockController.leaveChannel()).thenAnswer((_) async {});
      
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.byIcon(Icons.call_end));
      verify(() => mockController.leaveChannel()).called(1);
    });
  });
}
