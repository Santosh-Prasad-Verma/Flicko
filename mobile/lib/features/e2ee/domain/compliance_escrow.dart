/// Compliance escrow (Tasks 29-31).
///
/// Optional org-tenant key escrow: client encrypts a copy of the session key
/// under the org's escrow public key. Escrow is OFF by default and MUST NEVER
/// be enabled for personal accounts (R11.1, R17.5).
///
/// References: design.md §9, requirements.md R11
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Escrow policy for an organization tenant.
class EscrowPolicy {
  final String orgId;
  final Uint8List escrowPublicKey; // X25519 pub of org KMS
  final List<String> custodianIds; // user IDs approved to release
  final int threshold; // k-of-n approvals required
  final bool enabled;

  const EscrowPolicy({
    required this.orgId,
    required this.escrowPublicKey,
    required this.custodianIds,
    required this.threshold,
    required this.enabled,
  });

  factory EscrowPolicy.fromJson(Map<String, dynamic> j) => EscrowPolicy(
    orgId: j['org_id'] as String,
    escrowPublicKey: Uint8List.fromList(base64Decode(j['public_key'] as String)),
    custodianIds: (j['custodians'] as List).cast<String>(),
    threshold: (j['threshold'] as num).toInt(),
    enabled: j['enabled'] == true,
  );

  Map<String, dynamic> toJson() => {
    'org_id': orgId,
    'public_key': base64Encode(escrowPublicKey),
    'custodians': custodianIds,
    'threshold': threshold,
    'enabled': enabled,
  };
}

/// An escrowed copy of a conversation's root key.
class EscrowedKey {
  final String conversationId;
  final String orgId;
  final Uint8List ephemeralPub; // X25519 pub used for encryption
  final Uint8List ciphertext; // Encrypted root key
  final Uint8List nonce;
  final DateTime createdAt;

  const EscrowedKey({
    required this.conversationId,
    required this.orgId,
    required this.ephemeralPub,
    required this.ciphertext,
    required this.nonce,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'org_id': orgId,
    'ephemeral_pub': base64Encode(ephemeralPub),
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'created_at': createdAt.toIso8601String(),
  };
}

/// Custodian approval record for releasing an escrowed key.
class CustodianApproval {
  final String custodianId;
  final String conversationId;
  final DateTime approvedAt;
  final Uint8List signature; // Ed25519 sig of the release statement

  const CustodianApproval({
    required this.custodianId,
    required this.conversationId,
    required this.approvedAt,
    required this.signature,
  });
}

/// Client-side escrow engine.
class EscrowEngine {
  static final _x25519 = Cryptography.instance.x25519();
  static final _aead = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Encrypt a conversation root key under the org's escrow public key.
  ///
  /// Uses an ephemeral X25519 pair so each escrowed copy has unique keying.
  /// The org KMS holds the escrow private key; Flicko never sees it.
  static Future<EscrowedKey> escrowRootKey({
    required String conversationId,
    required EscrowPolicy policy,
    required Uint8List rootKey,
  }) async {
    if (!policy.enabled) {
      throw StateError('Escrow is disabled for org ${policy.orgId}');
    }

    final eph = await _x25519.newKeyPair();
    final ephPub = await eph.extractPublicKey();
    final dh = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(policy.escrowPublicKey, type: KeyPairType.x25519),
    );
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(await dh.extractBytes()),
      info: utf8.encode('flicko-escrow-v1'),
      nonce: Uint8List(0),
    );
    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(rootKey, secretKey: SecretKey(await derived.extractBytes()), nonce: nonce);
    final ct = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + box.mac.bytes.length, box.mac.bytes);

    return EscrowedKey(
      conversationId: conversationId,
      orgId: policy.orgId,
      ephemeralPub: Uint8List.fromList(ephPub.bytes),
      ciphertext: ct,
      nonce: Uint8List.fromList(nonce),
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Check if enough custodian approvals have been received.
  static bool hasQuorum(EscrowPolicy policy, List<CustodianApproval> approvals) {
    final validIds = approvals.map((a) => a.custodianId).toSet();
    final qualifiedCount = policy.custodianIds.where((id) => validIds.contains(id)).length;
    return qualifiedCount >= policy.threshold;
  }
}
