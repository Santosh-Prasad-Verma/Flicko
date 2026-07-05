/// Double Ratchet state machine — full implementation.
///
/// Implements the Signal Double Ratchet protocol with:
///   - HKDF-SHA-256 chain advancement (domain-separated)
///   - XChaCha20-Poly1305 AEAD per message
///   - Bounded skipped-key cache (MAX_SKIP=1000)
///   - DH ratchet step with X25519
///   - Replay protection via (DHr, N) uniqueness
///
/// References:
///   design.md §4 (Double Ratchet)
///   requirements.md R5, R6
///   Signal Double Ratchet specification (2016)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'protocol_info.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// Maximum number of skipped message keys we will derive on a single
/// receiving chain before bailing. Bounded to prevent DoS via huge
/// out-of-order index claims (R5.5, R14.5).
const int kMaxSkip = 1000;

/// Domain-separation strings for HKDF derivations inside the ratchet.
/// Canonical source: [ProtocolInfo].
const String kRatchetMsgInfo = 'flicko-ratchet-msg-v2';
const String kRatchetSendInfo = 'flicko-ratchet-send-v2';
const String kRatchetRecvInfo = 'flicko-ratchet-recv-v2';
const String kRatchetRootInfo = 'flicko-ratchet-root-v2';

// ── Header ───────────────────────────────────────────────────────────────────

/// Header prepended to every encrypted DR message.
///
/// Wire format (compact): dhPub(32) || pn(4-byte BE) || n(4-byte BE) = 40 B.
class RatchetHeader {
  /// Sender's current sending DH public key (32 B X25519).
  final Uint8List dhPub;

  /// Number of messages in the previous sending chain
  /// (so the recipient knows how many keys to skip when ratcheting).
  final int pn;

  /// Index of this message inside the current sending chain.
  final int n;

  const RatchetHeader({
    required this.dhPub,
    required this.pn,
    required this.n,
  });

  /// Encode to a compact 40-byte wire representation.
  Uint8List encode() {
    final buf = Uint8List(40);
    buf.setRange(0, 32, dhPub);
    final bd = ByteData.view(buf.buffer, buf.offsetInBytes, 40);
    bd.setUint32(32, pn, Endian.big);
    bd.setUint32(36, n, Endian.big);
    return buf;
  }

  /// Decode from a 40-byte compact representation.
  factory RatchetHeader.decode(Uint8List bytes) {
    if (bytes.length < 40) {
      throw FormatException('RatchetHeader too short: ${bytes.length}');
    }
    final dhPub = Uint8List.fromList(bytes.sublist(0, 32));
    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, 40);
    return RatchetHeader(
      dhPub: dhPub,
      pn: bd.getUint32(32, Endian.big),
      n: bd.getUint32(36, Endian.big),
    );
  }
}

// ── Skipped Key Cache ────────────────────────────────────────────────────────

/// Identity tuple for the skipped-key cache.
class SkippedKeyId {
  final String dhPubB64;
  final int n;

  const SkippedKeyId(this.dhPubB64, this.n);

  @override
  bool operator ==(Object other) =>
      other is SkippedKeyId && other.dhPubB64 == dhPubB64 && other.n == n;

  @override
  int get hashCode => Object.hash(dhPubB64, n);

  @override
  String toString() => 'SkippedKeyId(n=$n)';
}

// ── Ratchet State ────────────────────────────────────────────────────────────

/// Per-conversation Double Ratchet state.
///
/// All private-key bytes live only inside [dhs] (a [SimpleKeyPair]).
/// The state is encrypted-at-rest by `RatchetStore` (Task 11).
class RatchetState {
  /// Current sending DH key pair. Rotates per DH ratchet step.
  SimpleKeyPair dhs;

  /// Most recent received DH public key (32 B). Null only on a fresh state
  /// before the first message arrives.
  Uint8List? dhrPub;

  /// 32-byte root key that feeds every chain-key derivation.
  Uint8List rk;

  /// Sending chain key (32 B). Null between DH ratchet steps.
  Uint8List? cks;

