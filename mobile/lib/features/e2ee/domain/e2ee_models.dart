/// Domain models for end-to-end encrypted DMs.
///
/// All public/private keys are stored as base64 strings at rest and on the
/// wire — only converted to bytes when they reach the crypto layer.
library;

class IdentityKey {
  /// X25519 public key (32 bytes, base64).
  final String identityPub;

  /// Ed25519 public key for signing prekeys (32 bytes, base64).
  final String signingPub;

  /// SHA-256 of identityPub, hex-encoded. Shown to users for verification.
  final String fingerprint;

  /// Stable identifier for the device that owns this identity.
  final String deviceId;

  const IdentityKey({
    required this.identityPub,
    required this.signingPub,
    required this.fingerprint,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'identity_pub': identityPub,
        'signing_pub': signingPub,
        'fingerprint': fingerprint,
      };

  factory IdentityKey.fromJson(Map<String, dynamic> json) => IdentityKey(
        deviceId: json['device_id'] as String? ?? '',
        identityPub: json['identity_pub'] as String? ?? '',
        signingPub: json['signing_pub'] as String? ?? '',
        fingerprint: json['fingerprint'] as String? ?? '',
      );
}

class SignedPrekey {
  final int keyId;
  final String publicKey; // base64 X25519 pub
  final String signature; // base64 Ed25519 sig

  const SignedPrekey({
    required this.keyId,
    required this.publicKey,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'key_id': keyId,
        'public_key': publicKey,
        'signature': signature,
      };

  factory SignedPrekey.fromJson(Map<String, dynamic> json) => SignedPrekey(
        keyId: (json['key_id'] as num?)?.toInt() ?? 0,
        publicKey: json['public_key'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
      );
}

class OneTimePrekey {
  final int keyId;
  final String publicKey;

  const OneTimePrekey({required this.keyId, required this.publicKey});

  Map<String, dynamic> toJson() => {
        'key_id': keyId,
        'public_key': publicKey,
      };

  factory OneTimePrekey.fromJson(Map<String, dynamic> json) => OneTimePrekey(
        keyId: (json['key_id'] as num?)?.toInt() ?? 0,
        publicKey: json['public_key'] as String? ?? '',
      );
}

/// Bundle returned by GET /e2ee/bundle/{userId}
class PrekeyBundle {
  final String userId;
  final String deviceId;
  final IdentityKey identity;
  final SignedPrekey signedPrekey;
  final OneTimePrekey? oneTimePrekey;

  const PrekeyBundle({
    required this.userId,
    required this.deviceId,
    required this.identity,
    required this.signedPrekey,
    this.oneTimePrekey,
  });

  factory PrekeyBundle.fromJson(Map<String, dynamic> json) => PrekeyBundle(
        userId: json['user_id'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
        identity: IdentityKey.fromJson(
            (json['identity'] as Map?)?.cast<String, dynamic>() ?? {}),
        signedPrekey: SignedPrekey.fromJson(
            (json['signed_prekey'] as Map?)?.cast<String, dynamic>() ?? {}),
        oneTimePrekey: json['one_time_prekey'] == null
            ? null
            : OneTimePrekey.fromJson((json['one_time_prekey'] as Map).cast<String, dynamic>()),
      );
}

/// An encrypted-on-wire DM payload.
class EncryptedEnvelope {
  /// XChaCha20-Poly1305 ciphertext (base64).
  final String ciphertext;

  /// 24-byte XChaCha20 nonce (base64).
  final String nonce;

  /// Sender's ephemeral X25519 public key for ECDH (base64).
  final String senderEphemeralPub;

  /// Sender's stable device id.
  final String senderDeviceId;

  /// Recipient device id this envelope is bound to.
  final String recipientDeviceId;

  /// One-time prekey id consumed (if any).
  final int? prekeyId;

  /// Signed prekey id used.
  final int? signedPrekeyId;

  const EncryptedEnvelope({
    required this.ciphertext,
    required this.nonce,
    required this.senderEphemeralPub,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    this.prekeyId,
    this.signedPrekeyId,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'nonce': nonce,
        'sender_ephemeral_pub': senderEphemeralPub,
        'sender_device_id': senderDeviceId,
        'recipient_device_id': recipientDeviceId,
        if (prekeyId != null) 'prekey_id': prekeyId,
        if (signedPrekeyId != null) 'signed_prekey_id': signedPrekeyId,
      };

  factory EncryptedEnvelope.fromDmRow(Map<String, dynamic> row) => EncryptedEnvelope(
        ciphertext: row['ciphertext'] as String? ?? '',
        nonce: row['nonce'] as String? ?? '',
        senderEphemeralPub: row['sender_ephemeral_pub'] as String? ?? '',
        senderDeviceId: row['sender_device_id'] as String? ?? '',
        recipientDeviceId: row['recipient_device_id'] as String? ?? '',
        prekeyId: (row['prekey_id'] as num?)?.toInt(),
        signedPrekeyId: (row['signed_prekey_id'] as num?)?.toInt(),
      );
}
