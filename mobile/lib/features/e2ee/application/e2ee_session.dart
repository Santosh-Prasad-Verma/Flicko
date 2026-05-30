import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/e2ee_repository.dart';
import '../data/ratchet_wal_store.dart';
import '../data/secure_keystore.dart';
// ignore: deprecated_member_use_from_same_package
import '../domain/crypto_service.dart';
import '../domain/e2ee_models.dart';
import '../domain/identity_verification.dart';
import '../domain/ratchet.dart';
import '../domain/x3dh.dart';

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
  final RatchetWalStore _wal;

  E2EESession(this._local, this._remote, this._wal);

  // ── Conversation keying ──────────────────────────────────────────────────

  /// Per-peer-device key for the WAL store. Keyed by *who I'm talking to*,
  /// so each side independently agrees on the slot.
  String _convKey(String peerUserId, String peerDeviceId) =>
      'conv:$peerUserId:$peerDeviceId';

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

  // ── v2: X3DH + Double Ratchet ────────────────────────────────────────────

  /// Encrypt [plaintext] for [recipientUserId] using the v2 protocol.
  ///
  /// First call to a new conversation runs X3DH against the peer's bundle
  /// and emits an `is_initial=true` envelope. Subsequent calls advance the
  /// existing Double Ratchet state from [RatchetWalStore].
  ///
  /// If [peerDevice] is provided, encrypts to that specific device. Otherwise
  /// uses whatever device the server returns from `fetchIdentity` (most
  /// recent). To fan-out across all of a user's devices, use
  /// [encryptV2ToAllDevices].
  Future<EncryptedEnvelope> encryptV2({
    required String recipientUserId,
    required String plaintext,
    IdentityKey? peerDevice,
  }) async {
    final senderDeviceId = await _local.getOrCreateDeviceId();
    final identityKp = await _local.loadIdentityKeyPair();
    if (identityKp == null) {
      throw StateError('e2ee/v2: identity key missing — call ensureBootstrapped');
    }
    final myIdPubBytes = (await identityKp.extractPublicKey()).bytes;

    // Resolve which peer device we're targeting.
    final peerIdentity = peerDevice ?? await _remote.fetchIdentity(recipientUserId);
    if (peerIdentity == null) {
      throw StateError('e2ee/v2: recipient $recipientUserId has no published keys');
    }
    final peerDeviceId = peerIdentity.deviceId;
    final convKey = _convKey(recipientUserId, peerDeviceId);

    // Try to recover an existing ratchet state.
    var state = await _wal.recover(convKey);

    var isInitial = false;
    String? initialEphemeralPub;
    int? consumedOtkId;
    int? signedPrekeyId;

    if (state == null) {
      // No session yet — bootstrap via X3DH. Pin the bundle to the device id
      // we resolved above so multi-device fan-out targets the right ratchet.
      final bundle = await _remote.fetchBundle(recipientUserId, deviceId: peerDeviceId);
      if (bundle == null) {
        throw StateError('e2ee/v2: bundle fetch failed for $recipientUserId');
      }
      final x3dh = await X3DHEngine.initiatorStart(
        bundle: bundle,
        myIdentityKeyPair: identityKp,
      );
      final spkPubBytes = base64Decode(bundle.signedPrekey.publicKey);
      state = await DoubleRatchet.initSender(
        sharedKey: x3dh.rootKey,
        recipientDhPub: Uint8List.fromList(spkPubBytes),
      );
      isInitial = true;
      initialEphemeralPub = base64Encode(x3dh.ephemeralPub);
      consumedOtkId = x3dh.oneTimePrekeyId;
      signedPrekeyId = x3dh.signedPrekeyId;
    }

    // Encrypt with the ratchet. AAD binds sender + recipient identities.
    final aad = Uint8List.fromList([
      ...myIdPubBytes,
      ...base64Decode(peerIdentity.identityPub),
    ]);
    final result = await DoubleRatchet.encrypt(
      state: state,
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
      associatedData: aad,
    );

    // Persist the advanced state.
    await _wal.append(convKey, result.state);

    return EncryptedEnvelope(
      protocolVersion: 'v2',
      ciphertext: base64Encode(result.ciphertext),
      nonce: '', // v2 packs nonce inside ciphertext
      ratchetHeader: base64Encode(result.header.encode()),
      senderEphemeralPub: initialEphemeralPub ?? '',
      senderDeviceId: senderDeviceId,
      recipientDeviceId: peerDeviceId,
      isInitial: isInitial,
      senderIdentityPub: isInitial ? base64Encode(myIdPubBytes) : null,
      prekeyId: consumedOtkId,
      signedPrekeyId: signedPrekeyId,
    );
  }

  /// Multi-device fan-out: encrypts [plaintext] once per recipient device.
  ///
  /// Returns one [EncryptedEnvelope] per device the recipient owns, each
  /// with its own independent Double Ratchet session. The DM layer pushes
  /// each envelope separately to the relay; the recipient's devices each
  /// see exactly the envelope addressed to them.
  ///
  /// If the recipient has no devices registered, returns an empty list —
  /// caller may fall back to plaintext or surface a "not on E2EE" warning.
  Future<List<EncryptedEnvelope>> encryptV2ToAllDevices({
    required String recipientUserId,
    required String plaintext,
  }) async {
    final devices = await _remote.fetchDevices(recipientUserId);
    if (devices.isEmpty) {
      // Fallback: try the legacy single-device path so a recipient that
      // never re-published doesn't break.
      final single = await _remote.fetchIdentity(recipientUserId);
      if (single == null) return const [];
      return [
        await encryptV2(
          recipientUserId: recipientUserId,
          plaintext: plaintext,
          peerDevice: single,
        ),
      ];
    }
    final out = <EncryptedEnvelope>[];
    for (final dev in devices) {
      out.add(await encryptV2(
        recipientUserId: recipientUserId,
        plaintext: plaintext,
        peerDevice: dev,
      ));
    }
    return out;
  }

  /// Decrypt a v2 envelope. On `is_initial=true` envelopes, runs the X3DH
  /// responder path before invoking the ratchet.
  Future<String> decryptV2(EncryptedEnvelope env, {required String senderUserId}) async {
    if (env.protocolVersion != 'v2') {
      throw ArgumentError('e2ee/v2: envelope is not v2 (got ${env.protocolVersion})');
    }
    if (env.ratchetHeader == null || env.ratchetHeader!.isEmpty) {
      throw ArgumentError('e2ee/v2: missing ratchet header');
    }

    final identityKp = await _local.loadIdentityKeyPair();
    if (identityKp == null) {
      throw StateError('e2ee/v2: identity key missing');
    }
    final myIdPubBytes = (await identityKp.extractPublicKey()).bytes;
    final myDeviceId = await _local.getOrCreateDeviceId();

    // Defensive: if the envelope was addressed to a different device, refuse.
    if (env.recipientDeviceId.isNotEmpty && env.recipientDeviceId != myDeviceId) {
      throw StateError(
        'e2ee/v2: envelope addressed to ${env.recipientDeviceId} but this is $myDeviceId',
      );
    }

    final convKey = _convKey(senderUserId, env.senderDeviceId);
    var state = await _wal.recover(convKey);

    if (state == null) {
      // First-contact: must be an initial envelope; run X3DH responder.
      if (!env.isInitial ||
          env.senderIdentityPub == null ||
          env.senderEphemeralPub.isEmpty) {
        throw StateError('e2ee/v2: no session and envelope is not initial');
      }
      final spk = await _local.loadSignedPrekey();
      if (spk == null) {
        throw StateError('e2ee/v2: signed prekey missing');
      }
      SimpleKeyPair? otkKp;
      if (env.prekeyId != null) {
        otkKp = await _local.consumeOneTimePrekey(env.prekeyId!);
      }
      final x3dh = await X3DHEngine.responderAccept(
        senderEphemeralPub: Uint8List.fromList(base64Decode(env.senderEphemeralPub)),
        senderIdentityPub: Uint8List.fromList(base64Decode(env.senderIdentityPub!)),
        myIdentityKeyPair: identityKp,
        mySignedPrekeyKeyPair: spk.keyPair,
        signedPrekeyId: env.signedPrekeyId ?? spk.keyId,
        myOneTimePrekeyKeyPair: otkKp,
        oneTimePrekeyId: env.prekeyId,
      );
      state = await DoubleRatchet.initRecipient(
        sharedKey: x3dh.rootKey,
        mySignedPrekey: spk.keyPair,
      );
    }

    final senderIdPubBytes = env.senderIdentityPub != null
        ? Uint8List.fromList(base64Decode(env.senderIdentityPub!))
        : await _resolvePeerIdentityPub(senderUserId, env.senderDeviceId);
    final aad = Uint8List.fromList([
      ...senderIdPubBytes,
      ...myIdPubBytes,
    ]);

    final header = RatchetHeader.decode(
      Uint8List.fromList(base64Decode(env.ratchetHeader!)),
    );
    final result = await DoubleRatchet.decrypt(
      state: state,
      header: header,
      ciphertext: Uint8List.fromList(base64Decode(env.ciphertext)),
      associatedData: aad,
    );

    await _wal.append(convKey, result.state);
    _maybeRefillOneTimePrekeys(await _local.getOrCreateDeviceId()).ignore();

    return utf8.decode(result.plaintext);
  }

  Future<Uint8List> _resolvePeerIdentityPub(String peerUserId,
      [String? peerDeviceId]) async {
    final id = await _remote.fetchIdentity(peerUserId, deviceId: peerDeviceId);
    if (id == null) {
      throw StateError('e2ee/v2: cannot resolve identity for $peerUserId');
    }
    return Uint8List.fromList(base64Decode(id.identityPub));
  }

  // ── v1: legacy single-shot 3-DH (DEPRECATED) ─────────────────────────────


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

  /// This device's stable id. Used by callers (e.g. DM repo) that need to
  /// pick out the envelope addressed to *this* device from a fan-out batch.
  Future<String> getMyDeviceId() => _local.getOrCreateDeviceId();

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

  // ── Identity change detection (R12.4, R16) ───────────────────────────────

  /// Compare a peer's currently-published identity fingerprint against the
  /// one we last pinned for them. Returns:
  ///   - `null` when the peer has no published identity (or fetch failed).
  ///   - An [IdentityChangeAlert] when this is first contact OR a rotation
  ///     was detected. The caller (UI) decides whether to surface a banner.
  ///
  /// First-contact (TOFU): the alert's `oldFingerprint` is empty and the
  /// caller should call [acknowledgePeerIdentity] silently if the user is
  /// initiating the conversation.
  ///
  /// Rotation: `oldFingerprint != newFingerprint`. The caller MUST surface
  /// this to the user; encryption to this peer should pause until the user
  /// either re-verifies and acknowledges OR explicitly accepts the new key.
  ///
  /// `hasAttestation` is set when the peer published a rotation attestation
  /// signed by the OLD signing key we already pinned, AND that signature
  /// verifies. The banner uses this to soften its tone — not silent, but
  /// "key changed and the change is authenticated" rather than "key changed
  /// out of nowhere."
  Future<IdentityChangeAlert?> checkPeerIdentityChange(String peerUserId) async {
    final id = await _remote.fetchIdentity(peerUserId);
    if (id == null) return null;
    final newFp = id.fingerprint;
    final oldFp = await _local.getLastSeenPeerFingerprint(peerUserId);
    if (oldFp == newFp) return null; // No change — quiet path.

    var hasAttestation = false;
    if (oldFp != null && oldFp.isNotEmpty) {
      hasAttestation = await _verifyRotationAttestation(
        peerUserId: peerUserId,
        newIdentityPubB64: id.identityPub,
      );
    }

    return IdentityChangeAlert(
      userId: peerUserId,
      oldFingerprint: oldFp ?? '',
      newFingerprint: newFp,
      hasAttestation: hasAttestation,
      detectedAt: DateTime.now().toUtc(),
    );
  }

  /// Pin [peerUserId]'s current published fingerprint as trusted. Called by
  /// the UI after the user reviews and accepts a rotation, or silently on
  /// first contact for a conversation the user initiated.
  ///
  /// Stores both the fingerprint AND the peer's current signing pub so a
  /// future rotation can verify an attestation under the old signing key.
  Future<void> acknowledgePeerIdentity(String peerUserId) async {
    final id = await _remote.fetchIdentity(peerUserId);
    if (id == null) return;
    await _local.setLastSeenPeerFingerprint(
      peerUserId,
      id.fingerprint,
      signingPub: id.signingPub,
    );
  }

  /// Verify a rotation attestation: server returns the signature, we check
  /// it under the OLD signing pub we pinned. Returns false on any failure
  /// (no attestation published, no old signing pub stored, signature
  /// invalid). The caller treats false as "rotation is unauthenticated"
  /// — that's a safe default.
  Future<bool> _verifyRotationAttestation({
    required String peerUserId,
    required String newIdentityPubB64,
  }) async {
    try {
      final att = await _remote.fetchAttestation(
        userId: peerUserId,
        newIdentityPub: newIdentityPubB64,
      );
      if (att == null) return false;

      final oldSigningPubB64 =
          await _local.getLastSeenPeerSigningPub(peerUserId);
      if (oldSigningPubB64 == null || oldSigningPubB64.isEmpty) return false;

      // Canonical attestation message:
      //   "rotate:<base64(old_identity_pub)>:<base64(new_identity_pub)>"
      // Both sides agree on this format (see IdentityAttestation.create
      // in identity_verification.dart).
      final msg = utf8.encode(
          'rotate:${att.oldIdentityPub}:${att.newIdentityPub}');
      final sig = Signature(
        base64Decode(att.signature),
        publicKey: SimplePublicKey(
          base64Decode(oldSigningPubB64),
          type: KeyPairType.ed25519,
        ),
      );
      return Cryptography.instance.ed25519().verify(msg, signature: sig);
    } catch (_) {
      // Any failure = "no valid attestation". Don't crash, don't lie.
      return false;
    }
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
    ref.watch(ratchetWalStoreProvider),
  );
});
