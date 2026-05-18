/// Encrypted WAL-based ratchet state persistence (Task 11).
///
/// Uses an append-only write-ahead log pattern so that a crash during
/// a ratchet step never leaves the conversation in a bricked state.
/// Each log entry stores a full snapshot of the [RatchetState] using SQLCipher.
///
/// On startup the WAL is compacted or older entries are GC'd.
///
/// References:
///   design.md §4.4 (Crash-safe ratchet persistence)
///   requirements.md R6
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as p;

import '../domain/ratchet.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// Namespace for the local master encryption key.
const String _walMasterKey = 'flicko.e2ee.wal.master';

/// Maximum WAL entries per conversation before compaction.
const int kWalCompactThreshold = 10;

// ── WAL Entry ────────────────────────────────────────────────────────────────

/// A single WAL entry containing a ratchet state snapshot.
class WalEntry {
  /// Monotonically increasing sequence number per conversation.
  final int seqNo;

  /// Conversation ID (deterministic hash of the two user IDs).
  final String conversationId;

  /// JSON of the ratchet state.
  final String snapshotJson;
  
  /// The hash of the previous entry in the chain.
  final String prevHash;

  /// Hash of this entry: sha256(snapshot_json + prev_hash)
  final String entryHash;

  /// Timestamp of when this entry was written.
  final DateTime writtenAt;

  const WalEntry({
    required this.seqNo,
    required this.conversationId,
    required this.snapshotJson,
    required this.prevHash,
    required this.entryHash,
    required this.writtenAt,
  });

  Map<String, dynamic> toMap() => {
        'seq_no': seqNo,
        'conversation_id': conversationId,
        'snapshot_json': snapshotJson,
        'prev_hash': prevHash,
        'entry_hash': entryHash,
        'written_at': writtenAt.millisecondsSinceEpoch,
      };

  factory WalEntry.fromMap(Map<String, dynamic> j) => WalEntry(
        seqNo: (j['seq_no'] as num).toInt(),
        conversationId: j['conversation_id'] as String,
        snapshotJson: j['snapshot_json'] as String,
        prevHash: j['prev_hash'] as String,
        entryHash: j['entry_hash'] as String,
        writtenAt: DateTime.fromMillisecondsSinceEpoch((j['written_at'] as num).toInt()),
      );
}

// ── Serializable Ratchet Snapshot ─────────────────────────────────────────

/// JSON-serializable snapshot of a [RatchetState] for WAL persistence.
/// Private key bytes are included (encrypted at rest) because the WAL
/// must be able to fully reconstruct the state after a crash.
class RatchetSnapshot {
  final Uint8List dhsPriv;
  final Uint8List dhsPub;
  final Uint8List? dhrPub;
  final Uint8List rk;
  final Uint8List? cks;
  final Uint8List? ckr;
  final int ns;
  final int nr;
  final int pn;
  final Map<String, Uint8List> skippedEncoded;

  const RatchetSnapshot({
    required this.dhsPriv,
    required this.dhsPub,
    required this.dhrPub,
    required this.rk,
    required this.cks,
    required this.ckr,
    required this.ns,
    required this.nr,
    required this.pn,
    required this.skippedEncoded,
  });

  /// Serialize the ratchet state into a snapshot.
  static Future<RatchetSnapshot> fromState(RatchetState state) async {
    final priv = await state.dhs.extractPrivateKeyBytes();
    final pub = await state.dhs.extractPublicKey();

    final skipped = <String, Uint8List>{};
    for (final entry in state.skipped.entries) {
      final key = '${entry.key.dhPubB64}:${entry.key.n}';
      skipped[key] = entry.value;
    }

    return RatchetSnapshot(
      dhsPriv: Uint8List.fromList(priv),
      dhsPub: Uint8List.fromList(pub.bytes),
      dhrPub: state.dhrPub,
      rk: state.rk,
      cks: state.cks,
      ckr: state.ckr,
      ns: state.ns,
      nr: state.nr,
      pn: state.pn,
      skippedEncoded: skipped,
    );
  }

