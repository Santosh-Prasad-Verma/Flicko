import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/server_channels/voice/presentation/controllers/watch_together_controller.dart';

void main() {
  group('WatchTogetherState Unit Tests', () {
    test('default state has Auto quality and empty availableQualities', () {
      const state = WatchTogetherState();
      expect(state.selectedQuality, 'Auto');
      expect(state.availableQualities, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('copyWith correctly updates selectedQuality and availableQualities', () {
      const initialState = WatchTogetherState();
      final updatedState = initialState.copyWith(
        selectedQuality: '1080p',
        availableQualities: {
          'Auto': 'https://stream.auto',
          '1080p': 'https://stream.1080p',
          '720p': 'https://stream.720p',
        },
      );

      expect(updatedState.selectedQuality, '1080p');
      expect(updatedState.availableQualities.length, 3);
      expect(updatedState.availableQualities['1080p'], 'https://stream.1080p');
    });
  });
}
