package models

import (
	"errors"
	"time"
)

type Server struct {
	ID          string    `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	OwnerID     string    `json:"owner_id" db:"owner_id"`
	IconURL     string    `json:"icon_url" db:"icon_url"`
	BannerURL   string    `json:"banner_url" db:"banner_url"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type Member struct {
	ID       string    `json:"id" db:"id"`
	ServerID string    `json:"server_id" db:"server_id"`
	UserID   string    `json:"user_id" db:"user_id"`
	Nickname string    `json:"nickname" db:"nickname"`
	JoinedAt time.Time `json:"joined_at" db:"joined_at"`
}

type ServerTemplate struct {
	Code           string    `json:"code" db:"code"`
	SourceServerID string    `json:"source_server_id" db:"source_server_id"`
	CreatorID      string    `json:"creator_id" db:"creator_id"`
	Name           string    `json:"name" db:"name"`
	Description    *string   `json:"description,omitempty" db:"description"`
	UsageCount     int       `json:"usage_count" db:"usage_count"`
	TemplateData   any       `json:"template_data" db:"template_data"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

func (s *Server) Validate() error {
	if len(s.Name) < 1 || len(s.Name) > 100 {
		return errors.New("server name must be between 1 and 100 characters")
	}
	return nil
}
