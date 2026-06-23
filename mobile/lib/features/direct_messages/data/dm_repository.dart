import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/core/services/appwrite_storage_service.dart';
import 'package:mobile/features/e2ee/application/e2ee_session.dart';
import 'package:mobile/features/e2ee/domain/e2ee_models.dart';
import 'package:mobile/data/models/user_model.dart';

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

  /// Fetches a user profile by ID.
  Future<UserModel> fetchUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  }

  /// Fetches recent DM messages for the user.
  /// Encrypted rows are decrypted in-place; failures fall back to a sentinel.
  Future<List<DMMessage>> fetchRecentMessages(String userId) async {
    try {
      final response = await _client
          .from('direct_messages')
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*), reactions:dm_reactions(emoji, user_id), dm_message_envelopes(*)')
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
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*), reactions:dm_reactions(emoji, user_id), dm_message_envelopes(*)')
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
  ///
  /// For multi-device recipients we encrypt once per recipient device and
  /// store each ciphertext in `dm_message_envelopes`. The DM row itself
  /// carries metadata only when v2 fan-out is used (`is_encrypted=true` +
  /// `protocol_version='v2'` + a sentinel content).
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

    // Try the multi-device fan-out path first; fall back to plaintext if
    // E2EE is disabled or unreachable for this conversation.
    final fanout = await _maybeEncryptToAllDevices(recipientId, finalContent);

    final payload = <String, dynamic>{
      'sender_id': senderId,
      'recipient_id': recipientId,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
    };

    if (fanout != null && fanout.envelopes.isNotEmpty) {
      // v2 fan-out: DM row holds metadata only; ciphertexts live in the child table.
      payload['content'] = '[encrypted]';
      payload['is_encrypted'] = true;
      payload['e2ee_protocol_version'] = 'v2';
    } else {
      payload['content'] = finalContent;
      payload['is_encrypted'] = false;
    }

    try {
      final response = await _client
          .from('direct_messages')
          .insert(payload)
          .select('*, sender:profiles!sender_id(*), recipient:profiles!recipient_id(*), reactions:dm_reactions(emoji, user_id), dm_message_envelopes(*)')
          .single();
      final messageId = response['id'] as String;

      // Persist per-device envelopes after the DM row exists (FK).
      if (fanout != null && fanout.envelopes.isNotEmpty) {
        final rows = fanout.envelopes
            .map((env) => _envelopeToRow(messageId, env))
            .toList();
        await _client.from('dm_message_envelopes').insert(rows);
      }

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

  /// Converts an EncryptedEnvelope into a `dm_message_envelopes` insert row.
  Map<String, dynamic> _envelopeToRow(String messageId, EncryptedEnvelope env) => {
    'message_id': messageId,
    'recipient_device_id': env.recipientDeviceId,
    'sender_device_id': env.senderDeviceId,
    'protocol_version': env.protocolVersion,
    'ciphertext': env.ciphertext,
    if (env.nonce.isNotEmpty) 'nonce': env.nonce,
    if (env.ratchetHeader != null) 'ratchet_header': env.ratchetHeader,
    if (env.senderEphemeralPub.isNotEmpty)
      'sender_ephemeral_pub': env.senderEphemeralPub,
    if (env.senderIdentityPub != null)
      'sender_identity_pub': env.senderIdentityPub,
    'is_initial': env.isInitial,
    if (env.prekeyId != null) 'prekey_id': env.prekeyId,
    if (env.signedPrekeyId != null) 'signed_prekey_id': env.signedPrekeyId,
  };

  /// v2 fan-out: encrypts once per recipient device. Returns null when E2EE
  /// is not enabled, the recipient has no devices, or encryption fails.
  Future<({List<EncryptedEnvelope> envelopes})?> _maybeEncryptToAllDevices(
      String recipientId, String content) async {
    if (_e2ee == null) return null;
    try {
      final enabled = await _e2ee.isConversationEnabled(recipientId);
      if (!enabled) return null;
      final envs = await _e2ee.encryptV2ToAllDevices(
        recipientUserId: recipientId,
        plaintext: content,
      );
      if (envs.isEmpty) return null;
      return (envelopes: envs);
    } catch (_) {
      // Encryption itself failed — fall back to plaintext rather than data loss.
      return null;
    }
  }

  /// Decrypts encrypted rows; passes plaintext rows through unchanged.
  ///
  /// For v2 fan-out rows, the ciphertext lives in `dm_message_envelopes`.
  /// We pick the envelope addressed to *this* device and ignore the rest
  /// (each device only has the keys to open its own envelope).
  Future<DMMessage> _decodeRow(Map<String, dynamic> row) async {
    // Post-process reactions to aggregate by emoji (matching RN / channel logic)
    final List<dynamic> rawReactions = row['reactions'] ?? [];
    final Map<String, Map<String, dynamic>> reactionMap = {};
    final currentUserId = _client.auth.currentUser?.id;

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

    final Map<String, dynamic> updatedRow = Map<String, dynamic>.from(row);
    updatedRow['reactions'] = reactionMap.values.toList();

    final isEncrypted = row['is_encrypted'] == true;
    if (!isEncrypted) {
      return DMMessage.fromJson(updatedRow);
    }

    try {
      if (_e2ee == null) throw Exception('E2EE unavailable');
      final senderId = row['sender_id'] as String?;
      if (senderId == null) {
        throw Exception('encrypted row missing sender_id');
      }

      // Pick the envelope addressed to this device, if the row uses v2 fan-out.
      final perDevice = await _selectEnvelopeForThisDevice(row);
      final env = perDevice ?? EncryptedEnvelope.fromDmRow(row);

      final String plain;
      if (env.protocolVersion == 'v2') {
        plain = await _e2ee.decryptV2(env, senderUserId: senderId);
      } else {
        // ignore: deprecated_member_use
        plain = await _e2ee.decrypt(env);
      }
      return DMMessage.fromJson({...updatedRow, 'content': plain});
    } catch (_) {
      return DMMessage.fromJson({
        ...updatedRow,
        'content': '🔒 [unable to decrypt]',
      });
    }
  }

  /// Returns the envelope addressed to this device for a v2 fan-out row, or
  /// null if the row uses inline (legacy) ciphertext.
  Future<EncryptedEnvelope?> _selectEnvelopeForThisDevice(
      Map<String, dynamic> row) async {
    if (_e2ee == null) return null;
    final embedded = row['dm_message_envelopes'];
    if (embedded is! List || embedded.isEmpty) return null;

    final myDeviceId = await _e2ee.getMyDeviceId();
    Map<String, dynamic>? mine;
    for (final e in embedded) {
      if (e is Map && e['recipient_device_id'] == myDeviceId) {
        mine = e.cast<String, dynamic>();
        break;
      }
    }
    if (mine == null) return null;

    return EncryptedEnvelope(
      protocolVersion: mine['protocol_version'] as String? ?? 'v2',
      ciphertext: mine['ciphertext'] as String? ?? '',
      nonce: mine['nonce'] as String? ?? '',
      senderEphemeralPub: mine['sender_ephemeral_pub'] as String? ?? '',
      senderDeviceId: mine['sender_device_id'] as String? ?? '',
      recipientDeviceId: mine['recipient_device_id'] as String? ?? myDeviceId,
      ratchetHeader: mine['ratchet_header'] as String?,
      isInitial: mine['is_initial'] == true,
      senderIdentityPub: mine['sender_identity_pub'] as String?,
      prekeyId: (mine['prekey_id'] as num?)?.toInt(),
      signedPrekeyId: (mine['signed_prekey_id'] as num?)?.toInt(),
    );
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

  /// Expose _decodeRow publicly for incremental realtime updates
  Future<DMMessage> decodeMessageRow(Map<String, dynamic> row) => _decodeRow(row);

  /// Targeted subscription for a specific conversation
  RealtimeChannel subscribeToConversation(
    String myId,
    String otherUserId,
    void Function(PostgresChangeEvent event, Map<String, dynamic> payload) onUpdate,
  ) {
    developer.log('[SupabaseRealtime] Subscribing to targeted DM conversation between $myId and $otherUserId');
    return _client
        .channel('dm_convo_${myId}_$otherUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: myId,
          ),
          callback: (payload) async {
            developer.log('[SupabaseRealtime] Received DM change (I am recipient): ${payload.eventType}');
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            onUpdate(payload.eventType, Map<String, dynamic>.from(record));
                    },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: myId,
          ),
          callback: (payload) async {
            developer.log('[SupabaseRealtime] Received DM change (I am sender): ${payload.eventType}');
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            onUpdate(payload.eventType, Map<String, dynamic>.from(record));
                    },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dm_reactions',
          callback: (payload) {
            developer.log('[SupabaseRealtime] Received conversation DM reaction change event: ${payload.eventType}');
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            onUpdate(payload.eventType, Map<String, dynamic>.from(record));
                    },
        )
        .subscribe((status, error) {
          developer.log('[SupabaseRealtime] Subscription status for targeted DM convo: $status, error: $error');
        });
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  /// Updates an existing DM message content.
  ///
  /// For E2EE conversations, re-encrypts via per-device fan-out and replaces
  /// the message's envelope rows. Each replacement advances the ratchet —
  /// the old envelope's plaintext is no longer recoverable on either side.
  Future<void> editMessage(String messageId, String otherUserId, String content) async {
    final fanout = await _maybeEncryptToAllDevices(otherUserId, content);
    final updatePayload = <String, dynamic>{
      'edited_at': DateTime.now().toIso8601String(),
    };

    if (fanout != null && fanout.envelopes.isNotEmpty) {
      updatePayload['content'] = '[encrypted]';
      updatePayload['is_encrypted'] = true;
      updatePayload['e2ee_protocol_version'] = 'v2';
    } else {
      updatePayload['content'] = content;
      updatePayload['is_encrypted'] = false;
    }

    await _client.from('direct_messages').update(updatePayload).eq('id', messageId);

    if (fanout != null && fanout.envelopes.isNotEmpty) {
      // Replace existing envelopes for this message with the freshly-encrypted ones.
      await _client
          .from('dm_message_envelopes')
          .delete()
          .eq('message_id', messageId);
      final rows = fanout.envelopes
          .map((env) => _envelopeToRow(messageId, env))
          .toList();
      await _client.from('dm_message_envelopes').insert(rows);
    }
  }

  /// Deletes a direct message.
  Future<void> deleteMessage(String messageId) async {
    await _client.from('direct_messages').delete().eq('id', messageId);
  }

  /// Toggles a reaction on a direct message.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await _client
        .from('dm_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      await _client.from('dm_reactions').delete().eq('id', existing['id']);
    } else {
      await _client.from('dm_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }
}
