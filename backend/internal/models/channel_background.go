package models

import "time"

type ChannelBackground struct {
	ID              string    `json:"id" db:"id"`
	ChannelID       string    `json:"channel_id" db:"channel_id"`
	ServerID        string    `json:"server_id" db:"server_id"`
	UploaderID      *string   `json:"uploader_id,omitempty" db:"uploader_id"`
	FileIDOriginal  string    `json:"file_id_original" db:"file_id_original"`
	FileIDMobile    *string   `json:"file_id_mobile,omitempty" db:"file_id_mobile"`
	FileIDBlurred   *string   `json:"file_id_blurred,omitempty" db:"file_id_blurred"`
	BlurHash        string    `json:"blurhash" db:"blurhash"`
	WidthPx         int       `json:"width_px" db:"width_px"`
	HeightPx        int       `json:"height_px" db:"height_px"`
	BytesOriginal   int       `json:"bytes_original" db:"bytes_original"`
	MimeType        string    `json:"mime_type" db:"mime_type"`
	Sha256          string    `json:"sha256" db:"sha256"`
	DominantColor   string    `json:"dominant_color" db:"dominant_color"`
	MeanLuminance   float32   `json:"mean_luminance" db:"mean_luminance"`
	MinTextContrast *float32  `json:"min_text_contrast,omitempty" db:"min_text_contrast"`
	FocalX          float32   `json:"focal_x" db:"focal_x"`
	FocalY          float32   `json:"focal_y" db:"focal_y"`
	Status          string    `json:"status" db:"status"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

type ChannelBackgroundUserOverride struct {
	UserID    string    `json:"user_id" db:"user_id"`
	ChannelID string    `json:"channel_id" db:"channel_id"`
	Opacity   float32   `json:"opacity" db:"opacity"`
	Enabled   bool      `json:"enabled" db:"enabled"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
