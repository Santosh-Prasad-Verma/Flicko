// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/models/user_model.dart';

void main() {
  test('Query real supabase and parse profiles', () async {
    final client = SupabaseClient(
      'https://zliclxzqkopxgnlwlqsu.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaWNseHpxa29weGdubHdscXN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDcxNzI1MywiZXhwIjoyMDg2MjkzMjUzfQ.GD4F8tYxvji6TQmu7x65yHTUwBOSsmSqFQM0PeTLOio',
    );
    
    try {
      final response = await client.from('profiles').select().limit(50);
      print('Profiles fetched: ${response.length}');
      
      for (var json in response) {
        final Map<String, dynamic> profile = Map<String, dynamic>.from(json as Map);
        try {
          final parsed = UserModel.fromJson(profile);
          print('Parsed profile successfully: ${parsed.id}, username: ${parsed.username}');
        } catch (e, st) {
          print('Failed parsing profile ${profile['id']} (${profile['username']}): $e');
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
