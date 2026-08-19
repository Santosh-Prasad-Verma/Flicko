import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/data/models/channel_model.dart';
import 'package:mobile/data/models/user_model.dart';

class ServerRepository {
  final Dio _dio;

  ServerRepository(this._dio);

  Future<List<ServerModel>> getUserServers(String userId) async {
    try {
      final response = await _dio.get('/api/v1/users/@me/servers');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => ServerModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ChannelModel>> getServerChannels(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/channels');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => ChannelModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ServerModel?> getServer(String id) async {
    try {
      final response = await _dio.get('/api/v1/servers/$id');
      return ServerModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      return null;
    }
  }

  Future<List<ServerModel>> getDiscoverableServers() async {
    try {
      final response = await _dio.get('/api/v1/servers/discover');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => ServerModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> joinServer(String serverId, String userId) async {
    await _dio.post('/api/v1/servers/$serverId/join');
  }

  Future<ServerModel> createServer({
    required String name,
    required String ownerId,
    String? iconUrl,
  }) async {
    final response = await _dio.post('/api/v1/servers', data: {
      'name': name,
      if (iconUrl != null) 'icon': iconUrl,
    });
    return ServerModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<UserModel>> getServerMembers(String serverId) async {
    try {
      final response = await _dio.get('/api/v1/servers/$serverId/members');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(ref.watch(dioProvider));
});
