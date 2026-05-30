import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper over the `cryptography` package with the exact primitives
/// Flicko's E2EE protocol uses:
///
///  - X25519                  for Diffie–Hellman key agreement
///  - Ed25519                 for prekey signing
///  - HKDF-SHA-256            for key derivation from shared secrets
///  - XChaCha20-Poly1305      for symmetric authenticated encryption
///
/// **Status: PARTIAL — keypair generation, signing, fingerprints are production-grade.**
///
/// **DEPRECATED for message encryption.** [encrypt]/[decrypt] perform a single
/// stateless 3-DH agreement per message — there is no Double Ratchet, so:
///   - No per-message forward secrecy on the receiver side
///   - No post-compromise security
///   - Recipient's signed prekey + identity key are reused across messages
///
/// New code MUST route message-payload crypto through [DoubleRatchet] (see
/// `ratchet.dart`) initialised via [X3DHEngine] (see `x3dh.dart`). The wiring
/// from [E2EESession] to those engines is the remaining work item.
class CryptoService {
  static final _x25519 = Cryptography.instance.x25519();
  static final _ed25519 = Cryptography.instance.ed25519();
  static final _aead = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _sha256 = Sha256();

  // ── Key generation ────────────────────────────────────────────────────────

  /// Generates a new long-lived X25519 identity key pair.
  static Future<SimpleKeyPair> generateIdentityKeyPair() => _x25519.newKeyPair();

  /// Generates a new Ed25519 signing key pair (for signing prekeys).
  static Future<SimpleKeyPair> generateSigningKeyPair() => _ed25519.newKeyPair();

  /// Generates a fresh X25519 prekey.
  static Future<SimpleKeyPair> generatePrekey() => _x25519.newKeyPair();

  /// Generates a one-time prekey (alias for [generatePrekey] semantically).
  static Future<SimpleKeyPair> generateOneTimePrekey() => _x25519.newKeyPair();

  // ── Signing ───────────────────────────────────────────────────────────────

