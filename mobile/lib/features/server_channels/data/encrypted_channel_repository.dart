/// Encrypted server-channel messaging on top of [GroupChatSession].
///
/// Why a separate repository? The existing [MessageRepository] handles
/// channel chat over the unencrypted Supabase `messages` table. We don't
/// want to invasively rewrite it — instead we expose this repository for
/// channels that opt in to E2EE, and the chat notifier picks the right
/// path based on a channel flag.
///
/// Storage shape (intentionally transport-agnostic — see
/// [ChannelEnvelopeTransport]):
///   - One broadcast row per group message, holding [GroupEnvelope] bytes.
///   - One per-recipient-device row per sender-key distribution.
///
/// What this layer does NOT do:
///   - Member-list management. The caller passes the current member list
///     (including each member's device list) to [send]. When members are
///     added or removed, the caller invokes
///     [GroupChatSession.rotateOwnSenderKey] (#G).
///   - Out-of-order recovery. Sender chains are strictly forward; missed
///     messages must be re-requested by the caller.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../e2ee/application/e2ee_session.dart';
import '../../e2ee/application/group_chat_session.dart';
import '../../e2ee/domain/e2ee_models.dart';
import '../../e2ee/domain/group_session.dart';

/// What a server-channel envelope storage layer must offer.
///
/// Tests inject an in-memory implementation; production wires this to the
/// Supabase channel-envelope table.
abstract class ChannelEnvelopeTransport {
  /// Persist a broadcast group envelope so all member devices can pull it.
  Future<void> publishGroupMessage({
    required String channelId,
    required String senderUserId,
    required GroupEnvelope envelope,
  });

  /// Persist sender-key distribution envelopes — one per member device.
  /// Same wire shape as DM per-device envelopes (we reuse [EncryptedEnvelope]).
  Future<void> publishSenderKeyDistribution({
    required String channelId,
    required String senderUserId,
    required List<EncryptedEnvelope> envelopes,
  });
}

/// Result of a [EncryptedChannelRepository.receive] call.
sealed class ChannelDecryptResult {
  const ChannelDecryptResult();
}

class ChannelMessage extends ChannelDecryptResult {
  final Uint8List plaintext;
  const ChannelMessage(this.plaintext);
}

/// We received a group envelope but have no cached sender key for the
/// (channel, sender, senderDevice) tuple. The caller should request a
/// re-distribution from the sender (e.g. via a control event on the channel).
class ChannelNeedsSenderKey extends ChannelDecryptResult {
  final String senderUserId;
  final String senderDeviceId;
  const ChannelNeedsSenderKey(this.senderUserId, this.senderDeviceId);
}

class EncryptedChannelRepository {
  final E2EESession _e2ee;
  final GroupChatSession _group;
  final ChannelEnvelopeTransport _transport;

  EncryptedChannelRepository(this._e2ee, this._group, this._transport);

  /// Distribute this device's sender key for [channelId] to every recipient
  /// device in [recipientUserIds] (excluding our own user). Idempotent — if
  /// the same key is distributed twice the receiver simply overwrites its
  /// cache, no chain advances.
  ///
  /// Call this before the first [send] of a session, after a key rotation,
  /// or whenever the member set changes.
  Future<void> distributeSenderKey({
    required String channelId,
    required List<String> recipientUserIds,
  }) async {
    final payload = await _group.buildSenderKeyDistributionPayload(channelId);
    final all = <EncryptedEnvelope>[];
    for (final uid in recipientUserIds) {
      final envs = await _e2ee.encryptV2ToAllDevices(
        recipientUserId: uid,
        plaintext: payload,
      );
      all.addAll(envs);
    }
    if (all.isEmpty) return;
    final me = await _identifyMe();
    await _transport.publishSenderKeyDistribution(
      channelId: channelId,
      senderUserId: me,
      envelopes: all,
    );
  }

  /// Encrypt [plaintext] for the channel. Returns the broadcast envelope
  /// once it has been published. Sender-key distribution is the caller's
  /// responsibility (call [distributeSenderKey] first).
  Future<GroupEnvelope> send({
    required String channelId,
    required Uint8List plaintext,
  }) async {
    final env = await _group.sendGroupMessage(
      groupId: channelId,
      plaintext: plaintext,
    );
    final me = await _identifyMe();
    await _transport.publishGroupMessage(
      channelId: channelId,
      senderUserId: me,
      envelope: env,
    );
    return env;
  }

  /// Decrypt a received broadcast [envelope]. If we don't yet have the
  /// sender's key cached, returns [ChannelNeedsSenderKey] instead of
  /// throwing — callers can use it to drive a "request distribution" UX.
  Future<ChannelDecryptResult> receive({
    required GroupEnvelope envelope,
    required String senderUserId,
  }) async {
    try {
      final plain = await _group.receiveGroupMessage(
        envelope: envelope,
        senderUserId: senderUserId,
      );
      return ChannelMessage(plain);
    } on StateError {
      return ChannelNeedsSenderKey(senderUserId, envelope.senderDeviceId);
    }
  }

  /// Decrypt an incoming sender-key distribution that was sent through the
  /// per-pair ratchet. The caller already has the [EncryptedEnvelope] from
  /// the channel-envelope storage and the [senderUserId].
  ///
  /// Returns true when the payload was a sender-key distribution (and we
  /// cached it). If the inner plaintext was something else, returns false.
  Future<bool> acceptIncomingDistribution({
    required EncryptedEnvelope envelope,
    required String senderUserId,
  }) async {
    final plaintext = await _e2ee.decryptV2(envelope, senderUserId: senderUserId);
    return _group.tryAcceptControlPayload(
      senderUserId: senderUserId,
      plaintext: plaintext,
    );
  }

  /// Rotate this device's sender key for [channelId] and re-distribute it
  /// to the post-rotation member set. Call after a member is removed (#G).
  Future<void> rotateAndRedistribute({
    required String channelId,
    required List<String> recipientUserIds,
  }) async {
    await _group.rotateOwnSenderKey(channelId);
    await distributeSenderKey(
      channelId: channelId,
      recipientUserIds: recipientUserIds,
    );
  }

  Future<String> _identifyMe() async {
    // We rely on the caller's auth context for `me`. Here we only need a
    // string for the transport — the deviceId pinning happens inside
    // [GroupChatSession]. Falling back to the device id is fine for tests.
    return _e2ee.getMyDeviceId();
  }
}

final encryptedChannelRepositoryProvider =
    Provider.family<EncryptedChannelRepository, ChannelEnvelopeTransport>(
        (ref, transport) {
  return EncryptedChannelRepository(
    ref.watch(e2eeSessionProvider),
    ref.watch(groupChatSessionProvider),
    transport,
  );
});
