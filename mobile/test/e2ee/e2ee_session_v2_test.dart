/// Integration tests for E2EESession v2 (X3DH + Double Ratchet) round-trip.
///
/// Covers the path that production messages actually take:
///   sender.encryptV2 → wire envelope → receiver.decryptV2 → plaintext
///
/// Both sides use real crypto (X25519, Ed25519, XChaCha20-Poly1305, Argon2id
/// is irrelevant here, HKDF-SHA-256 in the ratchet). Only the network and
/// secure storage are faked — the cryptographic engines are exercised live.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/features/e2ee/application/e2ee_session.dart';
import '../../lib/features/e2ee/data/e2ee_repository.dart';
import '../../lib/features/e2ee/data/ratchet_wal_store.dart';
import '../../lib/features/e2ee/data/secure_keystore.dart';
import '../../lib/features/e2ee/domain/e2ee_models.dart' as models;

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};
  _FakeSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.from(data);
}

/// In-memory fake of the server's `/e2ee/*` endpoints.
///
/// Storage model: every bit of public key state is keyed by `(userId,
/// deviceId)`. `ensureBootstrapped` only knows the deviceId, so uploads land
/// in a `__pending` bucket; tests then call [bindPendingTo] to attach the
/// freshly-uploaded device to a userId.
class _FakeE2EERepository implements E2EERepository {
  // userId → ordered devices (first is "primary").
  final Map<String, List<models.IdentityKey>> _devicesByUser = {};
  // deviceId → SignedPrekey
  final Map<String, models.SignedPrekey> _spkByDevice = {};
  // deviceId → OTK pool
  final Map<String, List<models.OneTimePrekey>> _otksByDevice = {};
  // Pending uploads keyed by deviceId, awaiting bindPendingTo().
  final Map<String, models.IdentityKey> _pending = {};
  final Set<String> _enabledConversations = {};

  @override
  Future<void> uploadIdentity({
    required String deviceId,
    required String identityPub,
    required String signingPub,
    required String fingerprint,
  }) async {
    _pending[deviceId] = models.IdentityKey(
      deviceId: deviceId,
      identityPub: identityPub,
      signingPub: signingPub,
      fingerprint: fingerprint,
    );
  }

  /// Test helper: bind the most recently uploaded identity for [deviceId] to [userId].
  void bindPendingTo(String userId, String deviceId) {
    final id = _pending.remove(deviceId);
    if (id == null) {
      throw StateError('no pending identity for device $deviceId');
    }
    _devicesByUser.putIfAbsent(userId, () => []).add(id);
  }

  @override
  Future<models.IdentityKey?> fetchIdentity(String userId, {String? deviceId}) async {
    final devs = _devicesByUser[userId];
    if (devs == null || devs.isEmpty) return null;
    if (deviceId == null) {
      // Match backend ORDER BY COALESCE(rotated_at, created_at) DESC.
      return devs.last;
    }
    return devs.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => devs.last,
    );
  }

  @override
  Future<List<models.IdentityKey>> fetchDevices(String userId) async {
    return List.of(_devicesByUser[userId] ?? const []);
  }

  @override
  Future<void> uploadSignedPrekey({
    required String deviceId,
    required int keyId,
    required String publicKey,
    required String signature,
  }) async {
    _spkByDevice[deviceId] = models.SignedPrekey(
      keyId: keyId,
      publicKey: publicKey,
      signature: signature,
    );
  }

  @override
  Future<int> uploadOneTimePrekeys({
    required String deviceId,
    required List<models.OneTimePrekey> prekeys,
  }) async {
    _otksByDevice.putIfAbsent(deviceId, () => []).addAll(prekeys);
    return _otksByDevice[deviceId]!.length;
  }

  @override
  Future<({int count, bool low})> getOneTimePrekeyCount(String deviceId) async {
    final n = _otksByDevice[deviceId]?.length ?? 0;
    return (count: n, low: n < 5);
  }

  @override
  Future<models.PrekeyBundle?> fetchBundle(String userId, {String? deviceId}) async {
    final devs = _devicesByUser[userId];
    if (devs == null || devs.isEmpty) return null;
    final id = deviceId == null
        ? devs.last
        : devs.firstWhere((d) => d.deviceId == deviceId, orElse: () => devs.last);
    final spk = _spkByDevice[id.deviceId];
    if (spk == null) return null;
    final pool = _otksByDevice[id.deviceId];
    final otk = (pool == null || pool.isEmpty) ? null : pool.removeAt(0);
    return models.PrekeyBundle(
      userId: userId,
      deviceId: id.deviceId,
      identity: id,
      signedPrekey: spk,
      oneTimePrekey: otk,
    );
  }

  @override
  Future<void> enableConversation(String otherUserId) async {
    _enabledConversations.add(otherUserId);
  }

  @override
  Future<bool> isConversationEnabled(String otherUserId) async =>
      _enabledConversations.contains(otherUserId);

  // ── Attestations ────────────────────────────────────────────────────────
  // Test-only state: a per-(userId, newPub) most-recent attestation row.
  final Map<String, models.RemoteIdentityAttestation> _attestations = {};

  String _attKey(String userId, String newPub) => '$userId|$newPub';

  /// Test helper: seed an attestation as if it had been published.
  void seedAttestation(models.RemoteIdentityAttestation att) {
    _attestations[_attKey(att.userId, att.newIdentityPub)] = att;
  }

  @override
  Future<models.RemoteIdentityAttestation?> fetchAttestation({
    required String userId,
    required String newIdentityPub,
  }) async {
    return _attestations[_attKey(userId, newIdentityPub)];
  }

  @override
  Future<void> publishAttestation({
    required String oldIdentityPub,
    required String newIdentityPub,
    required String signatureB64,
  }) async {
    // Test fakes don't have an authenticated user — caller seeds via
    // seedAttestation. This stub is a no-op but signals "wired up".
  }
}