  /// Receiving chain key (32 B). Null until the first message is received.
  Uint8List? ckr;

  /// Counter for messages sent on the current sending chain.
  int ns;

  /// Counter for messages received on the current receiving chain.
  int nr;

  /// Number of messages that were sent on the previous sending chain
  /// (used by the recipient to skip across DH ratchet steps).
  int pn;

  /// Bounded cache of skipped message keys (out-of-order delivery).
  /// Map size MUST stay ≤ [kMaxSkip] across all chains combined.
  final Map<SkippedKeyId, Uint8List> skipped;

  RatchetState({
    required this.dhs,
    required this.dhrPub,
    required this.rk,
    required this.cks,
    required this.ckr,
    required this.ns,
    required this.nr,
    required this.pn,
    Map<SkippedKeyId, Uint8List>? skipped,
  }) : skipped = skipped ?? <SkippedKeyId, Uint8List>{};

  /// Serialize to JSON for diagnostic logging.
  /// Private key bytes are explicitly excluded (R5, R12.5).
  Map<String, dynamic> toDebugJson() {
    return {
      'dhs_pub': base64Encode(
          // We can't synchronously get the public key from SimpleKeyPair,
          // so we indicate presence only.
          Uint8List(0)),
      'dhr_pub': dhrPub != null ? base64Encode(dhrPub!) : null,
      'rk': '***REDACTED***',
      'cks': cks != null ? '***REDACTED***' : null,
      'ckr': ckr != null ? '***REDACTED***' : null,
      'ns': ns,
      'nr': nr,
      'pn': pn,
      'skipped_count': skipped.length,
    };
  }

  /// Perform the first root-key ratchet step to derive CKs.
    final dhOut = await _x25519.sharedSecretKey(
      keyPair: dhs,
      remotePublicKey:
          SimplePublicKey(recipientDhPub, type: KeyPairType.x25519),
    );
    final dhBytes = await dhOut.extractBytes();

    // Derive root key and sending chain key.
    final rkCk = await _kdfRootKey(sharedKey, Uint8List.fromList(dhBytes), kRatchetRootInfo);

