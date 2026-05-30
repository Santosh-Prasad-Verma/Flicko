/// Centralised HKDF / KDF "info" strings used as domain separators.
///
/// All E2EE derivations MUST pass exactly one of these as the HKDF
/// `info` parameter so an attacker cannot replay a derivation done in
/// one protocol context inside another (cross-protocol attack).
///
/// IMPORTANT: keep this file in lock-step with `protocol_info.go` on
/// the backend. A property test (Task 1.6) asserts the string sets are
/// identical and unique.
library;

class ProtocolInfo {
  ProtocolInfo._();

  /// X3DH initial root-key derivation.
  static const String x3dh = 'flicko-x3dh-v2';

  /// Double Ratchet — root chain step.
  static const String ratchetRoot = 'flicko-ratchet-root-v2';

  /// Double Ratchet — receiving chain key derivation.
  static const String ratchetRecv = 'flicko-ratchet-recv-v2';

  /// Double Ratchet — sending chain key derivation.
  static const String ratchetSend = 'flicko-ratchet-send-v2';

  /// Double Ratchet — per-message key from the chain key.
  static const String ratchetMsg = 'flicko-ratchet-msg-v2';

  /// Sealed-sender outer-envelope key derivation.
  static const String sealedSender = 'flicko-sealed-sender-v2';

  /// Encrypted-backup chunk key derivation.
  static const String backup = 'flicko-backup-v1';

  /// Domain tag for the per-envelope Ed25519 signature in group sender-key
  /// messages. Distinct from the chain/message-key derivation strings used
  /// inside [MultiDeviceManager] so a signature on a group envelope cannot
  /// be replayed as a chain-key derivation.
  static const String senderKey = 'flicko-sender-key-sig-v2';

  /// All info strings, exposed for the uniqueness property test.
  static const List<String> all = [
    x3dh,
    ratchetRoot,
    ratchetRecv,
    ratchetSend,
    ratchetMsg,
    sealedSender,
    backup,
    senderKey,
  ];
}
