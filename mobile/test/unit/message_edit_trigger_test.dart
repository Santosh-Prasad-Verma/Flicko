// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Update message to trigger handle_message_edit and verify edit history', () async {
    final client = SupabaseClient(
      'https://zliclxzqkopxgnlwlqsu.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaWNseHpxa29weGdubHdscXN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDcxNzI1MywiZXhwIjoyMDg2MjkzMjUzfQ.GD4F8tYxvji6TQmu7x65yHTUwBOSsmSqFQM0PeTLOio',
    );

    const channelId = '2be89bfc-b942-4f7b-a440-f7a5e7867736'; // Active channel
    const authorId = 'b91fad4e-a26e-4710-993e-58576a367c09';  // Tarun

    try {
      // 1. Insert message
      final payload = {
        'channel_id': channelId,
        'author_id': authorId,
        'content': 'Original Content',
        'type': 'default',
      };
      
      final insertResponse = await client.from('messages').insert(payload).select('id').single();
      final messageId = insertResponse['id'] as String;
      print('Inserted message ID: $messageId');

      // 2. Update message content (this triggers handle_message_edit)
      await client.from('messages').update({'content': 'Updated Content'}).eq('id', messageId);
      print('Updated message content to "Updated Content"');

      // 3. Verify entry in message_edit_history
      final editHistory = await client.from('message_edit_history')
          .select('*')
          .eq('message_id', messageId)
          .maybeSingle();

      print('Edit history record: $editHistory');
      expect(editHistory, isNotNull);
      expect(editHistory!['previous_content'], equals('Original Content'));

      // 4. Cleanup
      await client.from('messages').delete().eq('id', messageId);
      print('Cleaned up message');
      
      await client.from('message_edit_history').delete().eq('message_id', messageId);
      print('Cleaned up edit history manually');

    } catch (e, st) {
      print('Test failed: $e');
      print(st);
      rethrow;
    }
  });
}
