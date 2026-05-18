import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/e2ee_repository.dart';
import '../data/secure_keystore.dart';
import '../domain/crypto_service.dart';
import '../domain/e2ee_models.dart';

/// High-level façade for everything the rest of the app cares about.
///
/// Responsibilities:
///  1. Bootstrap a device on first run (generate identity, prekeys, upload).
///  2. Refill the one-time prekey pool when it runs low.
///  3. Encrypt outgoing DM bodies into [EncryptedEnvelope]s.
///  4. Decrypt inbound envelopes back into plaintext.
///  5. Surface peer fingerprints for verification UI.
///
/// Time complexity targets:
///  - encrypt: O(plaintext_len)
///  - decrypt: O(ciphertext_len)
///  - Bootstrap (first run): O(MaxPrekeyPool) one-time keypair generations
class E2EESession {
  static const int _prekeyPoolTarget = 25;
  static const int _prekeyPoolFloor = 5;

  final SecureKeystore _local;
  final E2EERepository _remote;

  E2EESession(this._local, this._remote);

  // ── Bootstrap ────────────────────────────────────────────────────────────

  /// Ensures this device has identity + signed prekey + a healthy OTK pool
  /// uploaded to the server. Idempotent — safe to call on every app launch.
  Future<void> ensureBootstrapped() async {
    final deviceId = await _local.getOrCreateDeviceId();

    if (!await _local.hasIdentity()) {
      await _generateAndUploadIdentity(deviceId);
    }

    if ((await _local.loadSignedPrekey()) == null) {
      await _generateAndUploadSignedPrekey(deviceId);
    }

    await _maybeRefillOneTimePrekeys(deviceId);
  }

  Future<void> _generateAndUploadIdentity(String deviceId) async {
    final identity = await CryptoService.generateIdentityKeyPair();
    final signing = await CryptoService.generateSigningKeyPair();
    await _local.storeIdentity(identityKeyPair: identity, signingKeyPair: signing);

    final identityPub = (await identity.extractPublicKey()).bytes;
    final signingPub = (await signing.extractPublicKey()).bytes;
    final fingerprint =
        await CryptoService.fingerprintHex(Uint8List.fromList(identityPub));

    await _remote.uploadIdentity(
      deviceId: deviceId,
      identityPub: base64Encode(identityPub),
      signingPub: base64Encode(signingPub),
      fingerprint: fingerprint,
    );
  }

  Future<void> _generateAndUploadSignedPrekey(String deviceId) async {
    final signingKp = await _local.loadSigningKeyPair();
    if (signingKp == null) {
      throw StateError('e2ee: signing key missing — did you call ensureBootstrapped?');
    }

    final keyId = await _local.nextSignedPrekeyId();
    final spk = await CryptoService.generatePrekey();
    await _local.storeSignedPrekey(keyId: keyId, keyPair: spk);

    final spkPub = (await spk.extractPublicKey()).bytes;
    final sig = await CryptoService.sign(signingKp, spkPub);

    await _remote.uploadSignedPrekey(
      deviceId: deviceId,
      keyId: keyId,
      publicKey: base64Encode(spkPub),
      signature: base64Encode(sig),
    );
  }

  Future<void> _maybeRefillOneTimePrekeys(String deviceId) async {
    final status = await _remote.getOneTimePrekeyCount(deviceId);
    if (status.count >= _prekeyPoolFloor) return;

    final toGenerate = _prekeyPoolTarget - status.count;
    final batch = <OneTimePrekey>[];
    for (var i = 0; i < toGenerate; i++) {
      final keyId = await _local.nextOneTimePrekeyId();
      final kp = await CryptoService.generateOneTimePrekey();
      await _local.storeOneTimePrekey(keyId: keyId, keyPair: kp);
      final pub = (await kp.extractPublicKey()).bytes;
      batch.add(OneTimePrekey(keyId: keyId, publicKey: base64Encode(pub)));
    }
    await _remote.uploadOneTimePrekeys(deviceId: deviceId, prekeys: batch);
  }

  /// Manual refill — exposed for settings screen ("regenerate keys" action).
  Future<void> refillOneTimePrekeys() async {
    final deviceId = await _local.getOrCreateDeviceId();
    await _maybeRefillOneTimePrekeys(deviceId);
  }

  // ── Encryption (outgoing) ────────────────────────────────────────────────