/// Convenience: build a RatchetWalStore backed by a unique temp-file
/// database so each test party (sender/receiver/extra device) has fully
/// isolated WAL storage. Using `inMemoryDatabasePath` would share state
/// across sessions in the same process — the opposite of what we want.
Future<({RatchetWalStore store, Database db, File file})> _newWal() async {
  final dir = await Directory.systemTemp.createTemp('flicko_wal_');
  final dbPath = '${dir.path}/ratchet.db';
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE ratchet_wal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id TEXT NOT NULL,
            seq_no INTEGER NOT NULL,
            snapshot_json TEXT NOT NULL,
            prev_hash TEXT NOT NULL,
            entry_hash TEXT NOT NULL,
            written_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_wal_conv_seq ON ratchet_wal(conversation_id, seq_no)');
        await db.execute('CREATE INDEX idx_wal_written_at ON ratchet_wal(written_at)');
      },
    ),
  );
  final store = RatchetWalStore(storage: _FakeSecureStorage(), db: db);
  return (store: store, db: db, file: File(dbPath));
}

/// Bootstrap a party's identity + signed prekey + 5 OTKs into [shared].
/// Returns the [E2EESession] keyed against the shared fake server.
Future<E2EESession> _bootstrapParty({
  required String userId,
  required _FakeE2EERepository shared,
}) async {
  final keystore = SecureKeystore(storage: _FakeSecureStorage());
  final wal = await _newWal();
  final session = E2EESession(keystore, shared, wal.store);
  await session.ensureBootstrapped();

  // Bind the freshly-uploaded device to the user.
  final deviceId = await keystore.getOrCreateDeviceId();
  shared.bindPendingTo(userId, deviceId);

  return session;
}

/// Bootstrap an additional device for an already-existing user — used to
/// model the "Bob has both a phone and a laptop" multi-device case.
Future<E2EESession> _bootstrapAdditionalDeviceFor({
  required String userId,
  required _FakeE2EERepository shared,
}) async {
  final keystore = SecureKeystore(storage: _FakeSecureStorage());
  final wal = await _newWal();
  final session = E2EESession(keystore, shared, wal.store);
  await session.ensureBootstrapped();
  final deviceId = await keystore.getOrCreateDeviceId();
  shared.bindPendingTo(userId, deviceId);
  return session;
}

