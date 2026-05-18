/// Sealed Sender envelope (Tasks 17-19).
///
/// Two-layer envelope hiding sender identity from server.
/// References: design.md §8, requirements.md R13
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../domain/protocol_info.dart';

const String _sealedInfo = ProtocolInfo.sealedSender;

class AbuseToken {
  final String tokenHash;
  final int epochDay;
  const AbuseToken({required this.tokenHash, required this.epochDay});

  static Future<AbuseToken> generate(Uint8List senderPub) async {
    final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final input = Uint8List(senderPub.length + 4)..setRange(0, senderPub.length, senderPub);
    ByteData.view(input.buffer, input.offsetInBytes, input.length).setUint32(senderPub.length, day, Endian.big);
    final hash = await Sha256().hash(input);
    return AbuseToken(tokenHash: hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), epochDay: day);
  }
}

class SealedSenderEnvelope {
  final String recipientDeviceId;
  final Uint8List outerEphemeralPub;
  final Uint8List outerCiphertext;
  final Uint8List outerNonce;
  final AbuseToken abuseToken;

  const SealedSenderEnvelope({required this.recipientDeviceId, required this.outerEphemeralPub, required this.outerCiphertext, required this.outerNonce, required this.abuseToken});

  Map<String, dynamic> toJson() => {'recipient_device_id': recipientDeviceId, 'outer_ephemeral_pub': base64Encode(outerEphemeralPub), 'outer_ciphertext': base64Encode(outerCiphertext), 'outer_nonce': base64Encode(outerNonce), 'abuse_token': abuseToken.tokenHash, 'abuse_epoch_day': abuseToken.epochDay};

  factory SealedSenderEnvelope.fromJson(Map<String, dynamic> j) => SealedSenderEnvelope(recipientDeviceId: j['recipient_device_id'] as String, outerEphemeralPub: Uint8List.fromList(base64Decode(j['outer_ephemeral_pub'] as String)), outerCiphertext: Uint8List.fromList(base64Decode(j['outer_ciphertext'] as String)), outerNonce: Uint8List.fromList(base64Decode(j['outer_nonce'] as String)), abuseToken: AbuseToken(tokenHash: j['abuse_token'] as String, epochDay: (j['abuse_epoch_day'] as num).toInt()));
}

class SealedSenderEngine {
  static final _x25519 = Cryptography.instance.x25519();
  static final _aead = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static Future<SealedSenderEnvelope> seal({required Uint8List innerCiphertext, required Uint8List senderIdentityPub, required String senderDeviceId, required Uint8List recipientIdentityPub, required String recipientDeviceId}) async {
    final outerEph = await _x25519.newKeyPair();
    final outerEphPub = await outerEph.extractPublicKey();
    final dh = await _x25519.sharedSecretKey(keyPair: outerEph, remotePublicKey: SimplePublicKey(recipientIdentityPub, type: KeyPairType.x25519));
    final outerKey = await _hkdf.deriveKey(secretKey: SecretKey(await dh.extractBytes()), info: utf8.encode(_sealedInfo), nonce: Uint8List(0));
    final devBytes = utf8.encode(senderDeviceId);
    final plain = Uint8List(32 + 2 + devBytes.length + innerCiphertext.length)..setRange(0, 32, senderIdentityPub);
    ByteData.view(plain.buffer, plain.offsetInBytes, plain.length).setUint16(32, devBytes.length, Endian.big);
    plain.setRange(34, 34 + devBytes.length, devBytes);
    plain.setRange(34 + devBytes.length, plain.length, innerCiphertext);
    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(plain, secretKey: SecretKey(await outerKey.extractBytes()), nonce: nonce);
    final ct = Uint8List(box.cipherText.length + box.mac.bytes.length)..setRange(0, box.cipherText.length, box.cipherText)..setRange(box.cipherText.length, box.cipherText.length + box.mac.bytes.length, box.mac.bytes);
    return SealedSenderEnvelope(recipientDeviceId: recipientDeviceId, outerEphemeralPub: Uint8List.fromList(outerEphPub.bytes), outerCiphertext: ct, outerNonce: Uint8List.fromList(nonce), abuseToken: await AbuseToken.generate(senderIdentityPub));
  }

  static Future<({Uint8List senderIdentityPub, String senderDeviceId, Uint8List innerCiphertext})> unseal({required SealedSenderEnvelope envelope, required SimpleKeyPair recipientIdentityKeyPair}) async {
    final dh = await _x25519.sharedSecretKey(keyPair: recipientIdentityKeyPair, remotePublicKey: SimplePublicKey(envelope.outerEphemeralPub, type: KeyPairType.x25519));
    final outerKey = await _hkdf.deriveKey(secretKey: SecretKey(await dh.extractBytes()), info: utf8.encode(_sealedInfo), nonce: Uint8List(0));
    final ct = envelope.outerCiphertext;
    final macStart = ct.length - 16;
    final box = SecretBox(ct.sublist(0, macStart), nonce: envelope.outerNonce, mac: Mac(ct.sublist(macStart)));
    final plain = Uint8List.fromList(await _aead.decrypt(box, secretKey: SecretKey(await outerKey.extractBytes())));
    final senderPub = plain.sublist(0, 32);
    final devLen = ByteData.view(plain.buffer, plain.offsetInBytes, plain.length).getUint16(32, Endian.big);
    final deviceId = utf8.decode(plain.sublist(34, 34 + devLen));
    return (senderIdentityPub: senderPub, senderDeviceId: deviceId, innerCiphertext: plain.sublist(34 + devLen));
  }
}
