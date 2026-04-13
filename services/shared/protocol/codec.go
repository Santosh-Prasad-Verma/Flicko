package protocol

import "encoding/json"

// Codec defines the interface for encoding/decoding gateway messages.
// Default implementation uses JSON; designed so MessagePack can be swapped in.
type Codec interface {
// Encode serializes a gateway message to bytes.
Encode(msg *GatewayMessage) ([]byte, error)

// Decode deserializes bytes into a GatewayMessage.
Decode(data []byte) (*GatewayMessage, error)
}

// JSONCodec implements Codec using encoding/json.
type JSONCodec struct{}

// Encode serializes the GatewayMessage to JSON bytes.
func (c JSONCodec) Encode(msg *GatewayMessage) ([]byte, error) {
return json.Marshal(msg)
}

// Decode deserializes JSON bytes into a GatewayMessage.
func (c JSONCodec) Decode(data []byte) (*GatewayMessage, error) {
var msg GatewayMessage
if err := json.Unmarshal(data, &msg); err != nil {
return nil, err
}
return &msg, nil
}

// NewMessage creates a GatewayMessage with the given opcode and payload.
// The payload is marshaled to json.RawMessage.
func NewMessage(op OpCode, payload interface{}) (*GatewayMessage, error) {
d, err := json.Marshal(payload)
if err != nil {
return nil, err
}
return &GatewayMessage{
Op: op,
D:  json.RawMessage(d),
}, nil
}

// NewDispatch creates an OpDispatch message with event type and sequence.
func NewDispatch(eventType string, seq int64, payload interface{}) (*GatewayMessage, error) {
d, err := json.Marshal(payload)
if err != nil {
return nil, err
}
return &GatewayMessage{
Op: OpDispatch,
D:  json.RawMessage(d),
S:  seq,
T:  eventType,
}, nil
}

// NewError creates an OpError message from code, message, and retry flag.
func NewError(code int, message string, retry bool) (*GatewayMessage, error) {
return NewMessage(OpError, ErrorPayload{
Code:    code,
Message: message,
Retry:   retry,
})
}

// NewAck creates an OpMessageAck message.
func NewAck(nonce, messageID string) (*GatewayMessage, error) {
return NewMessage(OpMessageAck, AckPayload{
Nonce:     nonce,
MessageID: messageID,
})
}

// DecodePayload extracts and unmarshals the D field into the target type T.
func DecodePayload[T any](msg *GatewayMessage) (T, error) {
var payload T
if err := json.Unmarshal(msg.D, &payload); err != nil {
return payload, err
}
return payload, nil
}

// MustEncode is like JSONCodec.Encode but panics on error.
// Useful in tests and for payloads guaranteed to be valid.
func MustEncode(msg *GatewayMessage) []byte {
data, err := JSONCodec{}.Encode(msg)
if err != nil {
panic("protocol.MustEncode: " + err.Error())
}
return data
}
