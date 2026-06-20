import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/data/models/channel_model.dart';
import 'package:mobile/data/models/user_model.dart';

/// Repository for handling server and channel related data operations.
/// 
/// Interacts with Supabase to fetch server memberships, server details,
/// and channel lists.
class ServerRepository {
  final SupabaseClient _client;

  ServerRepository(this._client);

  /// Fetches all servers the given [userId] is a member of.
  Future<List<ServerModel>> getUserServers(String userId) async {
    try {
      final response = await _client
          .from('server_members')
          .select('server:servers(*)')
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;
      
      return data
          .map((row) {
            final serverData = row['server'];
            if (serverData == null) return null;
            
            // Handle if server comes back as a list (happens in some Supabase join query variations)
            if (serverData is List && serverData.isNotEmpty) {
              return ServerModel.fromJson(serverData.first as Map<String, dynamic>);
            }
            
            return ServerModel.fromJson(serverData as Map<String, dynamic>);
          })
          .whereType<ServerModel>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches all channels for a specific [serverId].
  Future<List<ChannelModel>> getServerChannels(String serverId) async {
    try {
      final response = await _client
          .from('channels')
          .select('*')
          .eq('server_id', serverId)
          .order('position', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      
      return data
          .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a specific server by [id].
  Future<ServerModel?> getServer(String id) async {
    try {
      final response = await _client
          .from('servers')
          .select('*')
          .eq('id', id)
          .single();

      return ServerModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Fetches servers available for discovery.
  Future<List<ServerModel>> getDiscoverableServers() async {
    try {
      // Fetching all servers sorted by member count for discovery
      final response = await _client
          .from('servers')
          .select('*')
          .order('member_count', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ServerModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Joins a user to a server.
  Future<void> joinServer(String serverId, String userId) async {
    try {
      await _client.from('server_members').upsert({
        'server_id': serverId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new server.
  Future<ServerModel> createServer({
    required String name,
    required String ownerId,
    String? iconUrl,
  }) async {
    try {
      final response = await _client.from('servers').insert({
        'name': name,
        'owner_id': ownerId,
        'icon': iconUrl,
      }).select().single();

      final server = ServerModel.fromJson(response as Map<String, dynamic>);

      // Automatically join the owner to the server as 'owner'
      await _client.from('server_members').insert({
        'server_id': server.id,
        'user_id': ownerId,
        'role': 'owner',
      });

      // Create a default #general channel
      await _client.from('channels').insert({
        'server_id': server.id,
        'name': 'general',
        'type': 'text',
        'position': 0,
      });

      return server;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches all members of a server.
  Future<List<UserModel>> getServerMembers(String serverId) async {
    try {
      final response = await _client
          .from('server_members')
          .select('profiles!user_id(*)')
          .eq('server_id', serverId);
      
      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((row) {
            final profile = row['profiles'];
            if (profile == null) return null;
            return UserModel.fromJson(profile as Map<String, dynamic>);
          })
          .whereType<UserModel>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}


/// Provider for [ServerRepository].
final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(Supabase.instance.client);
});