    return RatchetState(
      dhs: dhs,
      dhrPub: Uint8List.fromList(recipientDhPub),
      rk: rkCk.rootKey,
      cks: rkCk.chainKey,
      ckr: null,
      ns: 0,
      nr: 0,
      pn: 0,
    );
  }

  /// Initialise a ratchet state for the **recipient** (Bob) after X3DH.
  ///
  /// [sharedKey] is the 32-byte SK from X3DH.
  /// [mySignedPrekey] is the SPK key pair used in X3DH (becomes first DHs).
  static Future<RatchetState> initRecipient({
    required Uint8List sharedKey,
    required SimpleKeyPair mySignedPrekey,
  }) async {
    return RatchetState(
      dhs: mySignedPrekey,
      dhrPub: null,
      rk: Uint8List.fromList(sharedKey),
      cks: null,
      ckr: null,
      ns: 0,
      nr: 0,
      pn: 0,
    );
  }

  // ── Sending Chain ──────────────────────────────────────────────────────────

  /// Advance the sending chain key and derive a one-time message key.
  ///
  /// The old chain key is discarded (forward secrecy per message — R5.1, R5.2).
  static Future<({Uint8List chainKey, Uint8List messageKey})>
      advanceSendingChain(Uint8List currentCk) async {
    // We do two HKDF rounds: one for chain key, one for message key.
    final newCk = await _hkdfDerive(currentCk, '$kRatchetMsgInfo-ck');
    final mk = await _hkdfDerive(currentCk, '$kRatchetMsgInfo-mk');
    return (chainKey: newCk, messageKey: mk);
  }

  /// Encrypt [plaintext] for the next outbound message.
  ///
  /// Returns the new state, header, and ciphertext (incl. AEAD tag).
  /// AAD includes header + sender + recipient (R5.7).
  static Future<({RatchetState state, RatchetHeader header, Uint8List ciphertext})>
      encrypt({
    required RatchetState state,
    required Uint8List plaintext,
    required Uint8List associatedData,
  }) async {
    if (state.cks == null) {
      throw StateError('DoubleRatchet.encrypt: sending chain not initialised');
    }

    // Advance the sending chain.
    final advanced = await advanceSendingChain(state.cks!);
    state.cks = advanced.chainKey;

    // Build header.
    final dhsPub = await state.dhs.extractPublicKey();
    final header = RatchetHeader(
      dhPub: Uint8List.fromList(dhsPub.bytes),
      pn: state.pn,
      n: state.ns,
    );
    state.ns += 1;

    // Build full AAD: encoded header || caller-supplied AD.
    final headerBytes = header.encode();
    final fullAd = Uint8List(headerBytes.length + associatedData.length)
      ..setRange(0, headerBytes.length, headerBytes)
      ..setRange(headerBytes.length,
          headerBytes.length + associatedData.length, associatedData);

    // AEAD encrypt with XChaCha20-Poly1305.
    final secretKey = SecretKey(advanced.messageKey);
    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: fullAd,
    );

    // Combine nonce(24) + ciphertext + mac(16) into one buffer.
    final ct = Uint8List(24 + box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, 24, nonce)
      ..setRange(24, 24 + box.cipherText.length, box.cipherText)
      ..setRange(24 + box.cipherText.length,
          24 + box.cipherText.length + box.mac.bytes.length, box.mac.bytes);

    return (state: state, header: header, ciphertext: ct);
  }

  // ── Receiving Chain ────────────────────────────────────────────────────────

  /// Decrypt [ciphertext] using [header] against the current receiving chain.
  ///
  /// Performs a DH ratchet step if [header.dhPub] differs from `state.dhrPub`.
  /// Handles in-order, out-of-order, and skipped cases.
  static Future<({RatchetState state, Uint8List plaintext})> decrypt({
    required RatchetState state,
    required RatchetHeader header,
    required Uint8List ciphertext,
    required Uint8List associatedData,
  }) async {
    // 1. Check skipped-key cache first (out-of-order delivery).
    final skippedId =
        SkippedKeyId(base64Encode(header.dhPub), header.n);
    final cachedMk = state.skipped[skippedId];
    if (cachedMk != null) {
      state.skipped.remove(skippedId);
      final pt = await _decryptWithKey(
          cachedMk, header, ciphertext, associatedData);
      return (state: state, plaintext: pt);
    }

    // 2. DH ratchet step if the header advertises a new DH key.
    final headerDhB64 = base64Encode(header.dhPub);
    final currentDhrB64 =
        state.dhrPub != null ? base64Encode(state.dhrPub!) : null;

    if (headerDhB64 != currentDhrB64) {
      // Skip missing messages on the old receiving chain.
      await _skipMessageKeys(state, state.nr, header.pn);

      // Perform the DH ratchet.
      await _dhRatchetStep(state, header.dhPub);
    }

    // 3. Skip missing messages on the current receiving chain.
    await _skipMessageKeys(state, state.nr, header.n);

    // 4. Advance the receiving chain to get this message's key.
    if (state.ckr == null) {
      throw RatchetDecryptError('Receiving chain key is null');
    }
    final advanced = await advanceSendingChain(state.ckr!);
    state.ckr = advanced.chainKey;
    state.nr += 1;

    // 5. Decrypt.
    final pt = await _decryptWithKey(
        advanced.messageKey, header, ciphertext, associatedData);
    return (state: state, plaintext: pt);
  }

  // ── DH Ratchet Step ────────────────────────────────────────────────────────

  /// Performs a DH ratchet step when a new remote DH key is seen.
  static Future<void> _dhRatchetStep(
      RatchetState state, Uint8List newDhrPub) async {
    state.pn = state.ns;
    state.ns = 0;
    state.nr = 0;
    state.dhrPub = Uint8List.fromList(newDhrPub);

    // Derive receiving chain key.
    final dhRecv = await _x25519.sharedSecretKey(
      keyPair: state.dhs,
      remotePublicKey:
          SimplePublicKey(newDhrPub, type: KeyPairType.x25519),
    );
    final dhRecvBytes = await dhRecv.extractBytes();
    final rkCkr = await _kdfRootKey(state.rk, Uint8List.fromList(dhRecvBytes), kRatchetRootInfo);
    state.rk = rkCkr.rootKey;
    state.ckr = rkCkr.chainKey;

    // Generate a new sending DH pair.
    state.dhs = await _x25519.newKeyPair();

    // Derive sending chain key.
    final dhSend = await _x25519.sharedSecretKey(
      keyPair: state.dhs,
      remotePublicKey:
          SimplePublicKey(newDhrPub, type: KeyPairType.x25519),
    );
    final dhSendBytes = await dhSend.extractBytes();
    final rkCks = await _kdfRootKey(state.rk, Uint8List.fromList(dhSendBytes), kRatchetRootInfo);
    state.rk = rkCks.rootKey;
    state.cks = rkCks.chainKey;
  }

  /// Skip and cache message keys for out-of-order delivery.
  static Future<void> _skipMessageKeys(
      RatchetState state, int start, int until) async {
    if (until - start > kMaxSkip) {
      throw RatchetSkipExceededError(until - start);
    }
    if (state.ckr == null) return;

    final dhrB64 =
        state.dhrPub != null ? base64Encode(state.dhrPub!) : '';
    for (var i = start; i < until; i++) {
      final advanced = await advanceSendingChain(state.ckr!);
      state.ckr = advanced.chainKey;
      state.skipped[SkippedKeyId(dhrB64, i)] = advanced.messageKey;

      // Evict oldest entries if we exceed the global cap.
      while (state.skipped.length > kMaxSkip) {
        state.skipped.remove(state.skipped.keys.first);
      }
    }
    // Update the counter to match the skip target.
    if (start < until) {
      state.nr = until;
    }
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  /// Root key KDF: HKDF(rk || dhOutput, info=domain).
  /// Returns new root key and chain key.
  static Future<({Uint8List rootKey, Uint8List chainKey})> _kdfRootKey(
      Uint8List rk, Uint8List dhOutput, String info) async {
    // Use HKDF with the DH output as IKM and the current root key as salt.
    final hkdf64 = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
    final derived = await hkdf64.deriveKey(
      secretKey: SecretKey(dhOutput),
      info: utf8.encode(info),
      nonce: rk, // Using rk as the HKDF salt.
    );
    final bytes = await derived.extractBytes();
    return (
      rootKey: Uint8List.fromList(bytes.sublist(0, 32)),
      chainKey: Uint8List.fromList(bytes.sublist(32, 64)),
    );
  }

  /// HKDF derive 32 bytes from a key and info string.
  static Future<Uint8List> _hkdfDerive(Uint8List key, String info) async {
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(key),
      info: utf8.encode(info),
      nonce: Uint8List(0),
    );
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Decrypt a single message with a known message key.
  static Future<Uint8List> _decryptWithKey(
    Uint8List mk,
    RatchetHeader header,
    Uint8List ciphertext,
    Uint8List associatedData,
  ) async {
    if (ciphertext.length < 40) {
      // 24 (nonce) + 16 (mac) minimum
      throw RatchetDecryptError('Ciphertext too short');
    }

    // Build full AAD.
    final headerBytes = header.encode();
    final fullAd = Uint8List(headerBytes.length + associatedData.length)
      ..setRange(0, headerBytes.length, headerBytes)
      ..setRange(headerBytes.length,
          headerBytes.length + associatedData.length, associatedData);

    // Split ciphertext: nonce(24) || encrypted || mac(16).
    final nonce = ciphertext.sublist(0, 24);
    final macStart = ciphertext.length - 16;
    final encrypted = ciphertext.sublist(24, macStart);
    final mac = ciphertext.sublist(macStart);

    try {
      final box = SecretBox(encrypted, nonce: nonce, mac: Mac(mac));
      final plaintext = await _aead.decrypt(
        box,
        secretKey: SecretKey(mk),
        aad: fullAd,
      );
      return Uint8List.fromList(plaintext);
    } catch (e) {
      throw RatchetDecryptError('AEAD decrypt failed: $e');
    }
  }
}
