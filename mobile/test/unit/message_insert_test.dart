// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/models/flicko_message.dart';

void main() {
  test('Insert message and call getById to check author and exceptions', () async {
    final client = SupabaseClient(
      'https://zliclxzqkopxgnlwlqsu.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaWNseHpxa29weGdubHdscXN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDcxNzI1MywiZXhwIjoyMDg2MjkzMjUzfQ.GD4F8tYxvji6TQmu7x65yHTUwBOSsmSqFQM0PeTLOio',
    );

    const channelId = '2be89bfc-b942-4f7b-a440-f7a5e7867736'; // Active channel from previous test
    const authorId = 'b91fad4e-a26e-4710-993e-58576a367c09';  // Tarun
    
    try {
      final payload = {
        'channel_id': channelId,
        'author_id': authorId,
        'content': 'Test message from unit test',
        'type': 'default',
      };
      
      final insertResponse = await client.from('messages').insert(payload).select('id').single();
      final messageId = insertResponse['id'] as String;
      print('Inserted message ID: $messageId');

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
        ''').eq('id', messageId).maybeSingle();

      print('Select response: $response');
      expect(response, isNotNull);

      final msg = Map<String, dynamic>.from(response as Map);
      if (msg['author'] != null && msg['author']['avatar_url'] != null) {
        msg['author']['avatar'] = msg['author']['avatar_url'];
      }
      if (msg['replyTo'] is List) {
        final replyList = msg['replyTo'] as List;
        if (replyList.isEmpty) {
          msg['replyTo'] = null;
        } else {
          msg['replyTo'] = Map<String, dynamic>.from(replyList.first as Map);
        }
      }
      
      final parsed = FlickoMessage.fromJson(msg);
      print('Parsed message successfully! Author: ${parsed.author?.username}, display_name: ${parsed.author?.displayName}, avatar: ${parsed.author?.avatarUrl}');
      expect(parsed.author, isNotNull);

      // Cleanup
      await client.from('messages').delete().eq('id', messageId);
      print('Cleaned up message');
    } catch (e, st) {
      print('Test failed with error: $e');
      print(st);
      rethrow;
    }
  });
}
