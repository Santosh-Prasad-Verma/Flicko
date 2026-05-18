// Property tests for E2EE protocol-info constants.
//
// Property:
//   For all derivations in the v2 stack, the HKDF `info` strings are
//   pairwise distinct AND non-empty AND prefixed with `flicko-`.
//
// Why this matters: a duplicated info string lets an attacker take
// material derived in one protocol and use it as if it had been derived
// for another (cross-protocol confusion). Domain separation is the only
// defence (R1.4).

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/e2ee/domain/protocol_info.dart';

void main() {
  group('ProtocolInfo', () {
    test('all info strings are non-empty', () {
      for (final info in ProtocolInfo.all) {
        expect(info, isNotEmpty);
      }
    });

    test('all info strings start with the "flicko-" project prefix', () {
      for (final info in ProtocolInfo.all) {
        expect(info, startsWith('flicko-'),
            reason: 'every info MUST identify the project to prevent reuse');
      }
    });

    test('all info strings are pairwise distinct', () {
      final asSet = ProtocolInfo.all.toSet();
      expect(asSet.length, ProtocolInfo.all.length,
          reason: 'duplicate domain-separation tags break R1.4');
    });

    test('expected protocol set is covered', () {
      expect(
        ProtocolInfo.all,
        containsAll([
          ProtocolInfo.x3dh,
          ProtocolInfo.ratchetRoot,
          ProtocolInfo.ratchetRecv,
          ProtocolInfo.ratchetSend,
          ProtocolInfo.ratchetMsg,
          ProtocolInfo.sealedSender,
          ProtocolInfo.backup,
        ]),
      );
    });
  });
}
