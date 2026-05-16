import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';

/// Repository for handling channel message-related data operations.
/// 
/// Interacts with Supabase and the backend API to fetch message history,
/// handle real-time subscriptions, and perform message mutations.
class MessageRepository {
  final SupabaseClient _client;
  final Dio _dio;
  final AppwriteStorageService _appwriteStorage;

  MessageRepository(this._client, this._dio, this._appwriteStorage);

  /// Fetches a page of messages for a specific [channelId].
  /// Uses [cursor] (timestamp) for infinite scrolling.
  Future<List<FlickoMessage>> getMessages(
    String channelId, {
    DateTime? cursor,
    int limit = 50,
  }) async {
    try {
      var query = _client.from('messages').select('''
          *,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar),
          reactions(emoji, user_id),
          attachments(id, url, content_type:mime_type, filename, size, width, height)
        ''').eq('channel_id', channelId).isFilter('thread_id', null);

      if (cursor != null) {
        query = query.lt('created_at', cursor.toIso8601String());
      }

      final List<dynamic> response = await query.order('created_at', ascending: false).limit(limit);
      
      return response.map((json) {
        final Map<String, dynamic> msg = Map<String, dynamic>.from(json);
        
        // Ensure proper mapping to FlickoMessage structure
        msg['type'] = 'channel';
        // author_id is inherently present from DB SELECT *
        
        if (msg['author'] != null && msg['author']['avatar_url'] != null) {
          msg['author']['avatar'] = msg['author']['avatar_url'];
        }

        // Post-process reactions to aggregate by emoji (matching RN logic)
        final List<dynamic> rawReactions = msg['reactions'] ?? [];
        final Map<String, Map<String, dynamic>> reactionMap = {};
        final currentUserId = _client.auth.currentSession?.user.id;

        for (final r in rawReactions) {
          final emoji = r['emoji'] as String;
          final userId = r['user_id'] as String;
          
          if (!reactionMap.containsKey(emoji)) {
            reactionMap[emoji] = {
              'emoji': emoji,
              'count': 0,
              'me': false,
              'users': <String>[],
            };
          }
          
          final entry = reactionMap[emoji]!;
          entry['count'] = (entry['count'] as int) + 1;
          (entry['users'] as List<String>).add(userId);
          if (userId == currentUserId) entry['me'] = true;
        }
        
        msg['reactions'] = reactionMap.values.toList();
        
        // Map attachments
        final List<dynamic> rawAttachments = msg['attachments'] ?? [];
        msg['attachments'] = rawAttachments.map((a) => {
          ...a,
          'contentType': a['content_type'],
        }).toList();

        return FlickoMessage.fromJson(msg);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Sends a new message to a channel via the backend API.
  Future<String> sendMessage({
    required String channelId,
    required String content,
    String? replyToId,
    bool isSilent = false,
    List<FlickoAttachment>? attachments,
  }) async {
    final payload = {
      'content': content,
      'type': replyToId != null ? 'reply' : 'default',
      'reply_to_id': replyToId,
      'is_silent': isSilent,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
    };

    final response = await _dio.post('/api/v1/channels/$channelId/messages', data: payload);
    
    // The API returns { id: "..." }
    return response.data['id'] as String;
  }

  /// Uploads an attachment to Appwrite Storage.
  Future<String> uploadAttachment(File file, String userId, String channelId) async {
    return await _appwriteStorage.uploadAttachment(file, userId, channelId);
    /* Supabase / Cloudinary code commented as requested
    try {
      final extension = p.extension(file.path);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = 'channels/$channelId/$fileName';

      await _client.storage.from('attachments').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get signed URL for access (matching RN pattern)
      final signedUrl = await _client.storage.from('attachments').createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 1 week
      return signedUrl;
    } catch (e) {
      rethrow;
    }
    */
  }

  /// Updates an existing message's content.
  Future<void> editMessage(String messageId, String content) async {
    await _client.from('messages').update({'content': content}).eq('id', messageId);
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }

  /// Toggles a reaction on a message.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) return;

    final existing = await _client
        .from('reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      await _client.from('reactions').delete().eq('id', existing['id']);
    } else {
      await _client.from('reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  /// Creates a typing indicator subscription.
  RealtimeChannel subscribeToTyping(String channelId, void Function(String userId, bool isTyping) onTyping) {
    return _client
        .channel('typing:$channelId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            onTyping(payload['user_id'] as String, payload['is_typing'] as bool);
          },
        )
        .subscribe();
  }

  /// Sends a typing indicator.
  Future<void> sendTyping(String channelId, String userId, bool isTyping) async {
    final channel = _client.channel('typing:$channelId');
    channel.subscribe();
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': userId,
        'is_typing': isTyping,
      },
    );
  }

  /// Creates a real-time subscription for message changes in a channel.
  RealtimeChannel subscribeToChannel(String channelId, void Function(PostgresChangeEvent event, Map<String, dynamic> payload) onChange) {
    return _client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) => onChange(payload.eventType, payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reactions',
          callback: (payload) => onChange(payload.eventType, payload.newRecord),
        )
        .subscribe();
  }
}

/// Provider for [MessageRepository].
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    Supabase.instance.client,
    ref.watch(dioProvider),
    ref.watch(appwriteStorageServiceProvider),
  );
});
