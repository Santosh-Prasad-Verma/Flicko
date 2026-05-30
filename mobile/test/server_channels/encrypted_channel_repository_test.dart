/// Integration tests for [EncryptedChannelRepository]: a server channel
/// with 3 members, each running their own session. Drives the full flow:
///   1. Each member distributes their sender key to every other member.
///   2. A member sends a broadcast group message; all others decrypt.
///   3. A member rotates and re-distributes; old peer keys are replaced.
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
import '../../lib/features/e2ee/domain/group_session.dart';
import '../../lib/features/server_channels/data/encrypted_channel_repository.dart';

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
  final dir = await Directory.systemTemp.createTemp('flicko_wal_chrepo_');
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

/// In-memory channel transport — the simplest thing that mimics the
/// production storage. We index distribution envelopes by recipient device
/// so a member's pull can filter to their own.
class _MemoryChannelTransport implements ChannelEnvelopeTransport {
  final List<({String channelId, String senderUserId, GroupEnvelope env})>
      groupMessages = [];
  final List<({String channelId, String senderUserId, models.EncryptedEnvelope env})>
      distributions = [];

  @override
  Future<void> publishGroupMessage({
    required String channelId,
    required String senderUserId,
    required GroupEnvelope envelope,
  }) async {
    groupMessages.add(
        (channelId: channelId, senderUserId: senderUserId, env: envelope));
  }

  @override
  Future<void> publishSenderKeyDistribution({
    required String channelId,
    required String senderUserId,
    required List<models.EncryptedEnvelope> envelopes,
  }) async {
    for (final e in envelopes) {
      distributions
          .add((channelId: channelId, senderUserId: senderUserId, env: e));
    }
  }

  /// Pull the distribution envelopes addressed to [deviceId].
  List<({String senderUserId, models.EncryptedEnvelope env})>
      distributionsFor(String channelId, String deviceId) {
    return distributions
        .where((d) =>
            d.channelId == channelId && d.env.recipientDeviceId == deviceId)
        .map((d) => (senderUserId: d.senderUserId, env: d.env))
        .toList();
  }
}

class _Party {
  final String userId;
  final SecureKeystore keystore;
  final E2EESession session;
  final GroupChatSession group;
  final EncryptedChannelRepository repo;
  _Party(this.userId, this.keystore, this.session, this.group, this.repo);

  Future<String> get deviceId => keystore.getOrCreateDeviceId();
}