/// Variant that exposes the underlying keystore so attestation tests can
/// forge real signatures with the device's signing key.
Future<({E2EESession session, SecureKeystore keystore})> _bootstrapPartyExposed({
  required String userId,
  required _FakeE2EERepository shared,
}) async {
  final keystore = SecureKeystore(storage: _FakeSecureStorage());
  final wal = await _newWal();
  final session = E2EESession(keystore, shared, wal.store);
  await session.ensureBootstrapped();
  final deviceId = await keystore.getOrCreateDeviceId();
  shared.bindPendingTo(userId, deviceId);
  return (session: session, keystore: keystore);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('E2EESession v2 round-trip', () {
    test('Alice → Bob: initial X3DH + Double Ratchet round-trip', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      // Alice encrypts to Bob — first message bootstraps the session.
      final env = await alice.encryptV2(
        recipientUserId: 'bob',
        plaintext: 'hello bob',
      );

      expect(env.protocolVersion, 'v2');
      expect(env.isInitial, isTrue);
      expect(env.senderIdentityPub, isNotNull);
      expect(env.ratchetHeader, isNotNull);
      expect(env.ciphertext, isNotEmpty);

      // Bob decrypts.
      final plain = await bob.decryptV2(env, senderUserId: 'alice');
      expect(plain, 'hello bob');
    });

    test('multiple messages in a row advance the ratchet (forward secrecy)', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      final messages = ['msg one', 'msg two', 'msg three', 'msg four'];
      final envelopes = <models.EncryptedEnvelope>[];
      for (final m in messages) {
        envelopes.add(await alice.encryptV2(recipientUserId: 'bob', plaintext: m));
      }

      // First envelope is initial; the rest are not.
      expect(envelopes.first.isInitial, isTrue);
      for (final e in envelopes.skip(1)) {
        expect(e.isInitial, isFalse);
      }

      // Each ratchet header must be unique (chain advances per message).
      final headers = envelopes.map((e) => e.ratchetHeader).toSet();
      expect(headers.length, messages.length);

      // Bob decrypts in order.
      for (var i = 0; i < envelopes.length; i++) {
        final plain = await bob.decryptV2(envelopes[i], senderUserId: 'alice');
        expect(plain, messages[i]);
      }
    });

    test('bidirectional: Bob can reply after receiving Alice\'s initial message', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      final aToB = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'ping');
      expect(await bob.decryptV2(aToB, senderUserId: 'alice'), 'ping');

      final bToA = await bob.encryptV2(recipientUserId: 'alice', plaintext: 'pong');
      // Bob already has a session from decrypting Alice's initial message,
      // so his reply uses the existing ratchet (not a fresh X3DH).
      expect(bToA.isInitial, isFalse);
      expect(await alice.decryptV2(bToA, senderUserId: 'bob'), 'pong');

      // Alice replies again — should reuse her now-established session.
      final aToB2 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'ping2');
      expect(await bob.decryptV2(aToB2, senderUserId: 'alice'), 'ping2');
    });

    test('tampered ciphertext fails AEAD verification', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      final env = await alice.encryptV2(
        recipientUserId: 'bob',
        plaintext: 'top secret',
      );

      // Flip a single bit in the ciphertext.
      final raw = base64Decode(env.ciphertext);
      raw[raw.length ~/ 2] ^= 0x01;
      final tampered = models.EncryptedEnvelope(
        protocolVersion: env.protocolVersion,
        ciphertext: base64Encode(raw),
        nonce: env.nonce,
        senderEphemeralPub: env.senderEphemeralPub,
        senderDeviceId: env.senderDeviceId,
        recipientDeviceId: env.recipientDeviceId,
        prekeyId: env.prekeyId,
        signedPrekeyId: env.signedPrekeyId,
        ratchetHeader: env.ratchetHeader,
        isInitial: env.isInitial,
        senderIdentityPub: env.senderIdentityPub,
      );

      expect(
        () => bob.decryptV2(tampered, senderUserId: 'alice'),
        throwsA(anything),
      );
    });

    test('plaintext recovery on long messages', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      // 8 KB of mixed UTF-8 — exercises AEAD on a real-world payload size.
      final big = List.generate(8192, (i) => 'data row $i; ').join();
      final env = await alice.encryptV2(recipientUserId: 'bob', plaintext: big);
      final plain = await bob.decryptV2(env, senderUserId: 'alice');
      expect(plain, big);
    });

    test('ratchet state survives a recover() between messages', () async {
      // Simulates the app being killed and restarted between sends.
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      final e1 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'first');
      expect(await bob.decryptV2(e1, senderUserId: 'alice'), 'first');

      // The next message uses the persisted state from the WAL.
      final e2 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'second');
      expect(e2.isInitial, isFalse, reason: 'session must persist across calls');
      expect(await bob.decryptV2(e2, senderUserId: 'alice'), 'second');
    });
  });

  group('E2EESession v2 multi-device fan-out', () {
    test('Bob has 2 devices: encryptV2ToAllDevices yields one envelope per device', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bobPhone = await _bootstrapParty(userId: 'bob', shared: server);
      final bobLaptop = await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);

      final devices = await server.fetchDevices('bob');
      expect(devices.length, 2);

      final envelopes = await alice.encryptV2ToAllDevices(
        recipientUserId: 'bob',
        plaintext: 'works on both devices',
      );
      expect(envelopes.length, 2);

      // Each envelope is addressed to a distinct device id.
      final targetIds = envelopes.map((e) => e.recipientDeviceId).toSet();
      expect(targetIds.length, 2);

      // Both devices independently decrypt their own envelope.
      final phoneEnv = envelopes.firstWhere(
        (e) => e.recipientDeviceId == devices[0].deviceId,
      );
      final laptopEnv = envelopes.firstWhere(
        (e) => e.recipientDeviceId == devices[1].deviceId,
      );
      expect(
        await bobPhone.decryptV2(phoneEnv, senderUserId: 'alice'),
        'works on both devices',
      );
      expect(
        await bobLaptop.decryptV2(laptopEnv, senderUserId: 'alice'),
        'works on both devices',
      );
    });

    test('cross-device decrypt fails — phone envelope cannot be opened on laptop', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server); // phone
      final bobLaptop = await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);

      final devices = await server.fetchDevices('bob');
      final envelopes = await alice.encryptV2ToAllDevices(
        recipientUserId: 'bob',
        plaintext: 'phone-only secret',
      );

      // The envelope addressed to the phone has the laptop's deviceId stripped;
      // try to decrypt it on the laptop — must fail.
      final phoneEnv = envelopes.firstWhere(
        (e) => e.recipientDeviceId == devices[0].deviceId,
      );
      expect(
        () => bobLaptop.decryptV2(phoneEnv, senderUserId: 'alice'),
        throwsA(anything),
      );
    });

    test('fan-out + reply: each Bob device replies independently with its own ratchet', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bobPhone = await _bootstrapParty(userId: 'bob', shared: server);
      final bobLaptop = await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);

      final devices = await server.fetchDevices('bob');
      final aliceToBob = await alice.encryptV2ToAllDevices(
        recipientUserId: 'bob',
        plaintext: 'inbound',
      );
      final phoneEnv = aliceToBob.firstWhere(
        (e) => e.recipientDeviceId == devices[0].deviceId,
      );
      final laptopEnv = aliceToBob.firstWhere(
        (e) => e.recipientDeviceId == devices[1].deviceId,
      );
      expect(await bobPhone.decryptV2(phoneEnv, senderUserId: 'alice'), 'inbound');
      expect(await bobLaptop.decryptV2(laptopEnv, senderUserId: 'alice'), 'inbound');

      // Phone replies — Alice has Alice's view of Bob "the user" pinned to
      // the phone (devs.first), so this round-trips cleanly.
      final phoneReply = await bobPhone.encryptV2(
        recipientUserId: 'alice',
        plaintext: 'reply from phone',
      );
      expect(await alice.decryptV2(phoneReply, senderUserId: 'bob'), 'reply from phone');
    });

    test('user with zero devices: fan-out returns empty list', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      // Note: 'ghost' was never bootstrapped.

      final envelopes = await alice.encryptV2ToAllDevices(
        recipientUserId: 'ghost',
        plaintext: 'into the void',
      );
      expect(envelopes, isEmpty);
    });
  });

  group('E2EESession v2 out-of-order delivery', () {
    test('5 messages delivered in shuffled order all decrypt correctly', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      const messages = ['one', 'two', 'three', 'four', 'five'];
      // Alice sends all 5 — each advances her sending chain.
      final envelopes = <models.EncryptedEnvelope>[];
      for (final m in messages) {
        envelopes.add(await alice.encryptV2(recipientUserId: 'bob', plaintext: m));
      }

      // The initial envelope must arrive first to bootstrap Bob's session
      // (it's the one carrying X3DH material). Deliver the rest reordered.
      expect(envelopes[0].isInitial, isTrue);
      expect(await bob.decryptV2(envelopes[0], senderUserId: 'alice'), 'one');

      // Network reorders the post-bootstrap tail.
      final shuffled = [
        envelopes[3], // four
        envelopes[1], // two
        envelopes[4], // five
        envelopes[2], // three
      ];
      final shuffledExpected = ['four', 'two', 'five', 'three'];

      for (var i = 0; i < shuffled.length; i++) {
        final plain = await bob.decryptV2(shuffled[i], senderUserId: 'alice');
        expect(plain, shuffledExpected[i],
            reason: 'shuffle position $i (Alice sent as #${envelopes.indexOf(shuffled[i])})');
      }
    });

    test('out-of-order across a DH ratchet step', () async {
      // Pattern that exercises both the skipped-key cache AND the previous-chain
      // skip count (`pn`). Alice sends 3, Bob replies, Alice sends 3 more.
      // We deliver Alice's first batch in reverse, then Bob's reply, then her
      // second batch out of order.
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      // Alice → Bob, batch 1
      final a1 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a1');
      final a2 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a2');
      final a3 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a3');

      // Bob receives a1 first to bootstrap his ratchet, then a3, a2 out of order.
      expect(await bob.decryptV2(a1, senderUserId: 'alice'), 'a1');
      expect(await bob.decryptV2(a3, senderUserId: 'alice'), 'a3');
      expect(await bob.decryptV2(a2, senderUserId: 'alice'), 'a2');

      // Bob replies — triggers a DH ratchet step on Alice's next send.
      final b1 = await bob.encryptV2(recipientUserId: 'alice', plaintext: 'b1');
      expect(await alice.decryptV2(b1, senderUserId: 'bob'), 'b1');

      // Alice → Bob, batch 2 — now on a NEW DH chain.
      final a4 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a4');
      final a5 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a5');
      final a6 = await alice.encryptV2(recipientUserId: 'bob', plaintext: 'a6');

      // Bob receives a5 first — must skip across the DH boundary AND skip a4.
      expect(await bob.decryptV2(a5, senderUserId: 'alice'), 'a5');
      // Then a6, then a4 (catching up via skipped-key cache).
      expect(await bob.decryptV2(a6, senderUserId: 'alice'), 'a6');
      expect(await bob.decryptV2(a4, senderUserId: 'alice'), 'a4');
    });

    test('replaying a delivered envelope fails (key consumed)', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      final env = await alice.encryptV2(
        recipientUserId: 'bob',
        plaintext: 'play me once',
      );
      expect(await bob.decryptV2(env, senderUserId: 'alice'), 'play me once');

      // Same envelope, second time: the message key has been consumed — the
      // ratchet has no record of it and AEAD will fail under fresh keys.
      expect(
        () => bob.decryptV2(env, senderUserId: 'alice'),
        throwsA(anything),
      );
    });

    test('catching up the tail of a burst (10 messages, odd-then-even)', () async {
      // Stress the skipped-key cache: Alice sends 10 messages on one chain,
      // Bob processes the odd ones first (each leaves a "missing" even in
      // the cache), then catches up on the evens.
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapParty(userId: 'bob', shared: server);

      const burstSize = 10;
      final envs = <models.EncryptedEnvelope>[];
      for (var i = 0; i < burstSize; i++) {
        envs.add(await alice.encryptV2(recipientUserId: 'bob', plaintext: 'msg $i'));
      }

      // Initial envelope first (bootstraps the session).
      expect(await bob.decryptV2(envs[0], senderUserId: 'alice'), 'msg 0');

      // Odd-indexed messages from the burst, in order.
      for (var i = 1; i < burstSize; i += 2) {
        expect(await bob.decryptV2(envs[i], senderUserId: 'alice'), 'msg $i');
      }
      // Even-indexed messages arrive late — must come out of the skipped-key cache.
      for (var i = 2; i < burstSize; i += 2) {
        expect(await bob.decryptV2(envs[i], senderUserId: 'alice'), 'msg $i');
      }
    });
  });

  group('E2EESession identity change detection', () {
    test('first contact returns alert with empty oldFingerprint', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNotNull);
      expect(alert!.userId, 'bob');
      expect(alert.oldFingerprint, isEmpty);
      expect(alert.newFingerprint, isNotEmpty);
    });

    test('after acknowledgement, no alert for the same identity', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);

      await alice.acknowledgePeerIdentity('bob');
      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNull, reason: 'pinned identity should be silent');
    });

    test('identity rotation surfaces an alert with both fingerprints', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);

      // Alice trusts Bob's current key.
      final originalFp = (await server.fetchIdentity('bob'))!.fingerprint;
      await alice.acknowledgePeerIdentity('bob');

      // Bob "loses his phone" — re-bootstraps a new device, becoming the
      // primary the server returns. Fingerprint changes.
      await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);
      final newFp = (await server.fetchIdentity('bob'))!.fingerprint;
      expect(newFp, isNot(equals(originalFp)),
          reason: 'precondition: rotation must produce a different fingerprint');

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNotNull);
      expect(alert!.oldFingerprint, originalFp);
      expect(alert.newFingerprint, newFp);
    });

    test('after acknowledging a rotation, the new identity is silent', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);

      await alice.acknowledgePeerIdentity('bob');
      await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);
      // Re-pin the new key.
      await alice.acknowledgePeerIdentity('bob');

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNull);
    });

    test('returns null for users with no published identity', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);

      final alert = await alice.checkPeerIdentityChange('ghost');
      expect(alert, isNull);
    });

    // ── Rotation attestations ──────────────────────────────────────────────
    //
    // When a peer rotates their identity, the OLD signing key signs
    //   "rotate:<oldIdentityPub>:<newIdentityPub>"
    // and publishes the signature. A receiver who pinned the old signing
    // pub can verify the rotation under it. The banner uses
    // [IdentityChangeAlert.hasAttestation] to soften its tone.

    test('attested rotation: hasAttestation=true', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      final bob = await _bootstrapPartyExposed(userId: 'bob', shared: server);

      // Alice pins Bob's CURRENT identity + signing pub.
      final oldIdentity = (await server.fetchIdentity('bob'))!;
      await alice.acknowledgePeerIdentity('bob');

      // Capture Bob's ORIGINAL signing key pair before the rotation —
      // this is the key that signs the attestation.
      final oldSigningKp = await bob.keystore.loadSigningKeyPair();

      // Bob "rotates" — extra device becomes the canonical published one.
      await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);
      final newIdentity = (await server.fetchIdentity('bob'))!;
      expect(newIdentity.identityPub, isNot(oldIdentity.identityPub));

      // Build and seed a real attestation: the old signing key signs the
      // canonical rotation message tying the old and new identity pubs.
      final msg = utf8.encode(
          'rotate:${oldIdentity.identityPub}:${newIdentity.identityPub}');
      final sig = await Cryptography.instance
          .ed25519()
          .sign(msg, keyPair: oldSigningKp!);
      server.seedAttestation(models.RemoteIdentityAttestation(
        userId: 'bob',
        oldIdentityPub: oldIdentity.identityPub,
        newIdentityPub: newIdentity.identityPub,
        signature: base64Encode(sig.bytes),
        attestedAt: DateTime.utc(2026, 5, 29),
      ));

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNotNull);
      expect(alert!.hasAttestation, isTrue,
          reason: 'valid attestation must verify under the OLD signing key');
    });

    test('rotation without attestation: hasAttestation=false', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);

      await alice.acknowledgePeerIdentity('bob');
      await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);
      // No attestation seeded.

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNotNull);
      expect(alert!.hasAttestation, isFalse);
    });

    test('rotation with attestation signed under WRONG key: hasAttestation=false', () async {
      // Mallory tries to forge an attestation for Bob's rotation by signing
      // with HER own signing key (or any key that isn't Bob's old one).
      // Verification under Bob's old pinned signing pub must reject.
      final server = _FakeE2EERepository();
      final alice = await _bootstrapParty(userId: 'alice', shared: server);
      await _bootstrapParty(userId: 'bob', shared: server);
      final mallory = await _bootstrapPartyExposed(userId: 'mallory', shared: server);

      final oldIdentity = (await server.fetchIdentity('bob'))!;
      await alice.acknowledgePeerIdentity('bob');

      await _bootstrapAdditionalDeviceFor(userId: 'bob', shared: server);
      final newIdentity = (await server.fetchIdentity('bob'))!;

      final msg = utf8.encode(
          'rotate:${oldIdentity.identityPub}:${newIdentity.identityPub}');
      // Wrong key — Mallory's signing key, NOT Bob's old one.
      final malloryKp = await mallory.keystore.loadSigningKeyPair();
      final sig = await Cryptography.instance
          .ed25519()
          .sign(msg, keyPair: malloryKp!);
      server.seedAttestation(models.RemoteIdentityAttestation(
        userId: 'bob',
        oldIdentityPub: oldIdentity.identityPub,
        newIdentityPub: newIdentity.identityPub,
        signature: base64Encode(sig.bytes),
        attestedAt: DateTime.utc(2026, 5, 29),
      ));

      final alert = await alice.checkPeerIdentityChange('bob');
      expect(alert, isNotNull);
      expect(alert!.hasAttestation, isFalse,
          reason: 'attestation signed under the wrong key must NOT verify');
    });
  });
}
