import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceRepository {
  final SupabaseClient _supabase;
  
  VoiceRepository(this._supabase);

  /// Fetches a LiveKit JWT token from the Supabase Edge Function.
  Future<String> getAccessToken(String channelId) async {
    try {
      final response = await _supabase.functions.invoke(
        'get-livekit-token',
        body: {'roomName': channelId},
      );
      
      if (response.status != 200) {
        throw Exception('Failed to fetch LiveKit token: ${response.data}');
      }
      
      return response.data['token'] as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Connects to a LiveKit room.
  Future<Room> connect(String token, {RoomOptions? options}) async {
    final room = Room();
    
    // In a real app, the URL would come from environment variables
    const livekitUrl = String.fromEnvironment('LIVEKIT_URL', defaultValue: 'ws://localhost:7880');
    
    await room.connect(livekitUrl, token, roomOptions: options);
    return room;
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(Supabase.instance.client);
});
