package protocol

// OpCode represents WebSocket gateway operation codes.
// These define the type of every frame exchanged between client and gateway.
type OpCode int

const (
// OpDispatch — Server → Client: event delivery (message, member update, etc.).
// The event name lives in GatewayMessage.T, payload in D.
OpDispatch OpCode = 0

// OpHeartbeat — Client → Server: keep-alive ping.
// Payload: {"d": <last_sequence_number>}
OpHeartbeat OpCode = 1

// OpIdentify — Client → Server: first message after WS open.
// Payload: IdentifyPayload{Token, DeviceID}.
OpIdentify OpCode = 2

// OpPresenceUpdate — Bidirectional: online/idle/dnd/offline status.
// Payload: PresencePayload.
OpPresenceUpdate OpCode = 3

// OpTypingStart — Client → Server: user started typing.
// Payload: TypingPayload{ChannelID, UserID, Timestamp}.
OpTypingStart OpCode = 4

// OpMessageCreate — Client → Server: send a chat message.
// Payload: MessagePayload (content + nonce for idempotency).
OpMessageCreate OpCode = 5

// OpMessageAck — Server → Client: delivery confirmation.
// Payload: AckPayload{Nonce, MessageID}.
OpMessageAck OpCode = 6

// OpError — Server → Client: error response.
// Payload: ErrorPayload{Code, Message, Retry}.
OpError OpCode = 7

// OpChannelSub — Client → Server: subscribe to a channel's events.
// Payload: ChannelSubPayload{ChannelID}.
OpChannelSub OpCode = 8

// OpChannelUnsub — Client → Server: unsubscribe from a channel.
// Payload: ChannelSubPayload{ChannelID}.
OpChannelUnsub OpCode = 9

// OpReady — Server → Client: sent after successful Identify.
// Payload: ReadyPayload{SessionID, UserID, Guilds, ResumeURL}.
OpReady OpCode = 10
)

// String returns the human-readable name of an opcode.
func (o OpCode) String() string {
switch o {
case OpDispatch:
return "DISPATCH"
case OpHeartbeat:
return "HEARTBEAT"
case OpIdentify:
return "IDENTIFY"
case OpPresenceUpdate:
return "PRESENCE_UPDATE"
case OpTypingStart:
return "TYPING_START"
case OpMessageCreate:
return "MESSAGE_CREATE"
case OpMessageAck:
return "MESSAGE_ACK"
case OpError:
return "ERROR"
case OpChannelSub:
return "CHANNEL_SUB"
case OpChannelUnsub:
return "CHANNEL_UNSUB"
case OpReady:
return "READY"
default:
return "UNKNOWN"
}
}

// IsClientOp returns true if this opcode is sent by the client.
func (o OpCode) IsClientOp() bool {
switch o {
case OpHeartbeat, OpIdentify, OpPresenceUpdate,
OpTypingStart, OpMessageCreate, OpChannelSub, OpChannelUnsub:
return true
default:
return false
}
}

// IsServerOp returns true if this opcode is sent by the server.
func (o OpCode) IsServerOp() bool {
switch o {
case OpDispatch, OpMessageAck, OpError, OpReady:
return true
case OpPresenceUpdate:
return true // bidirectional
default:
return false
}
}