  /// Reconstruct a [RatchetState] from this snapshot.
  RatchetState toState() {
    final keyPair = SimpleKeyPairData(
      dhsPriv,
      publicKey: SimplePublicKey(dhsPub, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    final skipped = <SkippedKeyId, Uint8List>{};
    for (final entry in skippedEncoded.entries) {
      final parts = entry.key.split(':');
      if (parts.length == 2) {
        final id = SkippedKeyId(parts[0], int.parse(parts[1]));
        skipped[id] = entry.value;
      }
    }

    return RatchetState(
      dhs: keyPair,
      dhrPub: dhrPub,
      rk: rk,
      cks: cks,
      ckr: ckr,
      ns: ns,
      nr: nr,
      pn: pn,
      skipped: skipped,
    );
  }

  Map<String, dynamic> toJson() => {
        'dhs_priv': base64Encode(dhsPriv),
        'dhs_pub': base64Encode(dhsPub),
        'dhr_pub': dhrPub != null ? base64Encode(dhrPub!) : null,
        'rk': base64Encode(rk),
        'cks': cks != null ? base64Encode(cks!) : null,
        'ckr': ckr != null ? base64Encode(ckr!) : null,
        'ns': ns,
        'nr': nr,
        'pn': pn,
        'skipped': skippedEncoded.map(
            (k, v) => MapEntry(k, base64Encode(v))),
      };

  factory RatchetSnapshot.fromJson(Map<String, dynamic> j) {
    final skipped = <String, Uint8List>{};
    final raw = j['skipped'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      skipped[e.key] = Uint8List.fromList(base64Decode(e.value as String));
    }
    return RatchetSnapshot(
      dhsPriv: Uint8List.fromList(base64Decode(j['dhs_priv'] as String)),
      dhsPub: Uint8List.fromList(base64Decode(j['dhs_pub'] as String)),
      dhrPub: j['dhr_pub'] != null
          ? Uint8List.fromList(base64Decode(j['dhr_pub'] as String))
          : null,
      rk: Uint8List.fromList(base64Decode(j['rk'] as String)),
      cks: j['cks'] != null
          ? Uint8List.fromList(base64Decode(j['cks'] as String))
          : null,
      ckr: j['ckr'] != null
          ? Uint8List.fromList(base64Decode(j['ckr'] as String))
          : null,
      ns: (j['ns'] as num).toInt(),
      nr: (j['nr'] as num).toInt(),
      pn: (j['pn'] as num).toInt(),
      skippedEncoded: skipped,
    );
  }
}

// ── Ratchet WAL Store ────────────────────────────────────────────────────────

/// Encrypted WAL-based persistence for Double Ratchet sessions using SQLCipher.
///
/// Each write appends a new entry; reads replay the latest valid entry.
/// Hash chains ensure sequential integrity.
class RatchetWalStore {
  final FlutterSecureStorage _storage;
  Database? _db;

  RatchetWalStore({FlutterSecureStorage? storage, Database? db})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
            ),
        _db = db;

  /// Generate or retrieve the local WAL master key (32 bytes).
  Future<String> _getMasterKey() async {
    final existing = await _storage.read(key: _walMasterKey);
    if (existing != null && existing.isNotEmpty) {
      return existing; // Base64 encoded key
    }
    final key = SecretKeyData.random(length: 32);
    final bytes = await key.extractBytes();
    final b64 = base64Encode(bytes);
    await _storage.write(key: _walMasterKey, value: b64);
    return b64;
  }

  /// Initialize the SQLCipher database
  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = p.join(await getDatabasesPath(), 'ratchet_wal.db');
    final mk = await _getMasterKey();
    
    _db = await openDatabase(
      dbPath,
      password: mk,
      version: 1,
      onCreate: (db, version) async {
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
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
    return _db!;
  }

  /// Append a ratchet state snapshot to the WAL for [conversationId].
  ///
  /// This is the atomic write that ensures crash safety (R6.1, R6.2).
  Future<void> append(String conversationId, RatchetState state) async {
    final db = await _getDb();
    final snapshot = await RatchetSnapshot.fromState(state);
    final plainJson = jsonEncode(snapshot.toJson());
    
    await db.transaction((txn) async {
      // Get the last entry to chain hashes
      final maps = await txn.query(
        'ratchet_wal',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'seq_no DESC',
        limit: 1,
      );
      
      int nextSeq = 0;
      String prevHash = '';
      if (maps.isNotEmpty) {
        final lastEntry = WalEntry.fromMap(maps.first);
        nextSeq = lastEntry.seqNo + 1;
        prevHash = lastEntry.entryHash;
      }
      
      final entryHash = sha256.convert(utf8.encode('$plainJson|$prevHash')).toString();
      
      final entry = WalEntry(
        seqNo: nextSeq,
        conversationId: conversationId,
        snapshotJson: plainJson,
        prevHash: prevHash,
        entryHash: entryHash,
        writtenAt: DateTime.now().toUtc(),
      );
      
      await txn.insert('ratchet_wal', entry.toMap());
    });
    
    // Fire and forget compaction/GC
    _gc(conversationId);
  }

  /// Recover the latest valid ratchet state for [conversationId].
  ///
  /// Returns null if no state has been persisted (new conversation).
  Future<RatchetState?> recover(String conversationId) async {
    final db = await _getDb();
    final maps = await db.query(
      'ratchet_wal',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'seq_no ASC', // read chronologically to verify hashes
    );
    
    if (maps.isEmpty) return null;
    
    String expectedPrevHash = '';
    RatchetState? lastValidState;
    int lastValidId = -1;
    
    for (final map in maps) {
      final entry = WalEntry.fromMap(map);
      
      // Hash chain verification (Task 11.3)
      if (entry.prevHash != expectedPrevHash) {
        // Rollback mismatch
        break;
      }
      
      final computedHash = sha256.convert(utf8.encode('${entry.snapshotJson}|${entry.prevHash}')).toString();
      if (computedHash != entry.entryHash) {
        // Corrupted entry hash
        break;
      }
      
      try {
        final j = jsonDecode(entry.snapshotJson) as Map<String, dynamic>;
        lastValidState = RatchetSnapshot.fromJson(j).toState();
        lastValidId = map['id'] as int;
        expectedPrevHash = entry.entryHash;
      } catch (_) {
        // Corrupted JSON
        break;
      }
    }
    
    // If we aborted early due to a corruption, rollback (delete invalid tail entries)
    if (lastValidId != -1 && lastValidId < (maps.last['id'] as int)) {
      await db.delete(
        'ratchet_wal',
        where: 'conversation_id = ? AND id > ?',
        whereArgs: [conversationId, lastValidId],
      );
    } else if (lastValidId == -1 && maps.isNotEmpty) {
      // The very first entry is corrupted, wipe everything
      await deleteConversation(conversationId);
      return null;
    }
    
    return lastValidState;
  }

  /// GC entries older than 7 days (Task 11.4) or beyond compaction threshold
  Future<void> _gc(String conversationId) async {
    final db = await _getDb();
    final sevenDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    
    await db.transaction((txn) async {
      // Keep at least the latest 10 (kWalCompactThreshold)
      final maps = await txn.query(
        'ratchet_wal',
        columns: ['id'],
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'seq_no DESC',
        limit: 1,
        offset: kWalCompactThreshold,
      );
      
      if (maps.isNotEmpty) {
        final thresholdId = maps.first['id'] as int;
        await txn.delete(
          'ratchet_wal',
          where: 'conversation_id = ? AND (id <= ? OR written_at < ?)',
          whereArgs: [conversationId, thresholdId, sevenDaysAgo],
        );
      }
    });
  }

  /// Delete all WAL entries for a conversation (key reset, wipe).
  Future<void> deleteConversation(String conversationId) async {
    final db = await _getDb();
    await db.delete(
      'ratchet_wal',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Delete all WAL data (full wipe).
  Future<void> wipeAll() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final dbPath = p.join(await getDatabasesPath(), 'ratchet_wal.db');
    await deleteDatabase(dbPath);
    await _storage.delete(key: _walMasterKey);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final ratchetWalStoreProvider = Provider<RatchetWalStore>((_) => RatchetWalStore());
