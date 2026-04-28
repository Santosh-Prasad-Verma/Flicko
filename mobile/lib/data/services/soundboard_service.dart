import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/clerk_auth_service.dart';

final soundboardServiceProvider = Provider<SoundboardService>((ref) {
  return SoundboardService(Supabase.instance.client);
});

class SoundboardService {
  final SupabaseClient _supabase;

  SoundboardService(this._supabase);

  Future<List<SoundboardSound>> getServerSounds(String serverId) async {
    final response = await _supabase
        .from('soundboard_sounds')
        .select()
        .eq('server_id', serverId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => SoundboardSound.fromJson(json)).toList();
  }

  Future<List<SoundboardSound>> getFavoriteSounds() async {
    final userId = ClerkAuthService.currentAuthState?.user?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('soundboard_favorites')
        .select('sound:sound_id(*)')
        .eq('user_id', userId);

    return (response as List)
        .map((json) => SoundboardSound.fromJson(json['sound'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleFavorite(String soundId) async {
    final userId = ClerkAuthService.currentAuthState?.user?.id;
    if (userId == null) return;

    final existing = await _supabase
        .from('soundboard_favorites')
        .select()
        .eq('user_id', userId)
        .eq('sound_id', soundId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('soundboard_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('sound_id', soundId);
    } else {
      await _supabase.from('soundboard_favorites').insert({
        'user_id': userId,
        'sound_id': soundId,
      });
    }
  }

  Future<void> playSound(String soundId) async {
    // Analytics tracking for trending sounds
    await _supabase.rpc('increment_sound_plays', params: {'sound_id': soundId});
  }
}
