package protocol

import "encoding/json"

// GatewayMessage is the top-level wire format for every WebSocket frame.
// Both client→server and server→client messages share this envelope.
type GatewayMessage struct {
	// Op is the operation code identifying the message type.
	Op OpCode `json:"op"`

	// D is the lazily-decoded payload. Use DecodePayload to extract.
	D json.RawMessage `json:"d"`

	// S is the sequence number for resumable sessions.
	// Only present on server→client dispatch messages (Op=0).
	S int64 `json:"s,omitempty"`

	// T is the event type name (e.g., "MESSAGE_CREATE", "MEMBER_UPDATE").
	// Only present on dispatch messages (Op=0).
	T string `json:"t,omitempty"`

	// N is the client-generated nonce for idempotency.
	// Sent by clients on OpMessageCreate, echoed back on OpMessageAck.
	N string `json:"n,omitempty"`
}

// IdentifyPayload is sent by the client immediately after WebSocket open.
// The gateway validates the JWT token and responds with OpReady or OpError.
type IdentifyPayload struct {
	// Token is the JWT access token (Supabase-issued, Ed25519-signed).
	Token string `json:"token"`

	// SessionID allows a disconnecting client to resume previous subscriptions.
	SessionID string `json:"session_id,omitempty"`

	// DeviceID is a unique identifier for the user's device/session (for presence).
	DeviceID string `json:"device_id"`
}

// MessagePayload represents a chat message sent or received.
type MessagePayload struct {
	// ID is the server-assigned ULID (set on outbound dispatch, empty on inbound).
	ID string `json:"id,omitempty"`

	// ChannelID is the target channel.
	ChannelID string `json:"channel_id"`

	// AuthorID is the sender's user ID (set server-side, ignored on inbound).
	AuthorID string `json:"author_id,omitempty"`

	// Content is the message text (max 4000 chars, enforced by gateway).
	Content string `json:"content"`

	// Nonce is a client-generated idempotency key (max 64 chars).
	Nonce string `json:"nonce"`

	// Timestamp is Unix milliseconds (set server-side).
	Timestamp int64 `json:"timestamp,omitempty"`

	// Attachments is an optional list of attachment metadata.
	Attachments []Attachment `json:"attachments,omitempty"`
}

// Attachment represents a file attached to a message.
type Attachment struct {
	// ID is the attachment identifier.
	ID string `json:"id"`

	// Filename is the original file name.
	Filename string `json:"filename"`

	// ContentType is the MIME type.
	ContentType string `json:"content_type"`

	// Size is the file size in bytes.
	Size int64 `json:"size"`

	// URL is the download URL (presigned B2/S3 URL).
	URL string `json:"url"`
}

// TypingPayload indicates a user started typing in a channel.
type TypingPayload struct {
	// ChannelID where typing is happening.
	ChannelID string `json:"channel_id"`

	// UserID of the typing user.
	UserID string `json:"user_id,omitempty"`

	// Timestamp is Unix milliseconds when typing started.
	Timestamp int64 `json:"timestamp"`
}

// PresencePayload represents a user's online status.
type PresencePayload struct {
	// UserID whose presence changed.
	UserID string `json:"user_id"`

	// Status is one of: "online", "idle", "dnd", "offline".
	Status string `json:"status"`

	// LastSeen is Unix milliseconds of the last activity.
	LastSeen int64 `json:"last_seen,omitempty"`
}

// ChannelSubPayload is used for OpChannelSub and OpChannelUnsub.
type ChannelSubPayload struct {
	// ChannelID to subscribe/unsubscribe.
	ChannelID string `json:"channel_id"`
}

// ErrorPayload is sent by the server on OpError.
type ErrorPayload struct {
	// Code is a machine-readable close code (e.g., 4001 for invalid payload).
	Code int `json:"code"`

	// Message is a human-readable error description.
	Message string `json:"message"`

	// Retry indicates whether the client should retry the operation.
	Retry bool `json:"retry"`
}

// AckPayload is sent by the server on OpMessageAck.
type AckPayload struct {
	// Nonce is the client-generated nonce echoed back.
	Nonce string `json:"nonce"`

	// MessageID is the server-assigned ULID for the created message.
	MessageID string `json:"message_id"`
}

// ReadyPayload - Server → Client (OpReady).
type ReadyPayload struct {
	// SessionID allows a disconnecting client to resume previous subscriptions.
	SessionID string `json:"session_id"`

	// UserID is the authenticated user's ID.
	UserID string `json:"user_id"`

	// Guilds is the list of guild IDs the user belongs to.
	Guilds []string `json:"guilds"`

	// ResumeURL is the endpoint to reconnect to for session resume.
	ResumeURL string `json:"resume_url,omitempty"`
}
