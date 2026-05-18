import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local, encrypted-at-rest storage for E2EE private keys.
///
/// Backed by `flutter_secure_storage` which uses:
///   - Android: EncryptedSharedPreferences + Keystore
///   - iOS:     Keychain
///
/// Keys are stored as base64 strings under structured names so we can list
/// or rotate by prefix.
///
/// **NEVER** transmit anything from this store to the network. The repository
/// layer enforces that contract.
class SecureKeystore {
  static const _ns = 'flicko.e2ee';
  static const _kIdentityPriv = '$_ns.identity.priv';
  static const _kIdentityPub = '$_ns.identity.pub';
  static const _kSigningPriv = '$_ns.signing.priv';
  static const _kSigningPub = '$_ns.signing.pub';
  static const _kDeviceId = '$_ns.device_id';
  static const _kSignedPrekeyPriv = '$_ns.signed_prekey.priv';
  static const _kSignedPrekeyId = '$_ns.signed_prekey.id';
  static const _kOtkPrivPrefix = '$_ns.otk.priv.'; // + keyId
  static const _kNextOtkId = '$_ns.otk.next_id';
  static const _kNextSignedPrekeyId = '$_ns.signed_prekey.next_id';

  final FlutterSecureStorage _storage;

  SecureKeystore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  // ── Device ID ────────────────────────────────────────────────────────────

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    // 16-byte random ID, hex-encoded
    final rng = SecretKeyData.random(length: 16);
    final bytes = await rng.extractBytes();
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  // ── Identity / Signing ───────────────────────────────────────────────────

  Future<bool> hasIdentity() async {
    final priv = await _storage.read(key: _kIdentityPriv);
    return priv != null && priv.isNotEmpty;
  }

  Future<void> storeIdentity({
    required SimpleKeyPair identityKeyPair,
    required SimpleKeyPair signingKeyPair,
  }) async {
    await _saveKeyPair(identityKeyPair, _kIdentityPriv, _kIdentityPub);
    await _saveKeyPair(signingKeyPair, _kSigningPriv, _kSigningPub);
  }

  Future<SimpleKeyPair?> loadIdentityKeyPair() =>
      _loadKeyPair(_kIdentityPriv, _kIdentityPub, KeyPairType.x25519);

  Future<SimpleKeyPair?> loadSigningKeyPair() =>
      _loadKeyPair(_kSigningPriv, _kSigningPub, KeyPairType.ed25519);

  Future<Uint8List?> loadIdentityPub() async {
    final b64 = await _storage.read(key: _kIdentityPub);
    if (b64 == null) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  Future<Uint8List?> loadSigningPub() async {
    final b64 = await _storage.read(key: _kSigningPub);
    if (b64 == null) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  // ── Signed Prekey ────────────────────────────────────────────────────────

  Future<int> nextSignedPrekeyId() async {
    final raw = await _storage.read(key: _kNextSignedPrekeyId);
    final n = int.tryParse(raw ?? '') ?? 1;
    await _storage.write(key: _kNextSignedPrekeyId, value: '${n + 1}');
    return n;
  }

  Future<void> storeSignedPrekey({
    required int keyId,
    required SimpleKeyPair keyPair,
  }) async {
    final priv = await keyPair.extractPrivateKeyBytes();
    final pub = await keyPair.extractPublicKey();
    await _storage.write(
      key: _kSignedPrekeyPriv,
      value: jsonEncode({
        'key_id': keyId,
        'priv': base64Encode(priv),
        'pub': base64Encode(pub.bytes),
      }),
    );
    await _storage.write(key: _kSignedPrekeyId, value: '$keyId');
  }

  Future<({int keyId, SimpleKeyPair keyPair})?> loadSignedPrekey() async {
    final raw = await _storage.read(key: _kSignedPrekeyPriv);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final priv = base64Decode(j['priv'] as String);
    final pub = base64Decode(j['pub'] as String);
    final kp = SimpleKeyPairData(priv,
        publicKey: SimplePublicKey(pub, type: KeyPairType.x25519),
        type: KeyPairType.x25519);
    return (keyId: (j['key_id'] as num).toInt(), keyPair: kp);
  }

  // ── One-Time Prekeys ─────────────────────────────────────────────────────

  Future<int> nextOneTimePrekeyId() async {
    final raw = await _storage.read(key: _kNextOtkId);
    final n = int.tryParse(raw ?? '') ?? 1;
    await _storage.write(key: _kNextOtkId, value: '${n + 1}');
    return n;
  }

  Future<void> storeOneTimePrekey({
    required int keyId,
    required SimpleKeyPair keyPair,
  }) async {
    final priv = await keyPair.extractPrivateKeyBytes();
    final pub = await keyPair.extractPublicKey();
    await _storage.write(
      key: '$_kOtkPrivPrefix$keyId',
      value: jsonEncode({
        'priv': base64Encode(priv),
        'pub': base64Encode(pub.bytes),
      }),
    );
  }

  /// Consumes (deletes) the OTK private key after a peer used the matching pub.
  Future<SimpleKeyPair?> consumeOneTimePrekey(int keyId) async {
    final raw = await _storage.read(key: '$_kOtkPrivPrefix$keyId');
    if (raw == null) return null;
    await _storage.delete(key: '$_kOtkPrivPrefix$keyId');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final priv = base64Decode(j['priv'] as String);
    final pub = base64Decode(j['pub'] as String);
    return SimpleKeyPairData(priv,
        publicKey: SimplePublicKey(pub, type: KeyPairType.x25519),
        type: KeyPairType.x25519);
  }

  // ── Wipe (logout / panic button) ─────────────────────────────────────────

  /// Deletes all E2EE material. Use on logout or when the user explicitly
  /// resets keys.
  Future<void> wipe() async {
    final all = await _storage.readAll();
    for (final k in all.keys.where((k) => k.startsWith(_ns))) {
      await _storage.delete(key: k);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _saveKeyPair(
      SimpleKeyPair keyPair, String privKey, String pubKey) async {
    final priv = await keyPair.extractPrivateKeyBytes();
    final pub = await keyPair.extractPublicKey();
    await _storage.write(key: privKey, value: base64Encode(priv));
    await _storage.write(key: pubKey, value: base64Encode(pub.bytes));
  }

  Future<SimpleKeyPair?> _loadKeyPair(
      String privKey, String pubKey, KeyPairType type) async {
    final priv = await _storage.read(key: privKey);
    final pub = await _storage.read(key: pubKey);
    if (priv == null || pub == null) return null;
    return SimpleKeyPairData(
      base64Decode(priv),
      publicKey: SimplePublicKey(base64Decode(pub), type: type),
      type: type,
    );
  }
}

final secureKeystoreProvider = Provider<SecureKeystore>((_) => SecureKeystore());