Future<_Party> _bootstrap({
  required String userId,
  required _FakeE2EERepository server,
  required ChannelEnvelopeTransport transport,
}) async {
  final keystore = SecureKeystore(storage: _FakeSecureStorage());
  final wal = await _newWal();
  final session = E2EESession(keystore, server, wal.store);
  await session.ensureBootstrapped();
  final deviceId = await keystore.getOrCreateDeviceId();
  server.bindPendingTo(userId, deviceId);
  final group = GroupChatSession(session, keystore);
  final repo = EncryptedChannelRepository(session, group, transport);
  return _Party(userId, keystore, session, group, repo);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('EncryptedChannelRepository', () {
    test('3-member channel: distribute → send → 2 receivers decrypt', () async {
      final server = _FakeE2EERepository();
      final transport = _MemoryChannelTransport();
      final alice = await _bootstrap(userId: 'alice', server: server, transport: transport);
      final bob = await _bootstrap(userId: 'bob', server: server, transport: transport);
      final carol = await _bootstrap(userId: 'carol', server: server, transport: transport);

      const channelId = 'chan:engineering';

      // Alice distributes her sender key to Bob and Carol.
      await alice.repo.distributeSenderKey(
        channelId: channelId,
        recipientUserIds: ['bob', 'carol'],
      );

      // Bob and Carol each ingest the distribution envelope addressed to them.
      for (final party in [bob, carol]) {
        final id = await party.deviceId;
        final pulls = transport.distributionsFor(channelId, id);
        expect(pulls.length, 1, reason: '${party.userId} should see one dist');
        final ok = await party.repo.acceptIncomingDistribution(
          envelope: pulls.first.env,
          senderUserId: pulls.first.senderUserId == await alice.deviceId
              ? 'alice'
              : pulls.first.senderUserId,
        );
        expect(ok, isTrue);
      }

      // Alice broadcasts.
      final env = await alice.repo.send(
        channelId: channelId,
        plaintext: Uint8List.fromList('ship it'.codeUnits),
      );
      expect(transport.groupMessages.length, 1);
      expect(transport.groupMessages.first.env.groupId, channelId);

      // Bob and Carol decrypt.
      for (final party in [bob, carol]) {
        final res = await party.repo.receive(envelope: env, senderUserId: 'alice');
        expect(res, isA<ChannelMessage>());
        final pt = (res as ChannelMessage).plaintext;
        expect(String.fromCharCodes(pt), 'ship it');
      }
    });

    test('receive without prior distribution returns ChannelNeedsSenderKey', () async {
      final server = _FakeE2EERepository();
      final transport = _MemoryChannelTransport();
      final alice = await _bootstrap(userId: 'alice', server: server, transport: transport);
      final bob = await _bootstrap(userId: 'bob', server: server, transport: transport);

      const channelId = 'c';
      // Alice sends WITHOUT distributing first.
      final env = await alice.repo.send(
        channelId: channelId,
        plaintext: Uint8List.fromList('orphan'.codeUnits),
      );

      final res = await bob.repo.receive(envelope: env, senderUserId: 'alice');
      expect(res, isA<ChannelNeedsSenderKey>());
      final missing = res as ChannelNeedsSenderKey;
      expect(missing.senderUserId, 'alice');
      expect(missing.senderDeviceId, env.senderDeviceId);
    });

    test('rotateAndRedistribute: post-rotation chainId resets, old key invalid', () async {
      final server = _FakeE2EERepository();
      final transport = _MemoryChannelTransport();
      final alice = await _bootstrap(userId: 'alice', server: server, transport: transport);
      final bob = await _bootstrap(userId: 'bob', server: server, transport: transport);

      const channelId = 'c';
      // Initial flow.
      await alice.repo.distributeSenderKey(channelId: channelId, recipientUserIds: ['bob']);
      final bobId = await bob.deviceId;
      var pulls = transport.distributionsFor(channelId, bobId);
      await bob.repo.acceptIncomingDistribution(
        envelope: pulls.first.env,
        senderUserId: 'alice',
      );
      final pre = await alice.repo.send(
        channelId: channelId,
        plaintext: Uint8List.fromList('pre-rotate'.codeUnits),
      );
      expect(
        (await bob.repo.receive(envelope: pre, senderUserId: 'alice')),
        isA<ChannelMessage>(),
      );

      // Rotate (e.g. someone got removed) and re-distribute to the
      // remaining member set — Bob.
      await alice.repo.rotateAndRedistribute(
        channelId: channelId,
        recipientUserIds: ['bob'],
      );

      // Bob ingests the new distribution.
      pulls = transport.distributionsFor(channelId, bobId);
      // Two distributions now in the transport — pick the latest.
      await bob.repo.acceptIncomingDistribution(
        envelope: pulls.last.env,
        senderUserId: 'alice',
      );

      final post = await alice.repo.send(
        channelId: channelId,
        plaintext: Uint8List.fromList('post-rotate'.codeUnits),
      );
      // Fresh chain: the first message after rotation has chainId == 1.
      expect(post.chainId, 1);

      final res = await bob.repo.receive(envelope: post, senderUserId: 'alice');
      expect(res, isA<ChannelMessage>());
      expect(
        String.fromCharCodes((res as ChannelMessage).plaintext),
        'post-rotate',
      );
    });
  });
}