  /// Signs [data] with the Ed25519 [signingKeyPair]. Returns 64-byte signature.
  static Future<Uint8List> sign(SimpleKeyPair signingKeyPair, List<int> data) async {
    final signature = await _ed25519.sign(data, keyPair: signingKeyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 signature.
  static Future<bool> verify(
    List<int> data,
    Uint8List signatureBytes,
    Uint8List signingPubBytes,
  ) async {
    final signature = Signature(signatureBytes,
        publicKey: SimplePublicKey(signingPubBytes, type: KeyPairType.ed25519));
    return _ed25519.verify(data, signature: signature);
  }

  // ── Encryption / Decryption ──────────────────────────────────────────────

  /// **DEPRECATED** — single-shot 3-DH only, no Double Ratchet.
  /// Use the [DoubleRatchet] engine for per-message forward secrecy.
  ///
  /// Encrypts [plaintext] for a single recipient using:
  ///   shared = HKDF( X25519(ephemeralPriv, recipientIdentityPub) ||
  ///                  X25519(ephemeralPriv, recipientSignedPrekeyPub) ||
  ///                  X25519(ephemeralPriv, recipientOneTimePrekeyPub?) )
  ///
  /// Returns (ciphertext, nonce, ephemeralPub).
  @Deprecated('Use DoubleRatchet via E2EESession once v2 wiring lands. This path lacks PFS on receiver side and post-compromise security.')
  static Future<EncryptResult> encrypt({
    required Uint8List plaintext,
    required Uint8List recipientIdentityPub,
    required Uint8List recipientSignedPrekeyPub,
    Uint8List? recipientOneTimePrekeyPub,
  }) async {
    // 1. Generate ephemeral key pair (forward secrecy on sender side)
    final ephemeral = await _x25519.newKeyPair();

    // 2. Derive shared secret from concatenated ECDH outputs
    final shared = await _deriveSharedSecret(
      ephemeralPriv: ephemeral,
      identityPub: recipientIdentityPub,
      signedPrekeyPub: recipientSignedPrekeyPub,
      oneTimePrekeyPub: recipientOneTimePrekeyPub,
      info: 'flicko-e2ee-v1-encrypt',
    );

    // 3. Encrypt with XChaCha20-Poly1305
    final secretKey = SecretKey(shared);
    final nonce = _aead.newNonce();
    final secretBox = await _aead.encrypt(plaintext,
        secretKey: secretKey, nonce: nonce);

    // Combine ciphertext || mac into one buffer (recipient splits later)
    final combined = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    combined.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    combined.setRange(
        secretBox.cipherText.length, combined.length, secretBox.mac.bytes);

    final ephPubBytes = await ephemeral.extractPublicKey();

    return EncryptResult(
      ciphertext: combined,
      nonce: Uint8List.fromList(nonce),
      ephemeralPub: Uint8List.fromList(ephPubBytes.bytes),
    );
  }

  /// **DEPRECATED** — paired with [encrypt]; no Double Ratchet.
  ///
  /// Decrypts an envelope. Caller supplies the recipient's matching
  /// private keys for whichever prekeys the sender consumed.
  @Deprecated('Use DoubleRatchet via E2EESession once v2 wiring lands.')
  static Future<Uint8List> decrypt({
    required Uint8List ciphertextWithMac,
    required Uint8List nonce,
    required Uint8List senderEphemeralPub,
    required SimpleKeyPair recipientIdentityPriv,
    required SimpleKeyPair recipientSignedPrekeyPriv,
    SimpleKeyPair? recipientOneTimePrekeyPriv,
  }) async {
    final shared = await _deriveSharedSecretRecipient(
      senderEphemeralPub: senderEphemeralPub,
      identityPriv: recipientIdentityPriv,
      signedPrekeyPriv: recipientSignedPrekeyPriv,
      oneTimePrekeyPriv: recipientOneTimePrekeyPriv,
      info: 'flicko-e2ee-v1-encrypt',
    );

    // Split combined buffer back into ciphertext + mac (poly1305 mac is 16B)
    if (ciphertextWithMac.length < 16) {
      throw const FormatException('e2ee: ciphertext too short');
    }
    final macStart = ciphertextWithMac.length - 16;
    final cipherOnly = ciphertextWithMac.sublist(0, macStart);
    final macBytes = ciphertextWithMac.sublist(macStart);

    final box = SecretBox(cipherOnly, nonce: nonce, mac: Mac(macBytes));
    final plain = await _aead.decrypt(box, secretKey: SecretKey(shared));
    return Uint8List.fromList(plain);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  static Future<List<int>> _deriveSharedSecret({
    required SimpleKeyPair ephemeralPriv,
    required Uint8List identityPub,
    required Uint8List signedPrekeyPub,
    Uint8List? oneTimePrekeyPub,
    required String info,
  }) async {
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: ephemeralPriv,
      remotePublicKey: SimplePublicKey(identityPub, type: KeyPairType.x25519),
    );
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ephemeralPriv,
      remotePublicKey:
          SimplePublicKey(signedPrekeyPub, type: KeyPairType.x25519),
    );

    final concat = <int>[]
      ..addAll(await dh1.extractBytes())
      ..addAll(await dh2.extractBytes());

    if (oneTimePrekeyPub != null) {
      final dh3 = await _x25519.sharedSecretKey(
        keyPair: ephemeralPriv,
        remotePublicKey:
            SimplePublicKey(oneTimePrekeyPub, type: KeyPairType.x25519),
      );
      concat.addAll(await dh3.extractBytes());
    }

    final out = await _hkdf.deriveKey(
      secretKey: SecretKey(concat),
      info: utf8.encode(info),
      nonce: Uint8List(0), // HKDF salt; empty is acceptable here
    );
    return out.extractBytes();
  }

  static Future<List<int>> _deriveSharedSecretRecipient({
    required Uint8List senderEphemeralPub,
    required SimpleKeyPair identityPriv,
    required SimpleKeyPair signedPrekeyPriv,
    SimpleKeyPair? oneTimePrekeyPriv,
    required String info,
  }) async {
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: identityPriv,
      remotePublicKey:
          SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
    );
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: signedPrekeyPriv,
      remotePublicKey:
          SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
    );

    final concat = <int>[]
      ..addAll(await dh1.extractBytes())
      ..addAll(await dh2.extractBytes());

    if (oneTimePrekeyPriv != null) {
      final dh3 = await _x25519.sharedSecretKey(
        keyPair: oneTimePrekeyPriv,
        remotePublicKey:
            SimplePublicKey(senderEphemeralPub, type: KeyPairType.x25519),
      );
      concat.addAll(await dh3.extractBytes());
    }

    final out = await _hkdf.deriveKey(
      secretKey: SecretKey(concat),
      info: utf8.encode(info),
      nonce: Uint8List(0),
    );
    return out.extractBytes();
  }

  // ── Fingerprint helpers ──────────────────────────────────────────────────

  /// SHA-256 of the public key, hex-encoded. Shown to users to verify a
  /// peer's identity (compare with the peer out-of-band).
  static Future<String> fingerprintHex(Uint8List publicKey) async {
    final hash = await _sha256.hash(publicKey);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Same fingerprint formatted in groups of 4 hex chars for human reading.
  static String prettifyFingerprint(String hex) {
    final buf = StringBuffer();
    for (var i = 0; i < hex.length; i += 4) {
      if (i > 0) buf.write(' ');
      buf.write(hex.substring(i, (i + 4).clamp(0, hex.length)));
    }
    return buf.toString();
  }
}

class EncryptResult {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List ephemeralPub;

  const EncryptResult({
    required this.ciphertext,
    required this.nonce,
    required this.ephemeralPub,
  });
}

/// Riverpod provider — pure static service, but we wrap it for testability.
final cryptoServiceProvider = Provider<CryptoService>((_) => CryptoService());
