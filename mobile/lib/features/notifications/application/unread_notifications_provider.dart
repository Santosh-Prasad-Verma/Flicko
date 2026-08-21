import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// StreamProvider that yields the count of unread notifications for the currently logged-in user in real-time.
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(0);
  }

  final client = Supabase.instance.client;
  final controller = StreamController<int>();

  Future<void> updateCount() async {
    try {
      final response = await client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);
      
      final count = (response as List).length;
      if (!controller.isClosed) {
        controller.add(count);
      }
    } catch (e) {
      if (!controller.isClosed) {
        // Fallback to yielding 0 instead of crashing if there's a temporary network error
        controller.add(0);
      }
    }
  }

  // Get initial count
  updateCount();

  // Subscribe to real-time updates
  final channel = client
      .channel('public:notifications_count:user_id=eq.$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          updateCount();
        },
      );

  channel.subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
