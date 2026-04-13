package models

import "time"

type NotificationSettings struct {
	Desktop bool `json:"desktop"`
	Mobile  bool `json:"mobile"`
	Email   bool `json:"email"`
	Sounds  bool `json:"sounds"`
}

type PrivacySettings struct {
	AllowDMsFromServerMembers bool `json:"allow_dms_from_server_members"`
	ShowActivityStatus        bool `json:"show_activity_status"`
}

type UserSettings struct {
	UserID               string               `json:"user_id" db:"user_id"`
	Theme                string               `json:"theme" db:"theme"`
	NotificationSettings NotificationSettings `json:"notification_settings" db:"notification_settings"`
	PrivacySettings      PrivacySettings      `json:"privacy_settings" db:"privacy_settings"`
	CreatedAt            time.Time            `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time            `json:"updated_at" db:"updated_at"`
}
