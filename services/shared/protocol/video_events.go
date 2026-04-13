package protocol

// Video/Stream-related operation codes.
// These extend the core opcodes (0-10) defined in opcodes.go
// with video, screen sharing, and streaming events.

const (
	// OpVideoStateUpdate — Bidirectional: camera on/off, screen share toggle.
	// Payload: VideoStateUpdatePayload.
	OpVideoStateUpdate OpCode = 11

	// OpScreenShareStart — Server → Client: someone started screen sharing.
	// Payload: VideoStateUpdatePayload.
	OpScreenShareStart OpCode = 12

	// OpScreenShareStop — Server → Client: someone stopped screen sharing.
	// Payload: VideoStateUpdatePayload.
	OpScreenShareStop OpCode = 13

	// OpStreamStart — Server → Client: Go Live started.
	// Payload: StreamStartPayload.
	OpStreamStart OpCode = 14

	// OpStreamEnd — Server → Client: Go Live ended.
	// Payload: StreamEndPayload.
	OpStreamEnd OpCode = 15

	// OpStreamViewerJoin — Server → Client: viewer joined stream.
	// Payload: StreamViewerPayload.
	OpStreamViewerJoin OpCode = 16

	// OpStreamViewerLeave — Server → Client: viewer left stream.
	// Payload: StreamViewerPayload.
	OpStreamViewerLeave OpCode = 17

	// OpVideoQualityHint — Server → Client: suggested quality change (adaptive).
	// Payload: VideoQualityHintPayload.
	OpVideoQualityHint OpCode = 18
)

// ── Payloads ──

// VideoStateUpdatePayload is sent when a user's video/screen-share state changes.
type VideoStateUpdatePayload struct {
	UserID        string `json:"user_id"`
	ChannelID     string `json:"channel_id"`
	VideoEnabled  bool   `json:"video_enabled"`
	ScreenSharing bool   `json:"screen_sharing"`
	CameraFacing  string `json:"camera_facing,omitempty"`
	VideoQuality  string `json:"video_quality,omitempty"`
}

// StreamStartPayload is broadcast when a user starts Go Live.
type StreamStartPayload struct {
	StreamID   string `json:"stream_id"`
	UserID     string `json:"user_id"`
	ChannelID  string `json:"channel_id"`
	Title      string `json:"title"`
	StreamType string `json:"stream_type"`
	MaxQuality string `json:"max_quality"`
}

// StreamEndPayload is broadcast when a stream ends.
type StreamEndPayload struct {
	StreamID  string `json:"stream_id"`
	UserID    string `json:"user_id"`
	ChannelID string `json:"channel_id"`
	Reason    string `json:"reason"` // "ended" | "errored" | "admin_ended"
}

// StreamViewerPayload is broadcast when a viewer joins or leaves a stream.
type StreamViewerPayload struct {
	StreamID    string `json:"stream_id"`
	UserID      string `json:"user_id"`
	ViewerCount int    `json:"viewer_count"`
}

// VideoQualityHintPayload suggests the client change quality (adaptive bitrate).
type VideoQualityHintPayload struct {
	SuggestedQuality string `json:"suggested_quality"` // "low" | "medium" | "high"
	Reason           string `json:"reason"`            // "bandwidth" | "cpu" | "battery"
}
