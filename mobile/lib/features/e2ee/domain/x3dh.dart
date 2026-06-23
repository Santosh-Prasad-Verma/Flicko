/// X3DH asynchronous key agreement — full implementation.
///
/// Implements the Signal X3DH protocol:
///   - 4-DH (with OTK) or 3-DH fallback
///   - SPK signature verification before any ECDH (R4.4)
///   - HKDF-SHA-256 with domain-separated info string
///   - Binds initial Double Ratchet session from X3DH output
///
/// References:
///   design.md §3 (X3DH Session Establishment)
///   requirements.md R4
///   Signal X3DH specification (2016)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'e2ee_models.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// HKDF info string used to combine the DH outputs into a root key.
const String kX3dhInfo = 'flicko-x3dh-v2';

// ── Result Types ─────────────────────────────────────────────────────────────

/// Output of a successful X3DH initiation/acceptance.
class X3DHResult {
  /// 32-byte shared root key for the Double Ratchet's RK.
  final Uint8List rootKey;

  /// Sender's ephemeral public key (32 B X25519). Included in the first
  /// envelope so the recipient can recompute the same root key.
  final Uint8List ephemeralPub;

  /// One-time prekey id consumed (or null if 3-DH fallback was used).
  final int? oneTimePrekeyId;

  /// Recipient's signed prekey id used.
  final int signedPrekeyId;

  const X3DHResult({
    required this.rootKey,
    required this.ephemeralPub,
    required this.oneTimePrekeyId,
    required this.signedPrekeyId,
  });
}

// ── Errors ───────────────────────────────────────────────────────────────────

/// Raised when a fetched bundle's signed-prekey signature does not verify
/// against the recipient's signing public key (R4.4).
class X3DHSignatureError extends Error {
  final String detail;
  X3DHSignatureError(this.detail);
  @override
  String toString() => 'X3DHSignatureError($detail)';
}

// ── X3DH Engine ──────────────────────────────────────────────────────────────

/// Production X3DH implementation.
///
/// Sender path (initiator): verifies bundle, runs 3/4-DH, derives root key.
/// Recipient path (responder): mirrors the DH, derives same root key.
class X3DHEngine {
  static final _x25519 = Cryptography.instance.x25519();
  static final _ed25519 = Cryptography.instance.ed25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ── Sender (Initiator) ─────────────────────────────────────────────────────

  /// Verifies [bundle], runs 3-DH or 4-DH, and returns the root key plus
  /// the public material the recipient needs to derive the same key.
  ///
  /// Steps (from design.md §3.2):
  ///   1. Verify SPK signature with recipient's SK_pub (R4.3, R4.4)
  ///   2. Generate ephemeral key pair EK
  ///   3. Compute DH1..DH4 (or DH1..DH3 if no OTK)
  ///   4. SK = HKDF(DH1||DH2||DH3||DH4, info="flicko-x3dh-v2")
  ///   5. Return root key + public material
  static Future<X3DHResult> initiatorStart({
    required PrekeyBundle bundle,
    required SimpleKeyPair myIdentityKeyPair,
  }) async {
    // ── Step 1: Verify SPK signature (R4.3, R4.4) ──
    final signingPubBytes = base64Decode(bundle.identity.signingPub);
    final spkPubBytes = base64Decode(bundle.signedPrekey.publicKey);
    final signatureBytes = base64Decode(bundle.signedPrekey.signature);

    final signature = Signature(
      signatureBytes,
      publicKey:
          SimplePublicKey(signingPubBytes, type: KeyPairType.ed25519),
    );
    final valid = await _ed25519.verify(spkPubBytes, signature: signature);
    if (!valid) {
      throw X3DHSignatureError(
          'Signed prekey signature invalid for user ${bundle.userId}');
    }

    // ── Step 2: Generate ephemeral key pair ──
    final ephemeral = await _x25519.newKeyPair();
    final ephPub = await ephemeral.extractPublicKey();

    // ── Step 3: Compute DH outputs ──
    final identityPubBytes = base64Decode(bundle.identity.identityPub);

    // DH1 = DH(IK_A_priv, SPK_B)
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: myIdentityKeyPair,
      remotePublicKey:
          SimplePublicKey(spkPubBytes, type: KeyPairType.x25519),
    );

