package protocol

import (
	"encoding/json"
	"fmt"

	proto "github.com/flicko-org/flicko/services/shared/protocol"
)

// MaxFrameSize is the maximum raw WebSocket frame the gateway will
// accept before JSON parsing.  Matches MAX_MESSAGE_SIZE in config
// (default 4 KiB).  Frames exceeding this are rejected with
// CloseInvalidPayload.
const MaxFrameSize = 4096

// codec is the package-level JSON codec used by Encode / Decode.
var codec = proto.JSONCodec{}

// ── Codec interface (swap JSON → MessagePack later) ─────────────────

// Codec defines encode/decode behaviour.  The gateway currently uses
// JSONCodec; the interface exists so we can add MessagePack via a
// build tag or config flag without touching call sites.
type Codec = proto.Codec

// ── Public helpers ──────────────────────────────────────────────────

// Encode marshals an opcode + arbitrary payload into wire-format JSON.
//
//	raw, err := protocol.Encode(protocol.OpReady, readyPayload)
func Encode(op OpCode, data any) ([]byte, error) {
	msg, err := proto.NewMessage(op, data)
	if err != nil {
		return nil, fmt.Errorf("protocol.Encode: %w", err)
	}
	b, err := codec.Encode(msg)
	if err != nil {
		return nil, fmt.Errorf("protocol.Encode: %w", err)
	}
	return b, nil
}

// EncodeDispatch marshals an OpDispatch frame with event type, sequence,
// and payload.  Used by the fan-out writer.
func EncodeDispatch(eventType string, seq int64, data any) ([]byte, error) {
	msg, err := proto.NewDispatch(eventType, seq, data)
	if err != nil {
		return nil, fmt.Errorf("protocol.EncodeDispatch: %w", err)
	}
	b, err := codec.Encode(msg)
	if err != nil {
		return nil, fmt.Errorf("protocol.EncodeDispatch: %w", err)
	}
	return b, nil
}

// Decode unmarshals raw WebSocket bytes into a GatewayMessage.
// It enforces MaxFrameSize before touching the JSON parser.
func Decode(raw []byte) (*GatewayMessage, error) {
	if len(raw) > MaxFrameSize {
		return nil, fmt.Errorf("protocol.Decode: frame %d bytes exceeds limit %d",
			len(raw), MaxFrameSize)
	}
	msg, err := codec.Decode(raw)
	if err != nil {
		return nil, fmt.Errorf("protocol.Decode: %w", err)
	}
	return msg, nil
}

// DecodePayload extracts and unmarshals the D (payload) field of a
// GatewayMessage into the concrete type T.
//
//	id, err := protocol.DecodePayload[protocol.IdentifyPayload](msg)
func DecodePayload[T any](msg *GatewayMessage) (T, error) {
	return proto.DecodePayload[T](msg)
}

// DecodeRaw is a lower-level Decode that skips frame-size enforcement.
// Useful in tests; production code should always use Decode.
func DecodeRaw(raw []byte) (*GatewayMessage, error) {
	return codec.Decode(raw)
}

// ── Server-side message builders ────────────────────────────────────

// NewReadyMessage builds a complete OpReady frame.
func NewReadyMessage(sessionID, userID string, guilds []string, resumeURL string) ([]byte, error) {
	return Encode(OpReady, ReadyPayload{
		SessionID: sessionID,
		UserID:    userID,
		Guilds:    guilds,
		ResumeURL: resumeURL,
	})
}

// NewErrorMessage builds a complete OpError frame.
func NewErrorMessage(code int, message string, retry bool) ([]byte, error) {
	return Encode(OpError, ErrorPayload{
		Code:    code,
		Message: message,
		Retry:   retry,
	})
}

// NewAckMessage builds a complete OpMessageAck frame.
func NewAckMessage(nonce, messageID string) ([]byte, error) {
	return Encode(OpMessageAck, AckPayload{
		Nonce:     nonce,
		MessageID: messageID,
	})
}

// NewHeartbeatAck builds a heartbeat acknowledgement (op=1, d=null).
func NewHeartbeatAck() ([]byte, error) {
	msg := &GatewayMessage{
		Op: OpHeartbeat,
		D:  json.RawMessage("null"),
	}
	return codec.Encode(msg)
}
