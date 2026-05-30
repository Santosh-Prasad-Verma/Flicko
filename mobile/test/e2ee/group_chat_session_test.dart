/// End-to-end tests for [GroupChatSession]: sender-key distribution +
/// group broadcast across 3 real parties (Alice, Bob, Carol).
///
/// Each party owns:
///   - A [SecureKeystore] backed by a fake secure-storage map.
///   - A [RatchetWalStore] backed by a unique temp-file SQLite db.
///   - An [E2EESession] for per-pair encryption.
///   - A [GroupChatSession] layered on top, sharing the keystore.
///
/// The "transport" between parties is just direct method calls — we don't
/// model the DM repo or wire envelopes; that's covered by the v2 round-trip
/// tests already.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/features/e2ee/application/e2ee_session.dart';
import '../../lib/features/e2ee/application/group_chat_session.dart';
import '../../lib/features/e2ee/data/e2ee_repository.dart';
import '../../lib/features/e2ee/data/ratchet_wal_store.dart';
import '../../lib/features/e2ee/data/secure_keystore.dart';
import '../../lib/features/e2ee/domain/e2ee_models.dart' as models;

// ── Fakes (mirror those in e2ee_session_v2_test.dart) ────────────────────────

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

class _FakeE2EERepository implements E2EERepository {
  final Map<String, List<models.IdentityKey>> _devicesByUser = {};
  final Map<String, models.SignedPrekey> _spkByDevice = {};
  final Map<String, List<models.OneTimePrekey>> _otksByDevice = {};
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
    if (deviceId == null) return devs.last;
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

  @override
  Future<models.RemoteIdentityAttestation?> fetchAttestation({
    required String userId,
    required String newIdentityPub,
  }) async => null;

  @override
  Future<void> publishAttestation({
    required String oldIdentityPub,
    required String newIdentityPub,
    required String signatureB64,
  }) async {}
}

Future<({RatchetWalStore store, Database db})> _newWal() async {
  final dir = await Directory.systemTemp.createTemp('flicko_wal_grp_');
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}/ratchet.db',
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
  return (store: RatchetWalStore(storage: _FakeSecureStorage(), db: db), db: db);
}

class _Party {
  final String userId;
  final SecureKeystore keystore;
  final E2EESession session;
  final GroupChatSession group;
  _Party(this.userId, this.keystore, this.session, this.group);
}

