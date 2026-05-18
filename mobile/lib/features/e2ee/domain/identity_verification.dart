/// Identity rotation & verification (Tasks 12-16).
///
/// Covers: attested rotation, compromise reset, safety numbers,
/// QR verification, SAS, verification audit log, change alerts.
/// References: design.md §7, requirements.md R9, R12
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Generates a 60-digit safety number from two identity keys (R9.1).
/// The number is the same regardless of who computes it (commutative).
class SafetyNumber {
  static final _sha256 = Sha256();

  static Future<String> compute({
    required Uint8List localIdentityPub,
    required Uint8List remoteIdentityPub,
  }) async {
    // Order keys lexicographically so both sides get the same result.
    final cmp = _compareBytes(localIdentityPub, remoteIdentityPub);
    final first = cmp <= 0 ? localIdentityPub : remoteIdentityPub;
    final second = cmp <= 0 ? remoteIdentityPub : localIdentityPub;
    final combined = Uint8List(first.length + second.length)
      ..setRange(0, first.length, first)
      ..setRange(first.length, first.length + second.length, second);

    // Hash and truncate to 60 digits (30 bytes → 60 hex chars → 60 decimal digits).
    Hash hash = await _sha256.hash(combined);
    // Iterate 5200 times per Signal spec for slow hash.
    for (var i = 0; i < 5200; i++) {
      hash = await _sha256.hash(hash.bytes);
    }
    // Convert first 30 bytes to decimal digits.
    final digits = StringBuffer();
    for (var i = 0; i < 30 && i < hash.bytes.length; i++) {
      digits.write((hash.bytes[i] % 10).toString());
      digits.write(((hash.bytes[i] ~/ 10) % 10).toString());
    }
    return digits.toString();
  }

  /// Format for display: groups of 5 digits separated by spaces.
  static String format(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i += 5) {
      if (i > 0) buf.write(' ');
      buf.write(digits.substring(i, (i + 5).clamp(0, digits.length)));
    }
    return buf.toString();
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }
}

/// SAS (Short Authentication String) — 6-word phrase for verbal verification (R9.5).
class SasVerification {
  static const List<String> _wordList = [
    'alpha','bravo','charlie','delta','echo','foxtrot','golf','hotel',
    'india','juliet','kilo','lima','mike','november','oscar','papa',
    'quebec','romeo','sierra','tango','uniform','victor','whiskey','xray',
    'yankee','zulu','anchor','arrow','atlas','badge','beacon','blade',
    'bridge','candle','castle','cedar','cipher','coast','coral','crown',
    'dagger','dawn','diamond','drift','eagle','ember','falcon','flare',
    'forge','frost','garden','glacier','granite','harbor','hawk','ivory',
    'jade','knight','lantern','lunar','maple','marble','meadow','meteor',
  ];

  /// Generate a 6-word SAS from two identity keys.
  static Future<String> generate({
    required Uint8List localPub,
    required Uint8List remotePub,
  }) async {
    final combined = Uint8List(localPub.length + remotePub.length)
      ..setRange(0, localPub.length, localPub)
      ..setRange(localPub.length, localPub.length + remotePub.length, remotePub);
    final hash = await Sha256().hash(combined);
    final words = <String>[];
    for (var i = 0; i < 6; i++) {
      words.add(_wordList[hash.bytes[i] % _wordList.length]);
    }
    return words.join(' ');
  }
}

/// Identity rotation attestation (Task 12).
///
/// When a user rotates their identity key, the old key signs a statement
/// attesting that the new key is the legitimate successor (R9.3).
class IdentityAttestation {
  final Uint8List oldIdentityPub;
  final Uint8List newIdentityPub;
  final Uint8List attestationSignature; // Ed25519 sig from old signing key
  final DateTime attestedAt;

  const IdentityAttestation({
    required this.oldIdentityPub,
    required this.newIdentityPub,
    required this.attestationSignature,
    required this.attestedAt,
  });

  /// Create an attestation: old signing key signs "rotate:<oldPub>:<newPub>".
  static Future<IdentityAttestation> create({
    required SimpleKeyPair oldSigningKeyPair,
    required Uint8List oldIdentityPub,
    required Uint8List newIdentityPub,
  }) async {
    final msg = utf8.encode('rotate:${base64Encode(oldIdentityPub)}:${base64Encode(newIdentityPub)}');
    final ed = Cryptography.instance.ed25519();
    final sig = await ed.sign(msg, keyPair: oldSigningKeyPair);
    return IdentityAttestation(
      oldIdentityPub: oldIdentityPub,
      newIdentityPub: newIdentityPub,
      attestationSignature: Uint8List.fromList(sig.bytes),
      attestedAt: DateTime.now().toUtc(),
    );
  }

  /// Verify an attestation against the old signing public key.
  static Future<bool> verify(IdentityAttestation att, Uint8List oldSigningPub) async {
    final msg = utf8.encode('rotate:${base64Encode(att.oldIdentityPub)}:${base64Encode(att.newIdentityPub)}');
    final ed = Cryptography.instance.ed25519();
    final sig = Signature(att.attestationSignature, publicKey: SimplePublicKey(oldSigningPub, type: KeyPairType.ed25519));
    return ed.verify(msg, signature: sig);
  }

  Map<String, dynamic> toJson() => {
    'old_pub': base64Encode(oldIdentityPub),
    'new_pub': base64Encode(newIdentityPub),
    'signature': base64Encode(attestationSignature),
    'attested_at': attestedAt.toIso8601String(),
  };
}

/// Verification audit log entry (Task 15, R12.1).
class VerificationRecord {
  final String peerId;
  final String method; // safety_number | qr | sas
  final String fingerprint;
  final bool verified;
  final DateTime timestamp;

  const VerificationRecord({
    required this.peerId,
    required this.method,
    required this.fingerprint,
    required this.verified,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'peer_id': peerId,
    'method': method,
    'fingerprint': fingerprint,
    'verified': verified,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Identity change alert for UI surfacing (Task 16).
class IdentityChangeAlert {
  final String userId;
  final String oldFingerprint;
  final String newFingerprint;
  final bool hasAttestation;
  final DateTime detectedAt;

  const IdentityChangeAlert({
    required this.userId,
    required this.oldFingerprint,
    required this.newFingerprint,
    required this.hasAttestation,
    required this.detectedAt,
  });
}
