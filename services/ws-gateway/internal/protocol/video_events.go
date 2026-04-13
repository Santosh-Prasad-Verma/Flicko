package protocol

// Video/Stream operation codes — re-exported from shared/protocol.
// See shared/protocol/video_events.go for documentation.

import (
	proto "github.com/flicko-org/flicko/services/shared/protocol"
)

const (
	OpVideoStateUpdate  = proto.OpVideoStateUpdate  // 11 — Bidirectional: video state change
	OpScreenShareStart  = proto.OpScreenShareStart  // 12 — Server → Client: screen share started
	OpScreenShareStop   = proto.OpScreenShareStop   // 13 — Server → Client: screen share stopped
	OpStreamStart       = proto.OpStreamStart       // 14 — Server → Client: Go Live started
	OpStreamEnd         = proto.OpStreamEnd         // 15 — Server → Client: Go Live ended
	OpStreamViewerJoin  = proto.OpStreamViewerJoin  // 16 — Server → Client: viewer joined
	OpStreamViewerLeave = proto.OpStreamViewerLeave // 17 — Server → Client: viewer left
	OpVideoQualityHint  = proto.OpVideoQualityHint  // 18 — Server → Client: quality hint
)

// Re-export payload types for convenience.
type (
	VideoStateUpdatePayload = proto.VideoStateUpdatePayload
	StreamStartPayload      = proto.StreamStartPayload
	StreamEndPayload        = proto.StreamEndPayload
	StreamViewerPayload     = proto.StreamViewerPayload
	VideoQualityHintPayload = proto.VideoQualityHintPayload
)