    // DH2 = DH(EK_A_priv, IK_B)
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey:
          SimplePublicKey(identityPubBytes, type: KeyPairType.x25519),
    );

    // DH3 = DH(EK_A_priv, SPK_B)
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey:
          SimplePublicKey(spkPubBytes, type: KeyPairType.x25519),
    );

    // Concatenate DH outputs.
    final concat = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    // DH4 = DH(EK_A_priv, OTK_B) — only if OTK is present (R4.5, R4.6).
    int? consumedOtkId;
    if (bundle.oneTimePrekey != null) {
      final otkPubBytes = base64Decode(bundle.oneTimePrekey!.publicKey);
      final dh4 = await _x25519.sharedSecretKey(
        keyPair: ephemeral,
        remotePublicKey:
            SimplePublicKey(otkPubBytes, type: KeyPairType.x25519),
      );
      concat.addAll(await dh4.extractBytes());
      consumedOtkId = bundle.oneTimePrekey!.keyId;
    }

    // ── Step 4: Derive root key via HKDF ──
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(concat),
      info: utf8.encode(kX3dhInfo),
      nonce: Uint8List(0), // empty salt
    );
    final rootKey = Uint8List.fromList(await derived.extractBytes());

    return X3DHResult(
      rootKey: rootKey,
      ephemeralPub: Uint8List.fromList(ephPub.bytes),
      oneTimePrekeyId: consumedOtkId,
      signedPrekeyId: bundle.signedPrekey.keyId,
    );
  }

  // ── Recipient (Responder) ──────────────────────────────────────────────────

  /// Recomputes the root key from the first envelope's published material.
  ///
  /// Caller is responsible for consuming and deleting the matching OTK
  /// private locally (atomic OTK deletion happens server-side).
  ///
  /// Steps (mirror of initiator):
  ///   DH1 = DH(SPK_B_priv, IK_A_pub)
  ///   DH2 = DH(IK_B_priv, EK_A_pub)
  ///   DH3 = DH(SPK_B_priv, EK_A_pub)
  ///   DH4 = DH(OTK_B_priv, EK_A_pub) — optional
  static Future<X3DHResult> responderAccept({
    required Uint8List senderEphemeralPub,
    required Uint8List senderIdentityPub,
    required SimpleKeyPair myIdentityKeyPair,
    required SimpleKeyPair mySignedPrekeyKeyPair,
    required int signedPrekeyId,
    SimpleKeyPair? myOneTimePrekeyKeyPair,
    int? oneTimePrekeyId,
  }) async {
    // DH1 = DH(SPK_B_priv, IK_A_pub)
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: mySignedPrekeyKeyPair,
      remotePublicKey:
          SimplePublicKey(senderIdentityPub, type: KeyPairType.x25519),
    );

    // DH2 = DH(IK_B_priv, EK_A_pub)
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: myIdentityKeyPair,
      remotePublicKey:
          SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
    );

    // DH3 = DH(SPK_B_priv, EK_A_pub)
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: mySignedPrekeyKeyPair,
      remotePublicKey:
          SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
    );

    final concat = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    // DH4 if OTK was consumed.
    if (myOneTimePrekeyKeyPair != null) {
      final dh4 = await _x25519.sharedSecretKey(
        keyPair: myOneTimePrekeyKeyPair,
        remotePublicKey:
            SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
      );
      concat.addAll(await dh4.extractBytes());
    }

    // Derive root key via HKDF (same as initiator — R4.5).
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(concat),
      info: utf8.encode(kX3dhInfo),
      nonce: Uint8List(0),
    );
    final rootKey = Uint8List.fromList(await derived.extractBytes());

    return X3DHResult(
      rootKey: rootKey,
      ephemeralPub: senderEphemeralPub,
      oneTimePrekeyId: oneTimePrekeyId,
      signedPrekeyId: signedPrekeyId,
    );
  }
}
