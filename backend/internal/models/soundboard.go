package models

import "time"

type SoundboardSound struct {
	ID         string    `json:"id" db:"id"`
	ServerID   string    `json:"server_id" db:"server_id"`
	Name       string    `json:"name" db:"name"`
	Emoji      string    `json:"emoji" db:"emoji"`
	SoundURL   string    `json:"sound_url" db:"sound_url"`
	Duration   float64   `json:"duration" db:"duration"`
	UploadedBy string    `json:"uploaded_by" db:"uploaded_by"`
	PlayCount  int       `json:"play_count" db:"play_count"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

type SoundboardFavorite struct {
	ID        string    `json:"id" db:"id"`
	UserID    string    `json:"user_id" db:"user_id"`
	SoundID   string    `json:"sound_id" db:"sound_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
