/// Group messaging via Sender Keys (R7.2, R7.3).
///
/// Each group member maintains its own sender-key chain for the group; the
/// chain key is distributed once (out-of-band, via the per-device pair
/// sessions in [E2EESession]) and then every group message advances the
/// chain on both the sender's and receivers' sides.
///
/// Wire format ([GroupEnvelope]):
///   - groupId, senderDeviceId — addressing
///   - chainId — the message's index in the sender's chain
///   - ciphertext — XChaCha20-Poly1305(nonce || encrypted || tag)
///   - signature — Ed25519 signature over (chainId || ciphertext) using the
///     sender's signing key. Receivers verify with [SenderKey.signingPub]
///     before advancing their copy of the chain, so a tampered or replayed
///     envelope is rejected without ever derived a message key.
///
/// What this module does NOT handle (yet):
///   - Out-of-order delivery within a sender's chain. The sender-key chain
///     is strictly forward — a missed message must be re-requested, not
///     skipped. (Signal does the same.)
///   - Sender key rotation on member removal. When someone leaves the
///     group, every remaining member should rotate. Tracked separately.
///   - Distribution itself. The transport (encrypting a fresh sender key
///     per device-pair via [E2EESession.encryptV2]) lives elsewhere.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'multi_device.dart';
import 'protocol_info.dart';

/// One ciphertext addressed to a group, signed by its sender.
class GroupEnvelope {
  final String groupId;
  final String senderDeviceId;
  final int chainId;
  final Uint8List ciphertext; // nonce(24) || encrypted || mac(16)
  final Uint8List signature; // Ed25519 sig over (chainId || ciphertext)

  const GroupEnvelope({
    required this.groupId,
    required this.senderDeviceId,
    required this.chainId,
    required this.ciphertext,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'sender_device_id': senderDeviceId,
        'chain_id': chainId,
        'ciphertext': base64Encode(ciphertext),
        'signature': base64Encode(signature),
      };

  factory GroupEnvelope.fromJson(Map<String, dynamic> j) => GroupEnvelope(
        groupId: j['group_id'] as String,
        senderDeviceId: j['sender_device_id'] as String,
        chainId: (j['chain_id'] as num).toInt(),
        ciphertext: Uint8List.fromList(base64Decode(j['ciphertext'] as String)),
        signature: Uint8List.fromList(base64Decode(j['signature'] as String)),
      );
}

/// Raised when an envelope's signature does not verify against the cached
/// sender key's signing pub.
class GroupSignatureError extends Error {
  final String reason;
  GroupSignatureError(this.reason);
  @override
  String toString() => 'GroupSignatureError($reason)';
}

/// Raised when an envelope's chain index is older than what the receiver
/// has already processed. Bounded protection against replay.
class GroupChainOrderError extends Error {
  final int expected;
  final int got;
  GroupChainOrderError(this.expected, this.got);
  @override
  String toString() =>
      'GroupChainOrderError(expected>=$expected, got=$got)';
}

/// Stateless engine: callers thread sender-key state through encrypt/decrypt.
class GroupSession {
  static final _aead = Xchacha20.poly1305Aead();
  static final _ed25519 = Cryptography.instance.ed25519();

  /// Encrypt [plaintext] for the group whose sender chain is [senderKey].
  /// Returns the wire envelope and the advanced sender key for persistence.
  static Future<({GroupEnvelope envelope, SenderKey advanced})> encrypt({
    required SenderKey senderKey,
    required SimpleKeyPair signingKeyPair,
    required Uint8List plaintext,
  }) async {
    final advanced = await MultiDeviceManager.advanceSenderKey(senderKey);
    final mk = advanced.messageKey;

    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(mk),
      nonce: nonce,
    );

    final ct = Uint8List(24 + box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, 24, nonce)
      ..setRange(24, 24 + box.cipherText.length, box.cipherText)
      ..setRange(24 + box.cipherText.length,
          24 + box.cipherText.length + box.mac.bytes.length, box.mac.bytes);

