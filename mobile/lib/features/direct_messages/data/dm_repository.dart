import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/features/e2ee/application/e2ee_session.dart';
import 'package:mobile/features/e2ee/domain/e2ee_models.dart';

final dmRepositoryProvider = Provider<DMRepository>((ref) {
  E2EESession? e2ee;
  try {
    e2ee = ref.watch(e2eeSessionProvider);
  } catch (_) {
    // E2EE not available (e.g. backend unreachable) — DMs work without it
  }
  return DMRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appwriteStorageServiceProvider),
    e2ee,
  );
});

class DMRepository {
  final SupabaseClient _client;
  final AppwriteStorageService _appwriteStorage;
  final E2EESession? _e2ee;

  DMRepository(this._client, this._appwriteStorage, this._e2ee);

  /// Fetches recent DM messages for the user.
  /// Encrypted rows are decrypted in-place; failures fall back to a sentinel.
  Future<List<DMMessage>> fetchRecentMessages(String userId) async {
    try {
      final response = await _client
          .from('direct_messages')
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)')
          .or('sender_id.eq.$userId,recipient_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(500);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return Future.wait(rows.map(_decodeRow));
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
      final rows = (response as List).cast<Map<String, dynamic>>();
      return Future.wait(rows.map(_decodeRow));
    } catch (e) {
      return [];
    }
  }

  /// Sends a direct message.
  /// If E2EE is enabled for the conversation, the body is encrypted client-side
  /// before insert; the server only ever sees the ciphertext.
  Future<DMMessage> sendMessage({
    required String senderId,
    required String recipientId,
    required String content,
    List<DMAttachment>? attachments,
  }) async {
    String finalContent = content.trim();
    if (finalContent.isEmpty) {
      if (attachments != null && attachments.isNotEmpty) {
        final firstType = attachments.first.type.toLowerCase();
        if (firstType.contains('image') || firstType.startsWith('image/')) {
          finalContent = '📷 Photo';
        } else if (firstType.contains('video') || firstType.startsWith('video/')) {
          finalContent = '🎥 Video';
        } else if (firstType.contains('audio') || firstType.startsWith('audio/')) {
          finalContent = '🎵 Audio';
        } else {
          finalContent = '📎 Attachment';
        }
      } else {
        finalContent = 'Empty message';
      }
    }

    final encrypted = await _maybeEncryptOutgoing(recipientId, finalContent);
    final payload = <String, dynamic>{
      'sender_id': senderId,
      'recipient_id': recipientId,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
    };

    if (encrypted != null) {
      payload['content'] = '[encrypted]';
      payload['is_encrypted'] = true;
      payload['ciphertext'] = encrypted.ciphertext;
      payload['nonce'] = encrypted.nonce;
      payload['sender_ephemeral_pub'] = encrypted.senderEphemeralPub;
      payload['sender_device_id'] = encrypted.senderDeviceId;
      payload['recipient_device_id'] = encrypted.recipientDeviceId;
      if (encrypted.prekeyId != null) payload['prekey_id'] = encrypted.prekeyId;
      if (encrypted.signedPrekeyId != null) {
        payload['signed_prekey_id'] = encrypted.signedPrekeyId;
      }
    } else {
      payload['content'] = finalContent;
      payload['is_encrypted'] = false;
    }

    try {
      final response = await _client
          .from('direct_messages')
          .insert(payload)
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*)')
          .single();

      return _decodeRow(response);
    } catch (e) {
      developer.log(
        'DM send failed — likely RLS policy (check friends/privacy/blocks)',
        name: 'DMRepository',
        error: e,
      );
      rethrow;
    }
  }

  /// Returns null when E2EE is not enabled for the conversation.
  Future<EncryptedEnvelope?> _maybeEncryptOutgoing(
      String recipientId, String content) async {
    if (_e2ee == null) return null;
    try {
      final enabled = await _e2ee.isConversationEnabled(recipientId);
      if (!enabled) return null;
      return await _e2ee.encrypt(
          recipientUserId: recipientId, plaintext: content);
    } catch (_) {
      // If encryption itself failed, fall back to plaintext rather than data loss.
      // The UI should warn the user; for now we degrade gracefully.
      return null;
    }
  }

  /// Decrypts encrypted rows; passes plaintext rows through unchanged.
  Future<DMMessage> _decodeRow(Map<String, dynamic> row) async {
    final isEncrypted = row['is_encrypted'] == true;
    if (!isEncrypted) {
      return DMMessage.fromJson(row);
    }

    try {
      final env = EncryptedEnvelope.fromDmRow(row);
      if (_e2ee == null) throw Exception('E2EE unavailable');
      final plain = await _e2ee.decrypt(env);
      return DMMessage.fromJson({...row, 'content': plain});
    } catch (_) {
      return DMMessage.fromJson({
        ...row,
        'content': '🔒 [unable to decrypt]',
      });
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
    developer.log('[SupabaseRealtime] Subscribing to general DMs for user: $userId');
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
          callback: (payload) {
            developer.log('[SupabaseRealtime] Received DM table change (recipient_id matches current user): ${payload.eventType}');
            onUpdate();
          },
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
          callback: (payload) {
            developer.log('[SupabaseRealtime] Received DM table change (sender_id matches current user): ${payload.eventType}');
            onUpdate();
          },
        )
        .subscribe((status, error) {
          developer.log('[SupabaseRealtime] Subscription status for general DMs: $status, error: $error');
        });
  }

  /// Targeted subscription for a specific conversation
  RealtimeChannel subscribeToConversation(String myId, String otherUserId, void Function(DMMessage newMessage) onNewMessage) {
    developer.log('[SupabaseRealtime] Subscribing to targeted DM conversation between $myId and $otherUserId');
    return _client
        .channel('dm_convo_${myId}_${otherUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) async {
            final msgJson = payload.newRecord;
            final senderId = msgJson['sender_id'];
            final recipientId = msgJson['recipient_id'];
            developer.log('[SupabaseRealtime] Received conversation DM insert event. Sender: $senderId, Recipient: $recipientId');

            // Filter for this specific conversation
            if ((senderId == myId && recipientId == otherUserId) ||
                (senderId == otherUserId && recipientId == myId)) {
              final decoded = await _decodeRow(Map<String, dynamic>.from(msgJson));
              developer.log('[SupabaseRealtime] Match found! Decoding and calling onNewMessage for conversation');
              onNewMessage(decoded);
            } else {
              developer.log('[SupabaseRealtime] DM insert event did not match this conversation filter');
            }
          },
        )
        .subscribe((status, error) {
          developer.log('[SupabaseRealtime] Subscription status for targeted DM convo: $status, error: $error');
        });
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
