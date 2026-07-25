package musicparty

import (
	"time"

	"github.com/google/uuid"
)

// ── Session State ──────────────────────────────────────────────

type SessionState string

const (
	StateDraft    SessionState = "draft"
	StateReady    SessionState = "ready"
	StatePlaying  SessionState = "playing"
	StatePaused   SessionState = "paused"
	StateEnded    SessionState = "ended"
	StateDegraded SessionState = "degraded"
)

// ── Rotation Mode ──────────────────────────────────────────────

type RotationMode string

const (
	RotationManual      RotationMode = "manual"
	RotationRoundRobin  RotationMode = "round_robin"
	RotationListenerVote RotationMode = "listener_vote"
)

// ── Participant Role ───────────────────────────────────────────

type ParticipantRole string

const (
	RoleDJ       ParticipantRole = "dj"
	RoleListener ParticipantRole = "listener"
)

// ── Spotify Tier ───────────────────────────────────────────────

type SpotifyTier string

const (
	TierPremium SpotifyTier = "premium"
	TierFree    SpotifyTier = "free"
	TierNone    SpotifyTier = "none"
)

// ── Queue Item State ───────────────────────────────────────────

type QueueItemState string

const (
	QueueStateQueued    QueueItemState = "queued"
	QueueStatePlaying   QueueItemState = "playing"
	QueueStateCompleted QueueItemState = "completed"
	QueueStateSkipped   QueueItemState = "skipped"
	QueueStateRemoved   QueueItemState = "removed"
)

// ── Vibe Kind ──────────────────────────────────────────────────

type VibeKind string

const (
	VibeHeart    VibeKind = "heart"
	VibeFire     VibeKind = "fire"
	VibeStar     VibeKind = "star"
	VibeSkipVote VibeKind = "skip_vote"
)

// ── Domain Models ──────────────────────────────────────────────

type MPSettings struct {
	VoteSkipThreshold float64 `json:"vote_skip_threshold"`
	MaxListeners      int     `json:"max_listeners"`
	AllowDupes        bool    `json:"allow_dupes"`
}

type MPSession struct {
	ID               string       `json:"id"`
	RoomID           uuid.UUID    `json:"room_id"`
	DJUserID         uuid.UUID    `json:"dj_user_id"`
	NextDJUserID     *uuid.UUID   `json:"next_dj_user_id,omitempty"`
	RotationMode     RotationMode `json:"rotation_mode"`
	State            SessionState `json:"state"`
	CurrentTrackURI  *string      `json:"current_track_uri,omitempty"`
	CurrentPositionMS int         `json:"current_position_ms"`
	CurrentStartedAt *time.Time   `json:"current_started_at,omitempty"`
	AnchorWallMS     int64        `json:"anchor_wall_ms"`
	Seq              int          `json:"seq"`
	Settings         MPSettings   `json:"settings"`
	CreatedAt        time.Time    `json:"created_at"`
	UpdatedAt        time.Time    `json:"updated_at"`
	EndedAt          *time.Time   `json:"ended_at,omitempty"`
	LastActiveAt     time.Time    `json:"last_active_at"`
}

type MPParticipant struct {
	ID         int64           `json:"id"`
	SessionID  string          `json:"session_id"`
	UserID     uuid.UUID       `json:"user_id"`
	Role       ParticipantRole `json:"role"`
	SpotifyTier *SpotifyTier   `json:"spotify_tier,omitempty"`
	JoinedAt   time.Time       `json:"joined_at"`
	LeftAt     *time.Time      `json:"left_at,omitempty"`
}

type MPQueueItem struct {
	ID            string         `json:"id"`
	SessionID     string         `json:"session_id"`
	SpotifyURI    string         `json:"spotify_uri"`
	Title         *string        `json:"title,omitempty"`
	Artist        *string        `json:"artist,omitempty"`
	DurationMS    *int           `json:"duration_ms,omitempty"`
	AlbumArtURL   *string        `json:"album_art_url,omitempty"`
	PreviewURL    *string        `json:"preview_url,omitempty"`
	AddedByUserID uuid.UUID      `json:"added_by_user_id"`
	Position      float64        `json:"position"`
	State         QueueItemState `json:"state"`
	CreatedAt     time.Time      `json:"created_at"`
	PlayedAt      *time.Time     `json:"played_at,omitempty"`
	EndedAt       *time.Time     `json:"ended_at,omitempty"`
}

