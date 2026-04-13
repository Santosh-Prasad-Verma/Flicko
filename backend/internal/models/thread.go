package models

import "time"

type ThreadType string

const (
	ThreadPublic       ThreadType = "public"
	ThreadPrivate      ThreadType = "private"
	ThreadAnnouncement ThreadType = "announcement"
)

type Thread struct {
	ID                  string     `json:"id" db:"id"`
	ServerID            string     `json:"server_id" db:"server_id"`
	ParentChannelID     string     `json:"parent_channel_id" db:"parent_channel_id"`
	ParentMessageID     *string    `json:"parent_message_id,omitempty" db:"parent_message_id"`
	Name                string     `json:"name" db:"name"`
	CreatorID           string     `json:"creator_id" db:"creator_id"`
	Type                ThreadType `json:"type" db:"type"`
	MessageCount        int        `json:"message_count" db:"message_count"`
	MemberCount         int        `json:"member_count" db:"member_count"`
	IsArchived          bool       `json:"is_archived" db:"is_archived"`
	AutoArchiveDuration string     `json:"auto_archive_duration" db:"auto_archive_duration"` // e.g. "24 hours" postgres interval string
	ArchiveAt           time.Time  `json:"archive_at" db:"archive_at"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
}

type ThreadMember struct {
	ThreadID             string                 `json:"thread_id" db:"thread_id"`
	UserID               string                 `json:"user_id" db:"user_id"`
	JoinedAt             time.Time              `json:"joined_at" db:"joined_at"`
	LastReadMessageID    *string                `json:"last_read_message_id,omitempty" db:"last_read_message_id"`
	NotificationSettings map[string]interface{} `json:"notification_settings" db:"notification_settings"`
}
