import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/pinned_messages_sheet.dart';

void main() {
  group('PinnedMessagesSheet Widget Tests', () {
    testWidgets('shows loading state when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinnedMessagesSheet(
              pinnedMessages: [],
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when pinnedMessages is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinnedMessagesSheet(
              pinnedMessages: [],
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('No Pinned Messages'), findsOneWidget);
      expect(find.text('Pinned Messages'), findsOneWidget);
    });

    testWidgets('renders list of pinned messages correctly', (tester) async {
      final sampleMessage = FlickoMessage(
        id: 'msg-1',
        channelId: 'ch-1',
        authorId: 'u-1',
        content: 'Pinned test message content',
        type: 'default',
        createdAt: DateTime(2026, 7, 25, 12, 0),
        author: UserModel(
          id: 'u-1',
          username: 'testuser',
          displayName: 'Test User',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      bool jumped = false;
      bool unpinned = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinnedMessagesSheet(
              pinnedMessages: [sampleMessage],
              onJumpToMessage: (msg) {
                jumped = true;
              },
              onUnpinMessage: (msg) {
                unpinned = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Pinned Messages'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Pinned test message content'), findsOneWidget);

      // Tap unpin icon
      final unpinButton = find.byTooltip('Unpin Message');
      expect(unpinButton, findsOneWidget);
      await tester.tap(unpinButton);
      expect(unpinned, isTrue);

      // Tap Jump to message
      final jumpLink = find.text('Jump to message →');
      expect(jumpLink, findsOneWidget);
      await tester.tap(jumpLink);
      expect(jumped, isTrue);
    });
  });
}
