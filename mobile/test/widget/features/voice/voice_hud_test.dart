import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart';

class FakeVoiceController extends VoiceController {
  final VoiceState _initialState;
  FakeVoiceController(this._initialState);

  @override
  VoiceState build() {
    return _initialState;
  }

  void updateState(VoiceState newState) {
    state = newState;
  }

  bool toggleMuteCalled = false;
  bool toggleDeafenCalled = false;
  bool leaveChannelCalled = false;

  @override
  Future<void> toggleMute() async {
    toggleMuteCalled = true;
  }

  @override
  Future<void> toggleDeafen() async {
    toggleDeafenCalled = true;
  }

  @override
  Future<void> leaveChannel() async {
    leaveChannelCalled = true;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio'),
      (methodCall) async {
        if (methodCall.method == 'init') {
          return {'id': 'test_player_id'};
        }
        return null;
      },
    );
  });

  group('VoiceHUD Widget Tests', () {
    testWidgets('VoiceHUD is hidden when state is disconnected', (tester) async {
      final fakeController = FakeVoiceController(const VoiceState(isConnected: false, isConnecting: false));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VoiceHUD(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VoiceHUD), findsOneWidget);
      expect(find.byType(Container), findsNothing); // const SizedBox.shrink()
    });

    testWidgets('VoiceHUD shows "Connecting..." when isConnecting is true', (tester) async {
      final fakeController = FakeVoiceController(const VoiceState(isConnecting: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VoiceHUD(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Connecting...'), findsOneWidget);
    });

    testWidgets('VoiceHUD shows active voice status and buttons when isConnected is true', (tester) async {
      final fakeController = FakeVoiceController(const VoiceState(isConnected: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VoiceHUD(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('in Voice'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('Tapping mute button calls toggleMute on controller', (tester) async {
      final fakeController = FakeVoiceController(const VoiceState(isConnected: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VoiceHUD(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();

      expect(fakeController.toggleMuteCalled, isTrue);
    });

    testWidgets('Tapping leave button calls leaveChannel on controller', (tester) async {
      final fakeController = FakeVoiceController(const VoiceState(isConnected: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VoiceHUD(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();

      expect(fakeController.leaveChannelCalled, isTrue);
    });
  });
}
