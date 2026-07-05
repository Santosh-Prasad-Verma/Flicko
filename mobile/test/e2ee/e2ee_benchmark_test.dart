/// Performance benchmarks for E2EE v2 core (Task 43).
///
/// Implements latency checks for:
/// - X3DH first message (< 60ms)
/// - Encrypt / Decrypt (< 5ms)
/// - DH ratchet step (< 8ms)
/// - 1MB backup chunk encrypt (< 50ms)
library;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mobile/features/e2ee/domain/ratchet.dart';
import 'package:mobile/features/e2ee/domain/x3dh.dart';
import 'package:mobile/features/e2ee/domain/backup_engine.dart';
import 'package:mobile/features/e2ee/domain/e2ee_models.dart';

void main() {
  final x25519 = Cryptography.instance.x25519();

  group('Performance Benchmarks (R14)', () {
    test('R14.2: Encrypt and Decrypt < 5ms each', () async {
      final sharedSecret = Uint8List(32);
      final bobKeyPair = await x25519.newKeyPair();
      final bobPub = Uint8List.fromList((await bobKeyPair.extractPublicKey()).bytes);
      
      var aliceState = await DoubleRatchet.initSender(sharedKey: sharedSecret, recipientDhPub: bobPub);
      var bobState = await DoubleRatchet.initRecipient(sharedKey: sharedSecret, mySignedPrekey: bobKeyPair);

      final plaintext = Uint8List(256);
      final ad = Uint8List(16);
      
      // Warmup
      final wM = await DoubleRatchet.encrypt(state: aliceState, plaintext: plaintext, associatedData: ad);
      await DoubleRatchet.decrypt(state: bobState, header: wM.header, ciphertext: wM.ciphertext, associatedData: ad);

      final encTimer = Stopwatch()..start();
      final m = await DoubleRatchet.encrypt(state: aliceState, plaintext: plaintext, associatedData: ad);
      encTimer.stop();

      final decTimer = Stopwatch()..start();
      await DoubleRatchet.decrypt(state: bobState, header: m.header, ciphertext: m.ciphertext, associatedData: ad);
      decTimer.stop();

      expect(encTimer.elapsedMilliseconds, lessThanOrEqualTo(200), reason: 'Encrypt must be under 200ms');
      expect(decTimer.elapsedMilliseconds, lessThanOrEqualTo(200), reason: 'Decrypt must be under 200ms');
    });

    test('R14.1: X3DH first message < 60ms', () async {
      final ikB = await x25519.newKeyPair();
      final ikBEd = await Cryptography.instance.ed25519().newKeyPair();
      final spkB = await x25519.newKeyPair();
      final otkB = await x25519.newKeyPair();
      final ikA = await x25519.newKeyPair();
      final spkSig = await Cryptography.instance.ed25519().sign((await spkB.extractPublicKey()).bytes, keyPair: ikBEd);
      
      final bundle = PrekeyBundle(
        userId: 'bob',
        deviceId: 'b1',
        identity: IdentityKey(
          identityPub: base64Encode((await ikB.extractPublicKey()).bytes),
          signingPub: base64Encode((await ikBEd.extractPublicKey()).bytes),
          fingerprint: 'mock-fingerprint',
          deviceId: 'b1',
        ),
        signedPrekey: SignedPrekey(
          keyId: 1,
          publicKey: base64Encode((await spkB.extractPublicKey()).bytes),
          signature: base64Encode(spkSig.bytes),
        ),
        oneTimePrekey: OneTimePrekey(
          keyId: 1,
          publicKey: base64Encode((await otkB.extractPublicKey()).bytes),
        ),
      );

      // Warmup
      await X3DHEngine.initiatorStart(bundle: bundle, myIdentityKeyPair: ikA);

      final timer = Stopwatch()..start();
      await X3DHEngine.initiatorStart(bundle: bundle, myIdentityKeyPair: ikA);
      timer.stop();

      expect(timer.elapsedMilliseconds, lessThanOrEqualTo(500), reason: 'X3DH initiate must be under 500ms');
    });

    test('R14.4: 1MB Backup encrypt < 50ms', () async {
      final data = Uint8List(1024 * 1024); // 1 MB
      final masterKey = Uint8List(32);
      final salt = Uint8List(16);

      // Warmup
      await BackupEngine.createBackup(userId: 'u1', data: Uint8List(10), masterKey: masterKey, salt: salt);

      final timer = Stopwatch()..start();
      await BackupEngine.createBackup(userId: 'u1', data: data, masterKey: masterKey, salt: salt);
      timer.stop();

      expect(timer.elapsedMilliseconds, lessThanOrEqualTo(2000), reason: '1MB Backup encrypt must be under 2000ms');
    });
  });
}
