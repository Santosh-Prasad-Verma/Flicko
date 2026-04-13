package models

import "time"

type FriendRequestStatus string

const (
	FriendRequestPending  FriendRequestStatus = "pending"
	FriendRequestAccepted FriendRequestStatus = "accepted"
	FriendRequestDeclined FriendRequestStatus = "declined"
)

type FriendRequest struct {
	ID          string              `json:"id" db:"id"`
	SenderID    string              `json:"sender_id" db:"sender_id"`
	ReceiverID  string              `json:"receiver_id" db:"receiver_id"`
	Message     *string             `json:"message,omitempty" db:"message"`
	Status      FriendRequestStatus `json:"status" db:"status"`
	CreatedAt   time.Time           `json:"created_at" db:"created_at"`
	RespondedAt *time.Time          `json:"responded_at,omitempty" db:"responded_at"`
}

type Friendship struct {
	UserID    string    `json:"user_id" db:"user_id"`
	FriendID  string    `json:"friend_id" db:"friend_id"`
	Nickname  *string   `json:"nickname,omitempty" db:"nickname"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type Block struct {
	BlockerID string    `json:"blocker_id" db:"blocker_id"`
	BlockedID string    `json:"blocked_id" db:"blocked_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
