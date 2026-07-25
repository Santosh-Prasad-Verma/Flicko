import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';

class VoiceRepository {
  final SupabaseClient _supabase;

  VoiceRepository(this._supabase);

  /// Fetches a LiveKit JWT token from the Supabase Edge Function.
  Future<String> getAccessToken(String channelId, String serverId) async {
    try {
      final response = await _supabase.functions.invoke(
        'voice-token',
        body: {'channelId': channelId, 'serverId': serverId},
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
    final room = Room(roomOptions: options ?? const RoomOptions());

    final url = AppConfig.livekitUrl.isNotEmpty
        ? AppConfig.livekitUrl
        : 'ws://localhost:7880';

    await room.connect(url, token);
    return room;
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(Supabase.instance.client);
});
