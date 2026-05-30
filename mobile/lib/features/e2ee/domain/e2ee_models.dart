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
///
/// `protocolVersion` selects the crypto path:
///   - 'v1' (legacy): single-shot 3-DH; uses [senderEphemeralPub] + (signed)prekey ids.
///   - 'v2' (Double Ratchet): per-message ratchet header in [ratchetHeader].
///     Initial X3DH messages additionally carry [isInitial]=true plus
///     [senderIdentityPub], [senderEphemeralPub], and the consumed prekey ids
///     so the recipient can recompute the shared root key.
class EncryptedEnvelope {
  /// Protocol version: 'v1' (legacy 3-DH) or 'v2' (X3DH + Double Ratchet).
  final String protocolVersion;

  /// XChaCha20-Poly1305 ciphertext (base64). For v2 this includes the
  /// 24-byte nonce prepended and 16-byte AEAD tag appended.
  final String ciphertext;

  /// 24-byte XChaCha20 nonce (base64). v1 only — v2 packs it into [ciphertext].
  final String nonce;

  /// Sender's ephemeral X25519 public key for ECDH (base64).
  /// v1: per-message ephemeral. v2: only set on initial X3DH message.
  final String senderEphemeralPub;

  /// Sender's stable device id.
  final String senderDeviceId;

  /// Recipient device id this envelope is bound to.
  final String recipientDeviceId;

  /// One-time prekey id consumed (if any).
  final int? prekeyId;

  /// Signed prekey id used.
  final int? signedPrekeyId;

  // ── v2 fields ────────────────────────────────────────────────────────────

  /// Double Ratchet header (40 bytes: dhPub || pn || n), base64. v2 only.
  final String? ratchetHeader;

  /// True when this envelope is the first message of a v2 session — recipient
  /// must run X3DH using [senderIdentityPub] + [senderEphemeralPub].
  final bool isInitial;

  /// Sender's identity X25519 public key (base64). v2 initial only.
  final String? senderIdentityPub;

  const EncryptedEnvelope({
    required this.ciphertext,
    required this.nonce,
    required this.senderEphemeralPub,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    this.prekeyId,
    this.signedPrekeyId,
    this.protocolVersion = 'v1',
    this.ratchetHeader,
    this.isInitial = false,
    this.senderIdentityPub,
  });

  Map<String, dynamic> toJson() => {
        'protocol_version': protocolVersion,
        'ciphertext': ciphertext,
        'nonce': nonce,
        'sender_ephemeral_pub': senderEphemeralPub,
        'sender_device_id': senderDeviceId,
        'recipient_device_id': recipientDeviceId,
        if (prekeyId != null) 'prekey_id': prekeyId,
        if (signedPrekeyId != null) 'signed_prekey_id': signedPrekeyId,
        if (ratchetHeader != null) 'ratchet_header': ratchetHeader,
        if (isInitial) 'is_initial': true,
        if (senderIdentityPub != null) 'sender_identity_pub': senderIdentityPub,
      };

  factory EncryptedEnvelope.fromDmRow(Map<String, dynamic> row) => EncryptedEnvelope(
        protocolVersion: row['protocol_version'] as String? ?? 'v1',
        ciphertext: row['ciphertext'] as String? ?? '',
        nonce: row['nonce'] as String? ?? '',
        senderEphemeralPub: row['sender_ephemeral_pub'] as String? ?? '',
        senderDeviceId: row['sender_device_id'] as String? ?? '',
        recipientDeviceId: row['recipient_device_id'] as String? ?? '',
        prekeyId: (row['prekey_id'] as num?)?.toInt(),
        signedPrekeyId: (row['signed_prekey_id'] as num?)?.toInt(),
        ratchetHeader: row['ratchet_header'] as String?,
        isInitial: row['is_initial'] == true,
        senderIdentityPub: row['sender_identity_pub'] as String?,
      );
}

/// Wire shape returned by `GET /e2ee/identity/attestation/{userId}`.
///
/// All fields are base64. The client verifies [signature] over the
/// canonical attestation message
///
///     "rotate:<oldIdentityPub>:<newIdentityPub>"
///
/// against the OLD signing public key that the peer already trusts.
class RemoteIdentityAttestation {
  final String userId;
  final String oldIdentityPub;
  final String newIdentityPub;
  final String signature;
  final DateTime attestedAt;

  const RemoteIdentityAttestation({
    required this.userId,
    required this.oldIdentityPub,
    required this.newIdentityPub,
    required this.signature,
    required this.attestedAt,
  });

  factory RemoteIdentityAttestation.fromJson(Map<String, dynamic> json) =>
      RemoteIdentityAttestation(
        userId: json['user_id'] as String? ?? '',
        oldIdentityPub: json['old_identity_pub'] as String? ?? '',
        newIdentityPub: json['new_identity_pub'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
        attestedAt: DateTime.parse(
            json['attested_at'] as String? ?? '1970-01-01T00:00:00Z'),
      );
}
