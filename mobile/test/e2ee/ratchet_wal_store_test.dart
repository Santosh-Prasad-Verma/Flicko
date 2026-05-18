import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart' as p;

// We need to import the app's files
// Assuming the package name is flicko or mobile? Let's use relative imports.
import '../../lib/features/e2ee/data/ratchet_wal_store.dart';
import '../../lib/features/e2ee/domain/ratchet.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  FakeSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

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
      _data.remove(key);
    } else {
      _data[key] = value;
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
    _data.remove(key);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late RatchetWalStore store;
  late FakeSecureStorage fakeStorage;
  late Database testDb;

  setUp(() async {
    fakeStorage = FakeSecureStorage();
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
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
    ));
    store = RatchetWalStore(storage: fakeStorage, db: testDb);
    await testDb.execute('DELETE FROM ratchet_wal');
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<RatchetState> _createDummyState(int ns) async {
    final dhs = await Cryptography.instance.x25519().newKeyPair();
    return RatchetState(
      dhs: dhs,
      dhrPub: Uint8List(32),
      rk: Uint8List(32),
      cks: Uint8List(32),
      ckr: Uint8List(32),
      ns: ns,
      nr: 1,
      pn: 1,
    );
  }

  Database _openRawDb() {
    return testDb;
  }

  test('corrupt WAL entry triggers rollback rather than panic (11.6)', () async {
    final state1 = await _createDummyState(1);
    final state2 = await _createDummyState(2);
    final state3 = await _createDummyState(3);

    const convId = 'conv_123';
    
    await store.append(convId, state1);
    await store.append(convId, state2);
    await store.append(convId, state3);

    // Verify it recovers to state3 normally
    final recovered1 = await store.recover(convId);
    expect(recovered1, isNotNull);
    expect(recovered1!.ns, 3);

    // Now corrupt the second entry's JSON
    final db = _openRawDb();
    await db.execute("UPDATE ratchet_wal SET snapshot_json = 'INVALID_JSON' WHERE seq_no = 1");

    // Recover should now roll back state2 and state3, leaving us at state1
    final recovered2 = await store.recover(convId);
    expect(recovered2, isNotNull);
    expect(recovered2!.ns, 1);

    // Verify the DB actually deleted the corrupted and subsequent entries
    final dbCheck = _openRawDb();
    final count = sqlcipher.Sqflite.firstIntValue(await dbCheck.rawQuery("SELECT COUNT(*) FROM ratchet_wal WHERE conversation_id = '$convId'"));
    expect(count, 1);
  });

  test('PBT: random crash injection leaves state recoverable to last sane checkpoint (11.5)', () async {
    final rand = Random(42);
    
    for (int iter = 0; iter < 10; iter++) {
      await testDb.execute('DELETE FROM ratchet_wal');
      const convId = 'conv_pbt';
      
      final states = <RatchetState>[];
      for (int i = 0; i < 5; i++) {
        final state = await _createDummyState(i);
        states.add(state);
        await store.append(convId, state);
      }
      
      // Inject random corruption
      // 0: Missing entry (simulated by deleting an entry)
      // 1: Corrupt JSON
      // 2: Corrupt prev_hash
      // 3: Corrupt entry_hash
      final corruptionType = rand.nextInt(4);
      final corruptIndex = rand.nextInt(4) + 1; // Corrupt seq_no 1, 2, 3, or 4 (leave 0 alone to have a valid baseline)
      
      final db = _openRawDb();
      switch (corruptionType) {
        case 0:
          await db.execute("DELETE FROM ratchet_wal WHERE conversation_id = '$convId' AND seq_no = $corruptIndex");
          break;
        case 1:
          await db.execute("UPDATE ratchet_wal SET snapshot_json = '{bad}' WHERE conversation_id = '$convId' AND seq_no = $corruptIndex");
          break;
        case 2:
          await db.execute("UPDATE ratchet_wal SET prev_hash = 'badhash' WHERE conversation_id = '$convId' AND seq_no = $corruptIndex");
          break;
        case 3:
          await db.execute("UPDATE ratchet_wal SET entry_hash = 'badhash' WHERE conversation_id = '$convId' AND seq_no = $corruptIndex");
          break;
      }
      
      // Recover and expect it to yield state at (corruptIndex - 1) because seq_no starts at 0
      final recovered = await store.recover(convId);
      if (recovered == null) {
        final dump = await _openRawDb().query('ratchet_wal');
        print('FAILED on iter=$iter, type=$corruptionType, index=$corruptIndex. DB state: $dump');
      }
      expect(recovered, isNotNull);
      expect(recovered!.ns, states[corruptIndex - 1].ns, reason: 'Failed on iteration $iter, type $corruptionType, seq $corruptIndex');
      
      // Verify db is rolled back
      final dbCheck = _openRawDb();
      final count = sqlcipher.Sqflite.firstIntValue(await dbCheck.rawQuery("SELECT COUNT(*) FROM ratchet_wal WHERE conversation_id = '$convId'"));
      expect(count, corruptIndex); // Items up to corruptIndex-1 should remain, so total items is corruptIndex
    }
  });

  test('GC removes old entries correctly (11.4)', () async {
    const convId = 'conv_gc';
    
    // We will insert 15 entries. The threshold is 10.
    for (int i = 0; i < 15; i++) {
      final state = await _createDummyState(i);
      await store.append(convId, state);
    }
    
    // Check count. Should be 10 because GC fires on every append.
    final db = _openRawDb();
    final count = sqlcipher.Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ratchet_wal WHERE conversation_id = '$convId'"));
    // Wait, the append fires fire-and-forget GC. Let's wait a bit or invoke GC synchronously for test.
    // GC is internal. Let's just yield a bit to let the microtask finish.
    await Future.delayed(Duration(milliseconds: 50));
    
    final countAfterDelay = sqlcipher.Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ratchet_wal WHERE conversation_id = '$convId'"));
    expect(countAfterDelay, 10);
  });
}
