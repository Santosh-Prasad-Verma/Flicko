import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/core/config/app_config.dart';

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
          author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at),
          reactions(emoji, user_id),
          attachments(id, url, content_type:mime_type, filename, size, width, height),
          replyTo:messages!reply_to_id(
            id,
            content,
            type,
            author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at)
          )
        ''').eq('channel_id', channelId).isFilter('thread_id', null);

      if (cursor != null) {
        query = query.lt('created_at', cursor.toIso8601String());
      }

      final List<dynamic> response = await query.order('created_at', ascending: false).limit(limit);
      
      return response.map((json) {
        final Map<String, dynamic> msg = Map<String, dynamic>.from(json);
        
        // Ensure proper mapping to FlickoMessage structure
        // author_id is inherently present from DB SELECT *
        
        if (msg['author'] != null && msg['author']['avatar_url'] != null) {
          msg['author']['avatar'] = msg['author']['avatar_url'];
        }

        if (msg['replyTo'] != null && msg['replyTo']['author'] != null && msg['replyTo']['author']['avatar_url'] != null) {
          msg['replyTo']['author']['avatar'] = msg['replyTo']['author']['avatar_url'];
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
  /// Falls back to direct Supabase insert if the backend is unreachable.
  Future<String> sendMessage({
    required String channelId,
    required String content,
    String? replyToId,
    bool isSilent = false,
    List<FlickoAttachment>? attachments,
  }) async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) throw Exception('Not authenticated');

    String finalContent = content.trim();
    if (finalContent.isEmpty) {
      if (attachments != null && attachments.isNotEmpty) {
        final firstType = attachments.first.contentType.toLowerCase();
        if (firstType.startsWith('image/')) {
          finalContent = '📷 Photo';
        } else if (firstType.startsWith('video/')) {
          finalContent = '🎥 Video';
        } else if (firstType.startsWith('audio/')) {
          finalContent = '🎵 Audio';
        } else {
          finalContent = '📎 Attachment';
        }
      } else {
        finalContent = 'Empty message';
      }
    }

    final payload = <String, dynamic>{
      'channel_id': channelId,
      'author_id': userId,
      'content': finalContent,
      'type': replyToId != null ? 'reply' : 'default',
      if (replyToId != null) 'reply_to_id': replyToId,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((e) => e.toJson()).toList(),
    };

    try {
      if (AppConfig.hasApiBaseUrl) {
        final apiPayload = {
          'content': finalContent,
          'type': replyToId != null ? 'reply' : 'default',
          'reply_to_id': replyToId,
          'is_silent': isSilent,
          'attachments': attachments?.map((e) => e.toJson()).toList(),
        };
        final response = await _dio.post('/v1/channels/$channelId/messages', data: apiPayload);
        return response.data['id'] as String;
      }
      throw Exception('No API URL configured');
    } catch (apiError) {
      // Fallback: insert directly into Supabase
      developer.log(
        'API unavailable, using Supabase fallback',
        name: 'MessageRepository',
        error: apiError,
      );
      try {
        final response = await _client.from('messages').insert(payload).select('id').single();
        final messageId = response['id'] as String;

        if (attachments != null && attachments.isNotEmpty) {
          final List<Map<String, dynamic>> attachmentsPayload = attachments.map((a) => {
            'message_id': messageId,
            'filename': a.filename,
            'size': a.size,
            'mime_type': a.contentType,
            'url': a.url,
            if (a.width != null) 'width': a.width,
            if (a.height != null) 'height': a.height,
          }).toList();
          await _client.from('attachments').insert(attachmentsPayload);
        }

        return messageId;
      } catch (supabaseError) {
        developer.log(
          'Supabase fallback ALSO failed',
          name: 'MessageRepository',
          error: supabaseError,
        );
        rethrow;
      }
    }
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
    developer.log('[SupabaseRealtime] Subscribing to channel: $channelId');
    return _client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            if (record != null && record['channel_id'] == channelId) {
              developer.log('[SupabaseRealtime] Received messages change event: ${payload.eventType} in channel: $channelId, record: $record');
              onChange(payload.eventType, record);
            } else {
              developer.log('[SupabaseRealtime] Messages change event did not match channel filter (channelId: $channelId, record channel_id: ${record?['channel_id']})');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reactions',
          callback: (payload) {
            developer.log('[SupabaseRealtime] Received reactions change event: ${payload.eventType} in channel: $channelId');
            onChange(payload.eventType, payload.newRecord);
          },
        )
        .subscribe((status, error) {
          developer.log('[SupabaseRealtime] Subscription status for channel: $channelId changed to: $status, error: $error');
        });
  }

  /// Creates a thread from a message.
  Future<String> createThread(String messageId, {String? title}) async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('threads').insert({
      'message_id': messageId,
      'author_id': userId,
      if (title != null) 'title': title,
    }).select('id').single();

    return response['id'] as String;
  }

  /// Fetches thread replies for a thread.
  Future<List<FlickoMessage>> getThreadReplies(String threadId, {int limit = 50}) async {
    final response = await _client.from('messages').select('''
        *,
        author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at),
        reactions(emoji, user_id),
        attachments(id, url, content_type:mime_type, filename, size, width, height),
        replyTo:messages!reply_to_id(
          id,
          content,
          type,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at)
        )
      ''').eq('thread_id', threadId)
      .order('created_at', ascending: true)
      .limit(limit);

    final List<dynamic> rows = response;
    return rows.map((json) {
      final Map<String, dynamic> msg = Map<String, dynamic>.from(json);
      if (msg['author'] != null && msg['author']['avatar_url'] != null) {
        msg['author']['avatar'] = msg['author']['avatar_url'];
      }
      if (msg['replyTo'] != null && msg['replyTo']['author'] != null && msg['replyTo']['author']['avatar_url'] != null) {
        msg['replyTo']['author']['avatar'] = msg['replyTo']['author']['avatar_url'];
      }
      return FlickoMessage.fromJson(msg);
    }).toList();
  }

  /// Replies to a thread.
  Future<String> replyToThread(String threadId, String content, {List<FlickoAttachment>? attachments}) async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) throw Exception('Not authenticated');

    // Derive channel_id from the parent thread's original message
    // (channel_id is NOT NULL in the DB)
    final threadRow = await _client.from('threads').select('message_id').eq('id', threadId).single();
    final parentMessage = await _client.from('messages').select('channel_id').eq('id', threadRow['message_id']).single();
    final channelId = parentMessage['channel_id'] as String;

    final response = await _client.from('messages').insert({
      'channel_id': channelId,
      'thread_id': threadId,
      'author_id': userId,
      'content': content,
      'type': 'reply',
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((e) => e.toJson()).toList(),
    }).select('id').single();

    final messageId = response['id'] as String;

    if (attachments != null && attachments.isNotEmpty) {
      final List<Map<String, dynamic>> attachmentsPayload = attachments.map((a) => {
        'message_id': messageId,
        'filename': a.filename,
        'size': a.size,
        'mime_type': a.contentType,
        'url': a.url,
        if (a.width != null) 'width': a.width,
        if (a.height != null) 'height': a.height,
      }).toList();
      await _client.from('attachments').insert(attachmentsPayload);
    }

    return messageId;
  }

  /// Fetch a single message by id. Used by the Catch-Me-Up citation peek and
  /// other "jump to message" UIs. Returns null if the row is missing or the
  /// caller is not allowed to read it.
  Future<FlickoMessage?> getById(String messageId) async {
    try {
      final response = await _client.from('messages').select('''
          *,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at),
          reactions(emoji, user_id),
          attachments(id, url, content_type:mime_type, filename, size, width, height),
          replyTo:messages!reply_to_id(
            id,
            content,
            type,
            author:profiles!author_id(id, username, display_name, avatar_url:avatar, created_at)
          )
        ''').eq('id', messageId).maybeSingle();
      if (response == null) return null;
      final msg = Map<String, dynamic>.from(response as Map);
      if (msg['author'] != null && msg['author']['avatar_url'] != null) {
        msg['author']['avatar'] = msg['author']['avatar_url'];
      }
      if (msg['replyTo'] != null && msg['replyTo']['author'] != null && msg['replyTo']['author']['avatar_url'] != null) {
        msg['replyTo']['author']['avatar'] = msg['replyTo']['author']['avatar_url'];
      }
      return FlickoMessage.fromJson(msg);
    } catch (_) {
      return null;
    }
  }

  /// Pins or unpins a message using the database RPC function.
  Future<void> togglePinMessage(String messageId, bool pinned) async {
    await _client.rpc('pin_message', params: {
      'message_uuid': messageId,
      'pin_status': pinned,
    });
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
