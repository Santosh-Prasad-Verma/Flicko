// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/models/flicko_message.dart';

void main() {
  test('Query real supabase with service role and parse message', () async {
    final client = SupabaseClient(
      'https://zliclxzqkopxgnlwlqsu.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaWNseHpxa29weGdubHdscXN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDcxNzI1MywiZXhwIjoyMDg2MjkzMjUzfQ.GD4F8tYxvji6TQmu7x65yHTUwBOSsmSqFQM0PeTLOio',
    );
    
    try {
      final response = await client.from('messages').select('''
          *,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at)
      ''').order('created_at', ascending: false).limit(10);
      
      print('Raw response: $response');
      
      for (var json in response) {
        final Map<String, dynamic> msg = Map<String, dynamic>.from(json as Map);
        if (msg['author'] != null && msg['author']['avatar_url'] != null) {
          msg['author']['avatar'] = msg['author']['avatar_url'];
        }
        
        // Let's see if this parses
        try {
          final parsed = FlickoMessage.fromJson(msg);
          print('Parsed successfully: ${parsed.id}, type: ${parsed.type}');
        } catch (e, st) {
          print('Failed parsing message ${msg['id']}: $e');
          print(st);
        }
      }
    } catch (e, st) {
      print('Query failed: $e');
      print(st);
      rethrow;
    }
  });
}