type MPVibe struct {
	ID          int64     `json:"id"`
	SessionID   string    `json:"session_id"`
	QueueItemID *string   `json:"queue_item_id,omitempty"`
	UserID      uuid.UUID `json:"user_id"`
	Kind        VibeKind  `json:"kind"`
	CreatedAt   time.Time `json:"created_at"`
}

// ── REST Requests ──────────────────────────────────────────────

type CreateSessionRequest struct {
	RoomID       string              `json:"room_id"`
	RotationMode string              `json:"rotation_mode"`
	Settings     *CreateSettingsInput `json:"settings,omitempty"`
}

type CreateSettingsInput struct {
	VoteSkipThreshold *float64 `json:"vote_skip_threshold,omitempty"`
	MaxListeners      *int     `json:"max_listeners,omitempty"`
	AllowDupes        *bool    `json:"allow_dupes,omitempty"`
}

type UpdateSessionRequest struct {
	RotationMode      *string  `json:"rotation_mode,omitempty"`
	VoteSkipThreshold *float64 `json:"vote_skip_threshold,omitempty"`
	MaxListeners      *int     `json:"max_listeners,omitempty"`
}

type AddQueueItemRequest struct {
	SpotifyURI  string  `json:"spotify_uri"`
	Title       *string `json:"title,omitempty"`
	Artist      *string `json:"artist,omitempty"`
	DurationMS  *int    `json:"duration_ms,omitempty"`
	AlbumArtURL *string `json:"album_art_url,omitempty"`
	PreviewURL  *string `json:"preview_url,omitempty"`
}

type ReorderQueueItemRequest struct {
	Position float64 `json:"position"`
}

type PushAnchorRequest struct {
	TrackURI   string `json:"track_uri"`
	PositionMS int    `json:"position_ms"`
	Playing    bool   `json:"playing"`
}

type HandoffDJRequest struct {
	ToUserID string `json:"to_user_id"`
}

type SkipRequest struct {
	Reason string `json:"reason"` // "dj", "vote", "ended", "unavailable"
}

type VibeRequest struct {
	QueueItemID string `json:"queue_item_id"`
	Kind        string `json:"kind"` // "heart", "fire", "star", "skip_vote"
}

type JoinRequest struct {
	SpotifyTier string `json:"spotify_tier"` // "premium", "free", "none"
}

// ── REST Responses ─────────────────────────────────────────────

type JoinSessionResponse struct {
	Session      *MPSession    `json:"session"`
	Queue        []*MPQueueItem `json:"queue"`
	Anchor       *AnchorState  `json:"anchor,omitempty"`
	LiveKitToken string        `json:"livekit_token"`
}

type AnchorState struct {
	TrackURI    string `json:"track_uri"`
	PositionMS  int    `json:"position_ms"`
	Playing     bool   `json:"playing"`
	WallClockMS int64  `json:"wall_clock_ms"`
	Seq         int    `json:"seq"`
	DJID        string `json:"dj_id"`
}

type SkipVoteStatus struct {
	CurrentVotes int     `json:"current_votes"`
	Threshold    float64 `json:"threshold"`
	TotalVoters  int     `json:"total_voters"`
	Reached      bool    `json:"reached"`
}

// ── LiveKit Data Channel ───────────────────────────────────────

type SyncFrame struct {
	Version   int    `json:"v"`
	Type      string `json:"type"` // "anchor", "skip", "reaction", "queue_update", "dj_changed", "track_change"
	SessionID string `json:"session_id"`
	TrackURI  string `json:"track_uri,omitempty"`
	PositionMS int   `json:"position_ms,omitempty"`
	Playing   bool   `json:"playing,omitempty"`
	WallClockMS int64 `json:"wall_clock_ms,omitempty"`
	DJID      string `json:"dj_id,omitempty"`
	Seq       int    `json:"seq"`
	// Extra fields for specific frame types
	Reason    string `json:"reason,omitempty"`    // for skip
	VibeKind  string `json:"vibe_kind,omitempty"` // for reaction
	UserID    string `json:"user_id,omitempty"`   // for reaction/dj_changed
}
