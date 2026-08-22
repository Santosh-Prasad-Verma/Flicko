package watchtogether

import (
	"time"

	"github.com/google/uuid"
)

type MediaKind string

const (
	MediaKindYouTube  MediaKind = "youtube"
	MediaKindVimeo    MediaKind = "vimeo"
	MediaKindMP4      MediaKind = "mp4"
	MediaKindHLS      MediaKind = "hls"
	MediaKindAppwrite MediaKind = "appwrite"
)

type SessionState string

const (
	StateDraft   SessionState = "draft"
	StateReady   SessionState = "ready"
	StatePlaying SessionState = "playing"
	StatePaused  SessionState = "paused"
	StateEnded   SessionState = "ended"
)

type WTSettings struct {
	MaxViewers         int  `json:"max_viewers"`
	AllowSeekByViewer  bool `json:"allow_seek_by_viewer"`
}

type WTSession struct {
	ID               string       `json:"id"`
	RoomID           uuid.UUID    `json:"room_id"`
	HostUserID       uuid.UUID    `json:"host_user_id"`
	MediaKind        MediaKind    `json:"media_kind"`
	MediaURL         string       `json:"media_url"`
	MediaTitle       *string      `json:"media_title,omitempty"`
	MediaDurationMS  *int         `json:"media_duration_ms,omitempty"`
	Settings         WTSettings   `json:"settings"`
	State            SessionState `json:"state"`
	AnchorPositionMS int          `json:"anchor_position_ms"`
	AnchorPlaying    bool         `json:"anchor_playing"`
	AnchorRate       float64      `json:"anchor_rate"`
	AnchorWallMS     int64        `json:"anchor_wall_ms"`
	Seq              int          `json:"seq"`
	IsStandalone     bool         `json:"is_standalone"`
	IsPublic         bool         `json:"is_public"`
	LobbyName        *string      `json:"lobby_name,omitempty"`
	CreatedAt        time.Time    `json:"created_at"`
	UpdatedAt        time.Time    `json:"updated_at"`
	EndedAt          *time.Time   `json:"ended_at,omitempty"`
	LastActiveAt     time.Time    `json:"last_active_at"`
}

type WTParticipant struct {
	ID          int64      `json:"id"`
	SessionID   string     `json:"session_id"`
	UserID      uuid.UUID  `json:"user_id"`
	Role        string     `json:"role"` // 'host' or 'viewer'
	JoinedAt    time.Time  `json:"joined_at"`
	LeftAt      *time.Time `json:"left_at,omitempty"`
	LastDriftMS int        `json:"last_drift_ms"`
}

type WTReaction struct {
	ID         int64     `json:"id"`
	SessionID  string    `json:"session_id"`
	UserID     uuid.UUID `json:"user_id"`
	Emoji      string    `json:"emoji"`
	PositionMS int       `json:"position_ms"`
	CreatedAt  time.Time `json:"created_at"`
}

// REST Requests & Responses

type CreateSessionRequest struct {
	RoomID     string     `json:"room_id"`
	Media      MediaInput `json:"media"`
	Settings   WTSettings `json:"settings"`
	IsPublic   bool       `json:"is_public"`
	LobbyName  string     `json:"lobby_name"`
}

type MediaInput struct {
	Kind  MediaKind `json:"kind"`
	URL   string    `json:"url"`
	Title string    `json:"title"`
}

type JoinSessionResponse struct {
	Session    *WTSession `json:"session"`
	VoiceToken string     `json:"voice_token"`
}

type TransferHostRequest struct {
	ToUserID string `json:"to_user_id"`
}

type PushAnchorRequest struct {
	PositionMS int  `json:"position_ms"`
	Playing    bool `json:"playing"`
	Rate       float64 `json:"rate"`
}

type WTSessionAnchor struct {
	PositionMS  int     `json:"position_ms"`
	Playing     bool    `json:"playing"`
	Rate        float64 `json:"rate"`
	WallClockMS int64   `json:"wall_clock_ms"`
	Seq         int     `json:"seq"`
}


type SyncFrame struct {
	Version      int          `json:"v"`
	Type         string       `json:"type"` // "anchor" | "reaction" | "heartbeat"
	SessionID    string       `json:"session_id"`
	HostID       string       `json:"host_id"`
	PositionMS   int          `json:"position_ms"`
	Playing      bool         `json:"playing"`
	Rate         float64      `json:"rate"`
	WallClockMS  int64        `json:"wall_clock_ms"`
	Seq          int          `json:"seq"`
}