  /// Encrypts [plaintext] for [recipientUserId]. Returns the wire envelope.
  Future<EncryptedEnvelope> encrypt({
    required String recipientUserId,
    required String plaintext,
  }) async {
    final senderDeviceId = await _local.getOrCreateDeviceId();

    final bundle = await _remote.fetchBundle(recipientUserId);
    if (bundle == null) {
      throw StateError('e2ee: recipient $recipientUserId has no published keys');
    }

    // Verify signed prekey signature against recipient's signing pub
    final signingPub = base64Decode(bundle.identity.signingPub);
    final spkPub = base64Decode(bundle.signedPrekey.publicKey);
    final sig = base64Decode(bundle.signedPrekey.signature);
    final ok = await CryptoService.verify(
        spkPub, Uint8List.fromList(sig), Uint8List.fromList(signingPub));
    if (!ok) {
      throw StateError('e2ee: signed prekey signature invalid for $recipientUserId');
    }

    final identityPub = base64Decode(bundle.identity.identityPub);
    final otkPub = bundle.oneTimePrekey == null
        ? null
        : base64Decode(bundle.oneTimePrekey!.publicKey);

    final result = await CryptoService.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
      recipientIdentityPub: Uint8List.fromList(identityPub),
      recipientSignedPrekeyPub: Uint8List.fromList(spkPub),
      recipientOneTimePrekeyPub:
          otkPub == null ? null : Uint8List.fromList(otkPub),
    );

    return EncryptedEnvelope(
      ciphertext: base64Encode(result.ciphertext),
      nonce: base64Encode(result.nonce),
      senderEphemeralPub: base64Encode(result.ephemeralPub),
      senderDeviceId: senderDeviceId,
      recipientDeviceId: bundle.deviceId,
      prekeyId: bundle.oneTimePrekey?.keyId,
      signedPrekeyId: bundle.signedPrekey.keyId,
    );
  }

  // ── Decryption (incoming) ────────────────────────────────────────────────

  /// Decrypts an inbound envelope. Returns plaintext UTF-8.
  Future<String> decrypt(EncryptedEnvelope env) async {
    final identityKp = await _local.loadIdentityKeyPair();
    if (identityKp == null) {
      throw StateError('e2ee: identity key missing');
    }
    final signedPrekey = await _local.loadSignedPrekey();
    if (signedPrekey == null) {
      throw StateError('e2ee: signed prekey missing');
    }

    SimpleKeyPair? otkKp;
    if (env.prekeyId != null) {
      otkKp = await _local.consumeOneTimePrekey(env.prekeyId!);
      // If null, the OTK was already consumed (replay) — keep going without it,
      // shared secret derivation will simply fail and decrypt() will throw.
    }

    final plain = await CryptoService.decrypt(
      ciphertextWithMac: Uint8List.fromList(base64Decode(env.ciphertext)),
      nonce: Uint8List.fromList(base64Decode(env.nonce)),
      senderEphemeralPub:
          Uint8List.fromList(base64Decode(env.senderEphemeralPub)),
      recipientIdentityPriv: identityKp,
      recipientSignedPrekeyPriv: signedPrekey.keyPair,
      recipientOneTimePrekeyPriv: otkKp,
    );

    // Top up OTKs after each consumption — keep pool healthy.
    // Fire-and-forget; we don't block the read path.
    _maybeRefillOneTimePrekeys(env.recipientDeviceId).ignore();

    return utf8.decode(plain);
  }

  // ── Verification helpers ─────────────────────────────────────────────────

  /// Returns the local user's identity fingerprint (for QR / safety-number UI).
  Future<String> getMyFingerprint() async {
    final pub = await _local.loadIdentityPub();
    if (pub == null) {
      throw StateError('e2ee: not bootstrapped');
    }
    final fp = await CryptoService.fingerprintHex(pub);
    return CryptoService.prettifyFingerprint(fp);
  }

  /// Returns a peer's fingerprint as published on the server.
  Future<String?> getPeerFingerprint(String userId) async {
    final id = await _remote.fetchIdentity(userId);
    if (id == null) return null;
    return CryptoService.prettifyFingerprint(id.fingerprint);
  }

  // ── Conversation state passthrough ───────────────────────────────────────

  Future<bool> isConversationEnabled(String otherUserId) =>
      _remote.isConversationEnabled(otherUserId);

  Future<void> enableConversation(String otherUserId) =>
      _remote.enableConversation(otherUserId);
}

final e2eeSessionProvider = Provider<E2EESession>((ref) {
  return E2EESession(
    ref.watch(secureKeystoreProvider),
    ref.watch(e2eeRepositoryProvider),
  );
});