    // Sign (chainId || ciphertext) so receivers can reject tampered envelopes
    // BEFORE deriving a message key. Domain-separate via the protocol info
    // string to prevent cross-protocol signature reuse.
    final toSign = _signedBytes(
      groupId: senderKey.groupId,
      senderDeviceId: senderKey.senderDeviceId,
      chainId: advanced.advanced.chainId,
      ciphertext: ct,
    );
    final sig = await _ed25519.sign(toSign, keyPair: signingKeyPair);

    return (
      envelope: GroupEnvelope(
        groupId: senderKey.groupId,
        senderDeviceId: senderKey.senderDeviceId,
        chainId: advanced.advanced.chainId,
        ciphertext: ct,
        signature: Uint8List.fromList(sig.bytes),
      ),
      advanced: advanced.advanced,
    );
  }

  /// Decrypt [envelope] using the cached [peerSenderKey] for the same
  /// (groupId, senderDeviceId).
  ///
  /// Returns the plaintext and the advanced peer sender key for persistence.
  /// The chain MUST be in-order: replays and rewinds are rejected.
  static Future<({Uint8List plaintext, SenderKey advanced})> decrypt({
    required GroupEnvelope envelope,
    required SenderKey peerSenderKey,
  }) async {
    if (envelope.groupId != peerSenderKey.groupId ||
        envelope.senderDeviceId != peerSenderKey.senderDeviceId) {
      throw StateError('group: envelope/sender-key mismatch');
    }
    // Strictly monotonic: the envelope's chainId must be exactly one ahead
    // of what we last processed (peerSenderKey.chainId).
    final expected = peerSenderKey.chainId + 1;
    if (envelope.chainId != expected) {
      throw GroupChainOrderError(expected, envelope.chainId);
    }

    // Verify the signature against the cached signing pub BEFORE we touch
    // chain-key material. A bad signature must not advance the chain.
    final toVerify = _signedBytes(
      groupId: envelope.groupId,
      senderDeviceId: envelope.senderDeviceId,
      chainId: envelope.chainId,
      ciphertext: envelope.ciphertext,
    );
    final sig = Signature(
      envelope.signature,
      publicKey:
          SimplePublicKey(peerSenderKey.signingPub, type: KeyPairType.ed25519),
    );
    final ok = await _ed25519.verify(toVerify, signature: sig);
    if (!ok) {
      throw GroupSignatureError('signature did not verify');
    }

    // Advance and decrypt.
    final advanced = await MultiDeviceManager.advanceSenderKey(peerSenderKey);
    final mk = advanced.messageKey;

    final ct = envelope.ciphertext;
    if (ct.length < 40) {
      throw StateError('group: ciphertext too short');
    }
    final nonce = ct.sublist(0, 24);
    final macStart = ct.length - 16;
    final encrypted = ct.sublist(24, macStart);
    final mac = ct.sublist(macStart);

    final box = SecretBox(encrypted, nonce: nonce, mac: Mac(mac));
    final plain = await _aead.decrypt(box, secretKey: SecretKey(mk));

    return (
      plaintext: Uint8List.fromList(plain),
      advanced: advanced.advanced,
    );
  }

  /// Bytes covered by the per-envelope Ed25519 signature.
  static Uint8List _signedBytes({
    required String groupId,
    required String senderDeviceId,
    required int chainId,
    required Uint8List ciphertext,
  }) {
    final domain = utf8.encode(ProtocolInfo.senderKey);
    final gid = utf8.encode(groupId);
    final did = utf8.encode(senderDeviceId);

    final buf = BytesBuilder();
    buf.add(domain);
    buf.addByte(0x00);
    buf.add(gid);
    buf.addByte(0x00);
    buf.add(did);
    buf.addByte(0x00);
    final cidBuf = ByteData(4)..setUint32(0, chainId, Endian.big);
    buf.add(cidBuf.buffer.asUint8List());
    buf.add(ciphertext);
    return buf.toBytes();
  }
}
