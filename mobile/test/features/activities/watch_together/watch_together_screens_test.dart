import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activities/watch_together/presentation/standalone_room_screen.dart';
import 'package:mobile/features/activities/watch_together/presentation/public_lobbies_screen.dart';

void main() {
  group('Watch Together Screen Tests', () {
    testWidgets('StandaloneRoomScreen renders form elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StandaloneRoomScreen(),
          ),
        ),
      );

      // Verify header and privacy selections are present
      expect(find.text('Create Watch Room'), findsOneWidget);
      expect(find.text('Private Room'), findsOneWidget);
      expect(find.text('Public Room'), findsOneWidget);
      
      // Verify configuration form exists
      expect(find.text('MEDIA CONFIGURATION'), findsOneWidget);
      expect(find.text('Create Room'), findsOneWidget);
    });

    testWidgets('PublicLobbiesScreen renders list and search elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PublicLobbiesScreen(),
          ),
        ),
      );

      // Verify title and search bar
      expect(find.text('Public Lobbies'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
