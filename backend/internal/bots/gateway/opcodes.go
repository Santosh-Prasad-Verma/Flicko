package gateway

import "encoding/json"

// Gateway Opcodes (Discord Protocol Compatible)
const (
	OpDispatch         = 0  // Receive: Event Dispatch
	OpHeartbeat        = 1  // Send/Receive: Heartbeat
	OpIdentify         = 2  // Send: Identify
	OpPresenceUpdate   = 3  // Send: Presence Update
	OpVoiceStateUpdate = 4  // Send: Voice State Update
	OpResume           = 6  // Send: Resume
	OpReconnect        = 7  // Receive: Reconnect
	OpRequestMembers   = 8  // Send: Request Guild Members
	OpInvalidSession   = 9  // Receive: Invalid Session
	OpHello            = 10 // Receive: Hello
	OpHeartbeatACK     = 11 // Receive: Heartbeat ACK
)

type GatewayPayload struct {
	Op int             `json:"op"`
	D  json.RawMessage `json:"d,omitempty"`
	S  *int64          `json:"s,omitempty"`
	T  string          `json:"t,omitempty"`
}

type HelloData struct {
	HeartbeatInterval int `json:"heartbeat_interval"` // In milliseconds (e.g. 41250)
}

type IdentifyData struct {
	Token   string `json:"token"`
	Intents int64  `json:"intents"`
}

type ResumeData struct {
	Token     string `json:"token"`
	SessionID string `json:"session_id"`
	Seq       int64  `json:"seq"`
}

type ReadyData struct {
	V         int      `json:"v"`
	User      BotUser  `json:"user"`
	Guilds    []string `json:"guilds"`
	SessionID string   `json:"session_id"`
}

type BotUser struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Bot      bool   `json:"bot"`
}

type EventPayload struct {
	Sequence int64           `json:"s"`
	Type     string          `json:"t"`
	Data     json.RawMessage `json:"d"`
}
