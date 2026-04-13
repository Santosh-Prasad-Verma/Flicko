package protocol

import (
	proto "github.com/flicko-org/flicko/services/shared/protocol"
)

// ── Wire-format envelope ────────────────────────────────────────────

// GatewayMessage is the top-level frame envelope.
//
//	{
//	  "op": 5,
//	  "d":  { ... },
//	  "s":  42,          // sequence (dispatch only)
//	  "t":  "MESSAGE_CREATE",  // event type (dispatch only)
//	  "n":  "client-nonce"     // idempotency nonce
//	}
type GatewayMessage = proto.GatewayMessage

// ── Payload types ───────────────────────────────────────────────────

// IdentifyPayload — Client → Server (OpIdentify).
// First frame after WS open; carries JWT + device fingerprint.
type IdentifyPayload = proto.IdentifyPayload

// ReadyPayload — Server → Client (OpReady).
// Sent after successful authentication.
type ReadyPayload = proto.ReadyPayload

// MessagePayload — Bidirectional (OpMessageCreate / OpDispatch).
type MessagePayload = proto.MessagePayload

// Attachment — nested inside MessagePayload.
type Attachment = proto.Attachment

// TypingPayload — Client → Server (OpTypingStart).
type TypingPayload = proto.TypingPayload

// PresencePayload — Bidirectional (OpPresenceUpdate).
type PresencePayload = proto.PresencePayload

// ChannelSubPayload — Client → Server (OpChannelSub / OpChannelUnsub).
type ChannelSubPayload = proto.ChannelSubPayload

// ErrorPayload — Server → Client (OpError).
type ErrorPayload = proto.ErrorPayload

// AckPayload — Server → Client (OpMessageAck).
type AckPayload = proto.AckPayload
