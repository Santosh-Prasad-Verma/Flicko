/// Integration tests for the [GroupSession] sender-key engine.
///
/// Sender keys give every group member their own forward chain. Once a
/// member has shared its current sender key with everyone (out-of-band, via
/// the per-pair Double Ratchet), that member can broadcast a single
/// ciphertext per message and every receiver opens it locally.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/e2ee/domain/group_session.dart';
import 'package:mobile/features/e2ee/domain/multi_device.dart';

void main() {
  group('GroupSession (sender keys)', () {
    test('3-party broadcast: sender encrypts once, both receivers decrypt', () async {
      final aliceSigning = await Cryptography.instance.ed25519().newKeyPair();
      var aliceSenderKey = await MultiDeviceManager.generateSenderKey(
        groupId: 'group-1',
        deviceId: 'alice-phone',
        signingKeyPair: aliceSigning,
      );

      // Distribution: Bob and Carol each receive a copy of Alice's sender
      // key (in production via E2EESession.encryptV2). Test models this as
      // a value copy.
      var bobView = aliceSenderKey;
      var carolView = aliceSenderKey;

      // Alice broadcasts.
      final r = await GroupSession.encrypt(
        senderKey: aliceSenderKey,
        signingKeyPair: aliceSigning,
        plaintext: Uint8List.fromList('hello group'.codeUnits),
      );
      aliceSenderKey = r.advanced;

      final bobOut = await GroupSession.decrypt(
        envelope: r.envelope,
        peerSenderKey: bobView,
      );
      bobView = bobOut.advanced;
      expect(String.fromCharCodes(bobOut.plaintext), 'hello group');

      final carolOut = await GroupSession.decrypt(
        envelope: r.envelope,
        peerSenderKey: carolView,
      );
      carolView = carolOut.advanced;
      expect(String.fromCharCodes(carolOut.plaintext), 'hello group');

      // Chains are aligned across all three views.
      expect(aliceSenderKey.chainId, 1);
      expect(bobView.chainId, 1);
      expect(carolView.chainId, 1);
    });

    test('multiple sequential broadcasts advance the chain on every side', () async {
      final signing = await Cryptography.instance.ed25519().newKeyPair();
      var senderKey = await MultiDeviceManager.generateSenderKey(
        groupId: 'g',
        deviceId: 'a',
        signingKeyPair: signing,
      );
      var bobView = senderKey;

      const messages = ['m1', 'm2', 'm3', 'm4'];
      for (final m in messages) {
        final r = await GroupSession.encrypt(
          senderKey: senderKey,
          signingKeyPair: signing,
          plaintext: Uint8List.fromList(m.codeUnits),
        );
        senderKey = r.advanced;

        final out = await GroupSession.decrypt(
          envelope: r.envelope,
          peerSenderKey: bobView,
        );
        bobView = out.advanced;
        expect(String.fromCharCodes(out.plaintext), m);
      }

      expect(senderKey.chainId, messages.length);
      expect(bobView.chainId, messages.length);
    });

    test('tampered ciphertext fails signature verification (chain not advanced)', () async {
      final signing = await Cryptography.instance.ed25519().newKeyPair();
      final senderKey = await MultiDeviceManager.generateSenderKey(
        groupId: 'g',
        deviceId: 'a',
        signingKeyPair: signing,
      );
      var bobView = senderKey;

      final r = await GroupSession.encrypt(
        senderKey: senderKey,
        signingKeyPair: signing,
        plaintext: Uint8List.fromList('confidential'.codeUnits),
      );

      // Flip one bit in the middle of the ciphertext.
      final raw = Uint8List.fromList(r.envelope.ciphertext);
      raw[raw.length ~/ 2] ^= 0x01;
      final tampered = GroupEnvelope(
        groupId: r.envelope.groupId,
        senderDeviceId: r.envelope.senderDeviceId,
        chainId: r.envelope.chainId,
        ciphertext: raw,
        signature: r.envelope.signature,
      );

      expect(
        () => GroupSession.decrypt(envelope: tampered, peerSenderKey: bobView),
        throwsA(isA<GroupSignatureError>()),
      );
      // Bob's view is still on chain 0 — bad envelope did not advance state.
      expect(bobView.chainId, 0);
    });

    test('replay (chainId already processed) is rejected', () async {
      final signing = await Cryptography.instance.ed25519().newKeyPair();
      var senderKey = await MultiDeviceManager.generateSenderKey(
        groupId: 'g',
        deviceId: 'a',
        signingKeyPair: signing,
      );
      var bobView = senderKey;

      final r1 = await GroupSession.encrypt(
        senderKey: senderKey,
        signingKeyPair: signing,
        plaintext: Uint8List.fromList('first'.codeUnits),
      );
      senderKey = r1.advanced;

      final out1 =
          await GroupSession.decrypt(envelope: r1.envelope, peerSenderKey: bobView);
      bobView = out1.advanced;

      // Replay r1 — must fail with chain-order error.
      expect(
        () => GroupSession.decrypt(envelope: r1.envelope, peerSenderKey: bobView),
        throwsA(isA<GroupChainOrderError>()),
      );
    });

    test('forged signature with attacker key fails verification', () async {
      // Attacker tries to publish a "from Alice" envelope they never
      // generated. They can encrypt with the (leaked?) chain key but cannot
      // produce a valid signature without Alice's signing private key.
      final aliceSigning = await Cryptography.instance.ed25519().newKeyPair();
      final attackerSigning =
          await Cryptography.instance.ed25519().newKeyPair();
      final senderKey = await MultiDeviceManager.generateSenderKey(
        groupId: 'g',
        deviceId: 'alice',
        signingKeyPair: aliceSigning,
      );

      // Attacker uses the chain key but signs with their own key.
      final r = await GroupSession.encrypt(
        senderKey: senderKey,
        signingKeyPair: attackerSigning,
        plaintext: Uint8List.fromList('forged'.codeUnits),
      );

      // Bob's view still pins Alice's signing pub.
      expect(
        () => GroupSession.decrypt(envelope: r.envelope, peerSenderKey: senderKey),
        throwsA(isA<GroupSignatureError>()),
      );
    });
  });
}