Future<_Party> _bootstrap({
  required String userId,
  required _FakeE2EERepository server,
}) async {
  final keystore = SecureKeystore(storage: _FakeSecureStorage());
  final wal = await _newWal();
  final session = E2EESession(keystore, server, wal.store);
  await session.ensureBootstrapped();
  final deviceId = await keystore.getOrCreateDeviceId();
  server.bindPendingTo(userId, deviceId);
  return _Party(userId, keystore, session, GroupChatSession(session, keystore));
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('GroupChatSession 3-party flow', () {
    test('Alice distributes her sender key, then sends; Bob and Carol both decrypt', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final bob = await _bootstrap(userId: 'bob', server: server);
      final carol = await _bootstrap(userId: 'carol', server: server);

      const groupId = 'group:friends';

      // Alice publishes her sender key for the group.
      final distribution =
          await alice.group.buildSenderKeyDistributionPayload(groupId);

      // Distribution carried via the per-pair ratchet to each member.
      final toBob = await alice.session
          .encryptV2(recipientUserId: 'bob', plaintext: distribution);
      final toCarol = await alice.session
          .encryptV2(recipientUserId: 'carol', plaintext: distribution);

      // Bob and Carol decrypt the per-pair envelope...
      final bobPlain =
          await bob.session.decryptV2(toBob, senderUserId: 'alice');
      final carolPlain =
          await carol.session.decryptV2(toCarol, senderUserId: 'alice');

      // ...and pass the plaintext to their group session, which recognises
      // it as a sender-key distribution and caches it.
      expect(
        await bob.group
            .tryAcceptControlPayload(senderUserId: 'alice', plaintext: bobPlain),
        isTrue,
      );
      expect(
        await carol.group
            .tryAcceptControlPayload(senderUserId: 'alice', plaintext: carolPlain),
        isTrue,
      );

      // Alice sends a group message — ONE envelope, two readers.
      final env = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('hello team'.codeUnits),
      );
      expect(env.groupId, groupId);

      final bobOut = await bob.group
          .receiveGroupMessage(envelope: env, senderUserId: 'alice');
      final carolOut = await carol.group
          .receiveGroupMessage(envelope: env, senderUserId: 'alice');

      expect(String.fromCharCodes(bobOut), 'hello team');
      expect(String.fromCharCodes(carolOut), 'hello team');
    });

    test('multiple group messages from one sender stay in lockstep', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final bob = await _bootstrap(userId: 'bob', server: server);

      const groupId = 'g';
      final distribution =
          await alice.group.buildSenderKeyDistributionPayload(groupId);
      final wrap = await alice.session
          .encryptV2(recipientUserId: 'bob', plaintext: distribution);
      final plain = await bob.session.decryptV2(wrap, senderUserId: 'alice');
      await bob.group
          .tryAcceptControlPayload(senderUserId: 'alice', plaintext: plain);

      const messages = ['m1', 'm2', 'm3', 'm4', 'm5'];
      for (final m in messages) {
        final env = await alice.group.sendGroupMessage(
          groupId: groupId,
          plaintext: Uint8List.fromList(m.codeUnits),
        );
        final out = await bob.group
            .receiveGroupMessage(envelope: env, senderUserId: 'alice');
        expect(String.fromCharCodes(out), m);
      }
    });

    test('receiving without prior distribution throws (caller must request resend)', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final bob = await _bootstrap(userId: 'bob', server: server);

      const groupId = 'g';
      // Alice sends a group message but Bob never received the distribution.
      final env = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('orphan'.codeUnits),
      );

      expect(
        () => bob.group.receiveGroupMessage(envelope: env, senderUserId: 'alice'),
        throwsA(isA<StateError>()),
      );
    });

    test('non-control payloads are ignored by tryAcceptControlPayload', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);

      // A regular DM string, not JSON.
      expect(
        await alice.group.tryAcceptControlPayload(
          senderUserId: 'bob',
          plaintext: 'just a normal hello',
        ),
        isFalse,
      );

      // JSON without the right kind.
      expect(
        await alice.group.tryAcceptControlPayload(
          senderUserId: 'bob',
          plaintext: '{"kind":"unrelated","payload":{}}',
        ),
        isFalse,
      );
    });

    test('sender key persists across new GroupChatSession instance for the same device', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final bob = await _bootstrap(userId: 'bob', server: server);

      const groupId = 'g';
      final dist =
          await alice.group.buildSenderKeyDistributionPayload(groupId);
      final wrap = await alice.session
          .encryptV2(recipientUserId: 'bob', plaintext: dist);
      final plain = await bob.session.decryptV2(wrap, senderUserId: 'alice');
      await bob.group
          .tryAcceptControlPayload(senderUserId: 'alice', plaintext: plain);

      // First message via the original session.
      final env1 = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('first'.codeUnits),
      );
      expect(
        String.fromCharCodes(await bob.group
            .receiveGroupMessage(envelope: env1, senderUserId: 'alice')),
        'first',
      );

      // Simulate app restart for Alice: brand-new GroupChatSession, same
      // E2EESession and keystore. Her own sender key MUST come back from
      // disk so the chain doesn't reset to 0.
      final aliceGroup2 = GroupChatSession(alice.session, alice.keystore);
      final env2 = await aliceGroup2.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('second'.codeUnits),
      );
      expect(env2.chainId, env1.chainId + 1,
          reason: "own sender key didn't persist across sessions");
      expect(
        String.fromCharCodes(await bob.group
            .receiveGroupMessage(envelope: env2, senderUserId: 'alice')),
        'second',
      );
    });

    test('rotateOwnSenderKey: post-rotation chain restarts; pre-rotation envelopes still readable with old peer key', () async {
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final bob = await _bootstrap(userId: 'bob', server: server);

      const groupId = 'g';

      // Initial distribution + one message.
      final dist1 =
          await alice.group.buildSenderKeyDistributionPayload(groupId);
      final w1 = await alice.session
          .encryptV2(recipientUserId: 'bob', plaintext: dist1);
      final p1 = await bob.session.decryptV2(w1, senderUserId: 'alice');
      await bob.group
          .tryAcceptControlPayload(senderUserId: 'alice', plaintext: p1);

      final pre = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('pre'.codeUnits),
      );
      expect(pre.chainId, 1);
      expect(
        String.fromCharCodes(await bob.group
            .receiveGroupMessage(envelope: pre, senderUserId: 'alice')),
        'pre',
      );

      // Alice rotates and re-distributes (e.g. a member just left).
      await alice.group.rotateOwnSenderKey(groupId);
      final dist2 =
          await alice.group.buildSenderKeyDistributionPayload(groupId);
      final w2 = await alice.session
          .encryptV2(recipientUserId: 'bob', plaintext: dist2);
      final p2 = await bob.session.decryptV2(w2, senderUserId: 'alice');
      await bob.group
          .tryAcceptControlPayload(senderUserId: 'alice', plaintext: p2);

      final post = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('post'.codeUnits),
      );
      // The chain restarted on rotation.
      expect(post.chainId, 1);
      expect(
        String.fromCharCodes(await bob.group
            .receiveGroupMessage(envelope: post, senderUserId: 'alice')),
        'post',
      );
    });

    test('rotateOwnSenderKey: post-rotation envelopes do NOT decrypt under the OLD peer key', () async {
      // Models the scenario where a removed member (Mallory) keeps a copy
      // of Alice's pre-rotation sender key. After Alice rotates, Mallory's
      // cached key is now stale: any message Alice sends post-rotation MUST
      // fail under the old key (chain mismatch) — that's the security
      // property that makes rotation meaningful.
      final server = _FakeE2EERepository();
      final alice = await _bootstrap(userId: 'alice', server: server);
      final mallory = await _bootstrap(userId: 'mallory', server: server);

      const groupId = 'g';
      final dist =
          await alice.group.buildSenderKeyDistributionPayload(groupId);
      final wrap = await alice.session
          .encryptV2(recipientUserId: 'mallory', plaintext: dist);
      final p = await mallory.session.decryptV2(wrap, senderUserId: 'alice');
      await mallory.group
          .tryAcceptControlPayload(senderUserId: 'alice', plaintext: p);

      // Alice rotates BUT does NOT redistribute to Mallory (she's been removed).
      await alice.group.rotateOwnSenderKey(groupId);
      final post = await alice.group.sendGroupMessage(
        groupId: groupId,
        plaintext: Uint8List.fromList('locked-out'.codeUnits),
      );

      expect(
        () => mallory.group.receiveGroupMessage(envelope: post, senderUserId: 'alice'),
        throwsA(anything),
        reason: 'Mallory cached the old key; the new envelope must not open',
      );
    });
  });
}
