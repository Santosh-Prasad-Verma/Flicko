// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Run getMessages query and verify if it succeeds or throws', () async {
    final client = SupabaseClient(
      'https://zliclxzqkopxgnlwlqsu.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaWNseHpxa29weGdubHdscXN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDcxNzI1MywiZXhwIjoyMDg2MjkzMjUzfQ.GD4F8tYxvji6TQmu7x65yHTUwBOSsmSqFQM0PeTLOio',
    );

    const channelId = '2be89bfc-b942-4f7b-a440-f7a5e7867736';

    try {
      final response = await client.from('messages').select('''
          *,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at),
          reactions(emoji, user_id),
          attachments(id, url, content_type:mime_type, filename, size, width, height),
          replyTo:messages!reply_to_id(
            id,
            content,
            type,
            author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at)
          )
        ''').eq('channel_id', channelId).isFilter('thread_id', null);

      print('Query succeeded! Number of messages: ${response.length}');
      expect(response, isNotNull);
    } catch (e, st) {
      print('Query failed with error: $e');
      print(st);
      rethrow;
    }
  });
}
