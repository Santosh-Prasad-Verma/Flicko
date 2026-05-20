import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServerSettingsRepository {
  final SupabaseClient _supabase;

  ServerSettingsRepository(this._supabase);

  Future<Map<String, dynamic>> getServerDetails(String serverId) async {
    final data = await _supabase
        .from('servers')
        .select('*')
        .eq('id', serverId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateServer(String serverId, Map<String, dynamic> updates) async {
    await _supabase.from('servers').update(updates).eq('id', serverId);
  }

  Future<int> getMembersCount(String serverId) async {
    final res = await _supabase
        .from('server_members')
        .select('id')
        .eq('server_id', serverId);
    return (res as List).length;
  }

  Future<int> getChannelsCount(String serverId) async {
    final res = await _supabase
        .from('channels')
        .select('id')
        .eq('server_id', serverId);
    return (res as List).length;
  }

  Future<int> getRolesCount(String serverId) async {
    final res = await _supabase
        .from('roles')
        .select('id')
        .eq('server_id', serverId);
    return (res as List).length;
  }

  Future<List<Map<String, dynamic>>> getServerMembers(String serverId) async {
    final res = await _supabase
        .from('server_members')
        .select('*, profile:profiles(*)')
        .eq('server_id', serverId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<bool> isServerOwner(String serverId) async {
    final userId = _supabase.auth.currentSession?.user.id;
    if (userId == null) return false;
    final data = await _supabase
        .from('servers')
        .select('owner_id')
        .eq('id', serverId)
        .maybeSingle();
    return data?['owner_id'] == userId;
  }
}

final serverSettingsRepositoryProvider = Provider<ServerSettingsRepository>((ref) {
  return ServerSettingsRepository(Supabase.instance.client);
});
