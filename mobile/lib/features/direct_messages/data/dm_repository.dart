import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';

final dmRepositoryProvider = Provider<DMRepository>((ref) {
  return DMRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appwriteStorageServiceProvider),
  );
});

class DMRepository {
  final SupabaseClient _client;
  final AppwriteStorageService _appwriteStorage;

  DMRepository(this._client, this._appwriteStorage);

  /// Fetches recent DM messages for the user.
  Future<List<DMMessage>> fetchRecentMessages(String userId) async {
    try {
      final response = await _client
          .from('direct_messages')
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)')
          .or('sender_id.eq.$userId,recipient_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(500);

      return (response as List).map((json) => DMMessage.fromJson(json)).toList();
    } catch (e) {
      // Table may not exist yet or RLS may block — return empty list gracefully
      return [];
    }
  }

  /// Fetches paginated messages for a specific conversation.
  Future<List<DMMessage>> fetchMessagesWithPagination(
    String myId,
    String otherUserId, {
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('direct_messages')
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)')
          .or('and(sender_id.eq.$myId,recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.$myId)');

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false).limit(limit);
      return (response as List).map((json) => DMMessage.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Sends a direct message.
  Future<DMMessage> sendMessage({
    required String senderId,
    required String recipientId,
    required String content,
    List<DMAttachment>? attachments,
  }) async {
    try {
      final response = await _client.from('direct_messages').insert({
        'sender_id': senderId,
        'recipient_id': recipientId,
        'content': content,
        'attachments': attachments?.map((e) => e.toJson()).toList(),
      }).select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)').single();

      return DMMessage.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Uploads an attachment to Appwrite Storage.
  Future<String> uploadAttachment(File file, String userId, String conversationId) async {
    return await _appwriteStorage.uploadAttachment(file, userId, conversationId);
    /* Supabase / Cloudinary code commented as requested
    try {
      final extension = p.extension(file.path);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = 'dm/$conversationId/$fileName';

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

  /// Listens for real-time changes in the direct_messages table.
  RealtimeChannel subscribeToDMs(String userId, void Function() onUpdate) {
    return _client
        .channel('public:direct_messages:user:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  /// Targeted subscription for a specific conversation
  RealtimeChannel subscribeToConversation(String myId, String otherUserId, void Function(DMMessage newMessage) onNewMessage) {
    return _client
        .channel('dm_convo_${myId}_${otherUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            final msgJson = payload.newRecord;
            final senderId = msgJson['sender_id'];
            final recipientId = msgJson['recipient_id'];

            // Filter for this specific conversation
            if ((senderId == myId && recipientId == otherUserId) ||
                (senderId == otherUserId && recipientId == myId)) {
              // Note: We might need to fetch the profiles if they aren't in payload, 
              // but for live updates we usually just want to know a new msg arrived.
              // To keep it simple, we conversion it to model if possible.
              onNewMessage(DMMessage.fromJson(msgJson));
            }
          },
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
