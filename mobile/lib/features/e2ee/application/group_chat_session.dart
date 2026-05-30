/// High-level group-messaging session: owns this device's sender key per
/// group, persists peer sender keys, and bridges sender-key distribution
/// through the existing per-pair Double Ratchet session.
///
/// Sending a group message is one [GroupSession.encrypt] call against our
/// own chain, which produces a single envelope that every member opens
/// locally. Receiving requires a cached `SenderKey` for the (groupId,
/// senderDeviceId) pair — that's what [acceptSenderKeyDistribution] does.
///
/// Distribution wraps the serialized [SenderKey] in a normal v2 envelope
/// addressed to each member device, framed as
/// `{"kind":"group-sender-key","payload": <senderkey JSON>}`. The
/// recipient's [decryptV2] returns those bytes; the caller passes them to
/// [acceptSenderKeyDistribution].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_keystore.dart';
import '../domain/group_session.dart';
import '../domain/multi_device.dart';
import 'e2ee_session.dart';

/// Wire-frame for group sender-key distribution.
///
/// We tag distribution payloads so a receiver can tell them apart from
/// regular plaintext DMs. Future kinds (e.g. "group-rotate") share the
/// same envelope.
class GroupControlMessage {
  final String kind; // 'group-sender-key' | future kinds
  final Map<String, dynamic> payload;

  const GroupControlMessage({required this.kind, required this.payload});

  String encode() => jsonEncode({'kind': kind, 'payload': payload});

  static GroupControlMessage? tryDecode(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final kind = j['kind'];
      final payload = j['payload'];
      if (kind is! String || payload is! Map) return null;
      return GroupControlMessage(
        kind: kind,
        payload: payload.cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}

class GroupChatSession {
  static const String kindSenderKey = 'group-sender-key';

  final E2EESession _e2ee;
  final SecureKeystore _local;

  GroupChatSession(this._e2ee, this._local);

  // ── Own sender key (per group) ───────────────────────────────────────────

  /// Returns this device's sender key for [groupId], creating one on first
  /// use. The signing key pair is the device's existing E2EE signing key,
  /// so receivers verify group envelopes against the same Ed25519 pub they
  /// already trust for prekey signatures.
  Future<SenderKey> _ensureOwnSenderKey(String groupId) async {
    final cached = await _local.readOwnSenderKey(groupId);
    if (cached != null && cached.isNotEmpty) {
      return SenderKey.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    final signing = await _local.loadSigningKeyPair();
    if (signing == null) {
      throw StateError('group: signing key missing — call ensureBootstrapped');
    }
    final deviceId = await _e2ee.getMyDeviceId();
    final fresh = await MultiDeviceManager.generateSenderKey(
      groupId: groupId,
      deviceId: deviceId,
      signingKeyPair: signing,
    );
    await _local.writeOwnSenderKey(groupId, jsonEncode(fresh.toJson()));
    return fresh;
  }

  Future<void> _saveOwnSenderKey(SenderKey sk) async {
    await _local.writeOwnSenderKey(sk.groupId, jsonEncode(sk.toJson()));
  }

  /// Discard this device's cached sender key for [groupId] and generate a
  /// fresh chain on the next send. Used when a member is removed from the
  /// group: every remaining member rotates so the removed member's cached
  /// peer key cannot decrypt new messages.
  ///
  /// Pair this with [buildSenderKeyDistributionPayload] (or the
  /// channel-repo helper) to re-distribute the new key to the post-removal
  /// member set in the same flow.
  Future<void> rotateOwnSenderKey(String groupId) async {
    final signing = await _local.loadSigningKeyPair();
    if (signing == null) {
      throw StateError('group: signing key missing — call ensureBootstrapped');
    }
    final deviceId = await _e2ee.getMyDeviceId();
    final fresh = await MultiDeviceManager.generateSenderKey(
      groupId: groupId,
      deviceId: deviceId,
      signingKeyPair: signing,
    );
    await _saveOwnSenderKey(fresh);
  }

  // ── Distribution ─────────────────────────────────────────────────────────

  /// Wrap this device's current sender key for [groupId] as a control
  /// message and return the plaintext that should be sent to each member
  /// via [E2EESession.encryptV2ToAllDevices].
  ///
  /// We do NOT call encryptV2 here — the caller is the chat repo, which
  /// already knows how to address per-device envelopes and persist them.
  Future<String> buildSenderKeyDistributionPayload(String groupId) async {
    final sk = await _ensureOwnSenderKey(groupId);
    return GroupControlMessage(
      kind: kindSenderKey,
      payload: sk.toJson(),
    ).encode();
  }

  /// Handle an incoming control plaintext that came out of the v2 ratchet
  /// (i.e. the result of `E2EESession.decryptV2`). Returns true when this
  /// payload was a sender-key distribution and was stored.
  Future<bool> tryAcceptControlPayload({
    required String senderUserId,
    required String plaintext,
  }) async {
    final ctrl = GroupControlMessage.tryDecode(plaintext);
    if (ctrl == null) return false;
    if (ctrl.kind != kindSenderKey) return false;
    final sk = SenderKey.fromJson(ctrl.payload);
    await _local.writePeerSenderKey(
      sk.groupId,
      senderUserId,
      sk.senderDeviceId,
      jsonEncode(sk.toJson()),
    );
    return true;
  }

  // ── Send / Receive group messages ────────────────────────────────────────

  /// Encrypt [plaintext] for the group. Returns the broadcast envelope —
  /// the chat repo persists ONE row containing this and every member's
  /// device decrypts the same bytes.
  Future<GroupEnvelope> sendGroupMessage({
    required String groupId,
    required Uint8List plaintext,
  }) async {
    final signing = await _local.loadSigningKeyPair();
    if (signing == null) {
      throw StateError('group: signing key missing');
    }
    var sk = await _ensureOwnSenderKey(groupId);
    final r = await GroupSession.encrypt(
      senderKey: sk,
      signingKeyPair: signing,
      plaintext: plaintext,
    );
    sk = r.advanced;
    await _saveOwnSenderKey(sk);
    return r.envelope;
  }

  /// Decrypt a group envelope sent by [senderUserId]. Looks up the cached
  /// peer sender key for `(groupId, senderUserId, senderDeviceId)`; if
  /// none exists, throws so the caller can request a re-send.
  Future<Uint8List> receiveGroupMessage({
    required GroupEnvelope envelope,
    required String senderUserId,
  }) async {
    final raw = await _local.readPeerSenderKey(
      envelope.groupId,
      senderUserId,
      envelope.senderDeviceId,
    );
    if (raw == null) {
      throw StateError(
        'group: no sender key cached for ${envelope.senderDeviceId} '
        '— request distribution from $senderUserId',
      );
    }
    final peerSk = SenderKey.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final r = await GroupSession.decrypt(envelope: envelope, peerSenderKey: peerSk);
    await _local.writePeerSenderKey(
      envelope.groupId,
      senderUserId,
      envelope.senderDeviceId,
      jsonEncode(r.advanced.toJson()),
    );
    return r.plaintext;
  }
}

final groupChatSessionProvider = Provider<GroupChatSession>((ref) {
  return GroupChatSession(
    ref.watch(e2eeSessionProvider),
    ref.watch(secureKeystoreProvider),
  );
});
