/// Engine-level tests for the [DoubleRatchet] skipped-key cache boundary.
///
/// The ratchet caps how many keys a receiver will derive in one go to
/// catch up across out-of-order messages. The cap protects against DoS
/// (R5.5) — a malicious sender claiming index 10^9 must not exhaust
/// memory or CPU.
///
/// These tests pin the boundary's behaviour so a future refactor can't
/// silently change it. They run directly against [DoubleRatchet] without
/// going through [E2EESession]/[RatchetWalStore], so they exercise the
/// crypto cap in isolation.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/e2ee/domain/ratchet.dart';

/// Bootstrap a fresh sender/receiver pair sharing a static root key. We
/// don't need X3DH for these tests — the property under test is in the
/// ratchet engine itself.
Future<({RatchetState alice, RatchetState bob})> _newPair() async {
  final x = Cryptography.instance.x25519();
  final bobSpk = await x.newKeyPair();
  final spkPub = await bobSpk.extractPublicKey();
  // Deterministic shared secret — content doesn't matter, only that both
  // sides start with the same RK.
  final sharedKey = Uint8List(32)..fillRange(0, 32, 7);
  final alice = await DoubleRatchet.initSender(
    sharedKey: sharedKey,
    recipientDhPub: Uint8List.fromList(spkPub.bytes),
  );
  final bob = await DoubleRatchet.initRecipient(
    sharedKey: sharedKey,
    mySignedPrekey: bobSpk,
  );
  return (alice: alice, bob: bob);
}

/// Send N+1 messages from Alice and return all of them as wire envelopes.
/// Used to set up "skip N keys" scenarios.
Future<List<({RatchetHeader header, Uint8List ciphertext})>>
    _sendN(RatchetState alice, int count, {Uint8List? aad}) async {
  final out = <({RatchetHeader header, Uint8List ciphertext})>[];
  final ad = aad ?? Uint8List(0);
  for (var i = 0; i < count; i++) {
    final r = await DoubleRatchet.encrypt(
      state: alice,
      plaintext: Uint8List.fromList('m$i'.codeUnits),
      associatedData: ad,
    );
    out.add((header: r.header, ciphertext: r.ciphertext));
  }
  return out;
}

void main() {
  group('Double Ratchet skipped-key cap (kMaxSkip = 1000)', () {
    test('boundary value: kMaxSkip is exactly 1000', () {
      // If this ever changes, every test below needs to be reviewed —
      // pin the constant explicitly.
      expect(kMaxSkip, 1000);
    });

    test('skip 999 keys: receiver catches up to the tail', () async {
      final pair = await _newPair();
      final envs = await _sendN(pair.alice, kMaxSkip); // 1000 envelopes total
      // Bob receives the LAST envelope first → forces _skipMessageKeys span = 999.
      final r = await DoubleRatchet.decrypt(
        state: pair.bob,
        header: envs.last.header,
        ciphertext: envs.last.ciphertext,
        associatedData: Uint8List(0),
      );
      expect(String.fromCharCodes(r.plaintext), 'm${kMaxSkip - 1}');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('skip exactly kMaxSkip (1000) keys: still decrypts at the cap', () async {
      // Send 1001 envelopes: indices 0..1000. Receiving #1000 first means
      // _skipMessageKeys derives 1000 keys (span = until - start = 1000).
      // The cap is `until - start > kMaxSkip` so span == 1000 must succeed.
      final pair = await _newPair();
      final envs = await _sendN(pair.alice, kMaxSkip + 1);
      final r = await DoubleRatchet.decrypt(
        state: pair.bob,
        header: envs.last.header,
        ciphertext: envs.last.ciphertext,
        associatedData: Uint8List(0),
      );
      expect(String.fromCharCodes(r.plaintext), 'm$kMaxSkip');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('skip kMaxSkip+1 (1001) keys: throws RatchetSkipExceededError', () async {
      final pair = await _newPair();
      final envs = await _sendN(pair.alice, kMaxSkip + 2); // indices 0..1001
      // Receiving #1001 first → span = 1001 → must throw.
      await expectLater(
        DoubleRatchet.decrypt(
          state: pair.bob,
          header: envs.last.header,
          ciphertext: envs.last.ciphertext,
          associatedData: Uint8List(0),
        ),
        throwsA(isA<RatchetSkipExceededError>()),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('after skip-exceeded throw, an in-order message still decrypts', () async {
      // The cap protects against DoS without bricking the conversation: a
      // subsequent in-order message must still work. We send 1002 envelopes,
      // try to decrypt #1001 (over the cap, throws), then receive #0 (the
      // first in-order message) — which should succeed cleanly.
      final pair = await _newPair();
      final envs = await _sendN(pair.alice, kMaxSkip + 2);

      try {
        await DoubleRatchet.decrypt(
          state: pair.bob,
          header: envs.last.header,
          ciphertext: envs.last.ciphertext,
          associatedData: Uint8List(0),
        );
        fail('expected RatchetSkipExceededError');
      } on RatchetSkipExceededError {
        // expected
      }

      // In-order message #0 still decrypts.
      final r = await DoubleRatchet.decrypt(
        state: pair.bob,
        header: envs.first.header,
        ciphertext: envs.first.ciphertext,
        associatedData: Uint8List(0),
      );
      expect(String.fromCharCodes(r.plaintext), 'm0');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
