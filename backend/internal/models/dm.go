package models

import "time"

type GroupDM struct {
	ID        string    `json:"id" db:"id"`
	Name      *string   `json:"name" db:"name"`
	Icon      *string   `json:"icon" db:"icon"`
	OwnerID   string    `json:"owner_id" db:"owner_id"`
	IsActive  bool      `json:"is_active" db:"is_active"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

type GroupDMParticipant struct {
	GroupDMID string    `json:"group_dm_id" db:"group_dm_id"`
	UserID    string    `json:"user_id" db:"user_id"`
	JoinedAt  time.Time `json:"joined_at" db:"joined_at"`
}

type DMMessageType string

const (
	DMMsgDefault DMMessageType = "default"
	DMMsgSystem  DMMessageType = "system"
	DMMsgReply   DMMessageType = "reply"
)

type DMMessage struct {
	ID             string        `json:"id" db:"id"`
	ConversationID string        `json:"conversation_id" db:"conversation_id"` // Matches a GroupDM ID
	AuthorID       string        `json:"author_id" db:"author_id"`
	Content        string        `json:"content" db:"content"`
	Type           DMMessageType `json:"type" db:"type"`
	ReplyToID      *string       `json:"reply_to_id,omitempty" db:"reply_to_id"`
	EditedAt       *time.Time    `json:"edited_at,omitempty" db:"edited_at"`
	CreatedAt      time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time     `json:"updated_at" db:"updated_at"`
}

type DMReadState struct {
	ConversationID    string    `json:"conversation_id" db:"conversation_id"`
	UserID            string    `json:"user_id" db:"user_id"`
	LastReadMessageID *string   `json:"last_read_message_id,omitempty" db:"last_read_message_id"`
	LastReadAt        time.Time `json:"last_read_at" db:"last_read_at"`
}
