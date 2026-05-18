// Package e2ee — domain-separated KDF info strings.
//
// Mirrors mobile/lib/features/e2ee/domain/protocol_info.dart.
// A property test asserts both lists are identical and unique.
package e2ee

const (
	InfoX3DH         = "flicko-x3dh-v2"
	InfoRatchetRoot  = "flicko-ratchet-root-v2"
	InfoRatchetRecv  = "flicko-ratchet-recv-v2"
	InfoRatchetSend  = "flicko-ratchet-send-v2"
	InfoRatchetMsg   = "flicko-ratchet-msg-v2"
	InfoSealedSender = "flicko-sealed-sender-v2"
	InfoBackup       = "flicko-backup-v1"
)

// AllInfos enumerates every protocol-info string used by the v2 stack.
// Order MUST match `ProtocolInfo.all` in the Dart counterpart.
var AllInfos = []string{
	InfoX3DH,
	InfoRatchetRoot,
	InfoRatchetRecv,
	InfoRatchetSend,
	InfoRatchetMsg,
	InfoSealedSender,
	InfoBackup,
}
