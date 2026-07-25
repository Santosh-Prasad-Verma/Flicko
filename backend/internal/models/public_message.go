package models

import "time"

// AstraPublicMessage represents a denormalized high-throughput public chat message stored in Astra DB
type AstraPublicMessage struct {
	ID           string    `json:"_id"`
	ChannelID    string    `json:"channel_id"`
	AuthorID     string    `json:"author_id"`
	AuthorName   string    `json:"author_name"`
	AuthorAvatar string    `json:"author_avatar"`
	Content      string    `json:"content"`
	Vectorize    string    `json:"$vectorize,omitempty"`
	Vector       []float32 `json:"$vector,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
