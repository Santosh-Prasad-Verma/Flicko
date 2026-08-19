import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';

class ServerSettingsRepository {
  final Dio _dio;

  ServerSettingsRepository(this._dio);

  Future<Map<String, dynamic>> getServerDetails(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId');
      if (response.data != null && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return {};
  }

  Future<void> updateServer(String serverId, Map<String, dynamic> updates) async {
    try {
      await _dio.patch('/api/v1/servers/$serverId', data: updates);
    } catch (_) {}
  }

  Future<int> getMembersCount(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/members');
      if (response.data != null && response.data is List) {
        return (response.data as List).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<int> getChannelsCount(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/channels');
      if (response.data != null && response.data is List) {
        return (response.data as List).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<int> getRolesCount(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/roles');
      if (response.data != null && response.data is List) {
        return (response.data as List).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<Map<String, dynamic>>> getServerMembers(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/members');
      if (response.data != null && response.data is List) {
        return (response.data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> isServerOwner(String serverId) async {
    try {
      final server = await getServerDetails(serverId);
      final meResponse = await _dio.get('/api/v1/users/@me');
      final myId = meResponse.data?['id'];
      return server['owner_id'] == myId;
    } catch (_) {
      return false;
    }
  }
}

final serverSettingsRepositoryProvider = Provider<ServerSettingsRepository>((ref) {
  return ServerSettingsRepository(ref.watch(dioProvider));
});
