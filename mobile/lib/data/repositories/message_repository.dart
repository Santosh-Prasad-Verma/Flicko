import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/command_autocomplete.dart';

class MessageRepository {
  final Dio _dio;
  final AppwriteStorageService _appwriteStorage;

  MessageRepository(this._dio, this._appwriteStorage);

  Future<List<FlickoMessage>> getMessages(
    String channelId, {
    DateTime? cursor,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get('/api/v1/channels/$channelId/messages', queryParameters: {
        'limit': limit,
        if (cursor != null) 'before': cursor.toIso8601String(),
      });
      final List<dynamic> list = response.data as List<dynamic>;
      return list.map((json) => FlickoMessage.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> sendMessage({
    required String channelId,
    required String content,
    String? replyToId,
    bool isSilent = false,
    List<FlickoAttachment>? attachments,
  }) async {
    final response = await _dio.post('/api/v1/channels/$channelId/messages', data: {
      'content': content,
      'type': replyToId != null ? 'reply' : 'default',
      'reply_to_id': replyToId,
      'is_silent': isSilent,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
    });
    return response.data['id'] as String;
  }

  Future<String> uploadAttachment(File file, String userId, String channelId) async {
    return await _appwriteStorage.uploadAttachment(file, userId, channelId);
  }

  Future<void> editMessage(String messageId, String content) async {
    await _dio.patch('/api/v1/messages/$messageId', data: {'content': content});
  }

  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/api/v1/messages/$messageId');
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    await _dio.post('/api/v1/messages/$messageId/reactions', data: {'emoji': emoji});
  }

  Future<String> createThread(String messageId, {String? title}) async {
    final response = await _dio.post('/api/v1/messages/$messageId/threads', data: {
      if (title != null) 'title': title,
    });
    return response.data['id'] as String;
  }

  Future<List<FlickoMessage>> getThreadReplies(String threadId, {int limit = 50}) async {
    try {
      final response = await _dio.get('/api/v1/threads/$threadId/messages', queryParameters: {'limit': limit});
      final List<dynamic> list = response.data as List<dynamic>;
      return list.map((json) => FlickoMessage.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> replyToThread(String threadId, String content, {List<FlickoAttachment>? attachments}) async {
    final response = await _dio.post('/api/v1/threads/$threadId/messages', data: {
      'content': content,
      if (attachments != null) 'attachments': attachments.map((e) => e.toJson()).toList(),
    });
    return response.data['id'] as String;
  }

  Future<FlickoMessage?> getById(String messageId) async {
    try {
      final response = await _dio.get('/api/v1/messages/$messageId');
      return FlickoMessage.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> togglePinMessage(String messageId, bool pinned) async {
    await _dio.post('/api/v1/messages/$messageId/pin', data: {'pinned': pinned});
  }

  Future<void> sendSystemMessage(String channelId, String content) async {
    await _dio.post('/api/v1/channels/$channelId/messages', data: {
      'content': content,
      'type': 'system',
    });
  }

  RealtimeChannel subscribeToTyping(String channelId, void Function(String userId, bool isTyping) onTyping) {
    return RealtimeChannel();
  }

  Future<void> sendTyping(String channelId, String userId, bool isTyping) async {
    try {
      await _dio.post('/api/v1/channels/$channelId/typing', data: {'is_typing': isTyping});
    } catch (_) {}
  }

  RealtimeChannel subscribeToChannel(String channelId, void Function(PostgresChangeEvent event, Map<String, dynamic> payload) onChange) {
    return RealtimeChannel();
  }

  Future<List<CommandDefinition>> getCommandDefinitions() async {
    try {
      final response = await _dio.get('/api/v1/commands');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => CommandDefinition.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> invokeCommand({
    required String command,
    required String channelId,
    required String serverId,
    Map<String, dynamic>? options,
  }) async {
    final response = await _dio.post('/api/v1/commands/invoke', data: {
      'command_name': command,
      'channel_id': channelId,
      'server_id': serverId,
      'options': options ?? {},
    });
    return response.data as Map<String, dynamic>?;
  }
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    ref.watch(dioProvider),
    ref.watch(appwriteStorageServiceProvider),
  );
});
