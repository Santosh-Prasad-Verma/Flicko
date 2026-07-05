/// Multi-device session management (Tasks 20-24).
///
/// Handles per-device DR sessions, sender keys for group delivery,
/// self-pairing (new device onboarding), and device list management.
/// References: design.md §5, requirements.md R7
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Per-device session metadata tracked by the multi-device coordinator.
class DeviceSession {
  final String deviceId;
  final String identityPub; // base64
  final String signingPub;  // base64
  final DateTime registeredAt;
  final DateTime lastSeenAt;
  final bool isCurrentDevice;
  final String? deviceName;

  const DeviceSession({
    required this.deviceId,
    required this.identityPub,
    required this.signingPub,
    required this.registeredAt,
    required this.lastSeenAt,
    this.isCurrentDevice = false,
    this.deviceName,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> j) => DeviceSession(
    deviceId: j['device_id'] as String,
    identityPub: j['identity_pub'] as String,
    signingPub: j['signing_pub'] as String,
    registeredAt: DateTime.parse(j['registered_at'] as String),
    lastSeenAt: DateTime.parse(j['last_seen_at'] as String),
    isCurrentDevice: j['is_current'] == true,
    deviceName: j['device_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'identity_pub': identityPub,
    'signing_pub': signingPub,
    'registered_at': registeredAt.toIso8601String(),
    'last_seen_at': lastSeenAt.toIso8601String(),
    'is_current': isCurrentDevice,
    'device_name': deviceName,
  };
}

/// Sender Key for efficient one-to-many delivery (R7.2).
/// Instead of encrypting per-device, the sender distributes a sender key
/// and all devices decrypt the same ciphertext.
class SenderKey {
  final String groupId;
  final String senderDeviceId;
  final int chainId;
  final Uint8List chainKey; // 32 bytes
  final Uint8List signingPub; // Ed25519 pub for message authentication

  const SenderKey({
    required this.groupId,
    required this.senderDeviceId,
    required this.chainId,
    required this.chainKey,
    required this.signingPub,
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'sender_device_id': senderDeviceId,
    'chain_id': chainId,
    'chain_key': base64Encode(chainKey),
    'signing_pub': base64Encode(signingPub),
  };

  factory SenderKey.fromJson(Map<String, dynamic> j) => SenderKey(
    groupId: j['group_id'] as String,
    senderDeviceId: j['sender_device_id'] as String,
    chainId: (j['chain_id'] as num).toInt(),
    chainKey: Uint8List.fromList(base64Decode(j['chain_key'] as String)),
    signingPub: Uint8List.fromList(base64Decode(j['signing_pub'] as String)),
  );

  /// Serialize for distribution to peers (carried inside an [E2EESession]
  /// per-pair ciphertext). Receivers reconstruct via [SenderKey.fromJson].
  Uint8List toDistributionBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static SenderKey fromDistributionBytes(Uint8List bytes) =>
      SenderKey.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}

/// Self-pairing request for new device onboarding (R7.4, R7.5).
class SelfPairingRequest {
  final String requestId;
  final String newDeviceId;
  final Uint8List newDeviceIdentityPub; // X25519 pub
  final String sasPhrase; // 6-word SAS for out-of-band confirmation
  final String status; // pending | approved | rejected | expired
  final DateTime createdAt;
  final DateTime expiresAt;

  const SelfPairingRequest({
    required this.requestId,
    required this.newDeviceId,
    required this.newDeviceIdentityPub,
    required this.sasPhrase,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool get isPending => status == 'pending' && !isExpired;

  factory SelfPairingRequest.fromJson(Map<String, dynamic> j) => SelfPairingRequest(
    requestId: j['id'] as String,
    newDeviceId: j['new_device_id'] as String,
    newDeviceIdentityPub: Uint8List.fromList(base64Decode(j['new_device_identity'] as String)),
    sasPhrase: j['sas_fingerprint'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    createdAt: DateTime.parse(j['created_at'] as String),
    expiresAt: DateTime.parse(j['expires_at'] as String),
  );
}

/// Multi-device session coordinator.
///
/// Manages per-device sessions, sender key distribution,
/// and self-pairing flows.
class MultiDeviceManager {
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Generate a new sender key for group/multi-device delivery.
  static Future<SenderKey> generateSenderKey({
    required String groupId,
    required String deviceId,
    required SimpleKeyPair signingKeyPair,
  }) async {
    final chainKey = SecretKeyData.random(length: 32);
    final sigPub = await signingKeyPair.extractPublicKey();
    return SenderKey(
      groupId: groupId,
      senderDeviceId: deviceId,
      chainId: 0,
      chainKey: Uint8List.fromList(await chainKey.extractBytes()),
      signingPub: Uint8List.fromList(sigPub.bytes),
    );
  }

  /// Derive the next message key from a sender key chain.
  static Future<({SenderKey advanced, Uint8List messageKey})> advanceSenderKey(SenderKey sk) async {
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(sk.chainKey),
      info: utf8.encode('flicko-sender-key-v2'),
      nonce: Uint8List(0),
    );
    final newChain = Uint8List.fromList(await derived.extractBytes());
    final mkDerived = await _hkdf.deriveKey(
      secretKey: SecretKey(sk.chainKey),
      info: utf8.encode('flicko-sender-key-msg-v2'),
      nonce: Uint8List(0),
    );
    final mk = Uint8List.fromList(await mkDerived.extractBytes());
    return (
      advanced: SenderKey(
        groupId: sk.groupId,
        senderDeviceId: sk.senderDeviceId,
        chainId: sk.chainId + 1,
        chainKey: newChain,
        signingPub: sk.signingPub,
      ),
      messageKey: mk,
    );
  }

  /// Create a self-pairing request for a new device (R7.4).
  static Future<SelfPairingRequest> createPairingRequest({
    required String newDeviceId,
    required Uint8List newDeviceIdentityPub,
    required Uint8List existingDevicePub,
  }) async {
    // Generate SAS phrase from both device keys.
    final combined = Uint8List(newDeviceIdentityPub.length + existingDevicePub.length)
      ..setRange(0, newDeviceIdentityPub.length, newDeviceIdentityPub)
      ..setRange(newDeviceIdentityPub.length, newDeviceIdentityPub.length + existingDevicePub.length, existingDevicePub);
    final hash = await Sha256().hash(combined);
    const words = ['anchor','beacon','castle','delta','ember','falcon'];
    final sas = List.generate(6, (i) => words[hash.bytes[i] % words.length]).join(' ');

    final now = DateTime.now().toUtc();
    return SelfPairingRequest(
      requestId: base64Encode(hash.bytes.sublist(0, 16)),
      newDeviceId: newDeviceId,
      newDeviceIdentityPub: newDeviceIdentityPub,
      sasPhrase: sas,
      status: 'pending',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
  }
}
