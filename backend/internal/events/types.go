package events

import (
	"time"
)

// EventType identifies the kind of event flowing through the bus.
type EventType string

const (
	// Message events
	MessageCreate EventType = "MESSAGE_CREATE"
	MessageUpdate EventType = "MESSAGE_UPDATE"
	MessageDelete EventType = "MESSAGE_DELETE"

	// Member events
	MemberJoin  EventType = "MEMBER_JOIN"
	MemberLeave EventType = "MEMBER_LEAVE"
	MemberBan   EventType = "MEMBER_BAN"
	MemberUnban EventType = "MEMBER_UNBAN"
	MemberKick  EventType = "MEMBER_KICK"

	// Reaction events
	ReactionAdd    EventType = "REACTION_ADD"
	ReactionRemove EventType = "REACTION_REMOVE"

	// Command events
	CommandInvoke    EventType = "COMMAND_INVOKE"
	ButtonClick      EventType = "BUTTON_CLICK"
	SelectMenuSubmit EventType = "SELECT_MENU_SUBMIT"
	ModalSubmit      EventType = "MODAL_SUBMIT"

	// Channel events
	ChannelCreate EventType = "CHANNEL_CREATE"
	ChannelUpdate EventType = "CHANNEL_UPDATE"
	ChannelDelete EventType = "CHANNEL_DELETE"

	// Server events
	ServerUpdate EventType = "SERVER_UPDATE"

	// Role events
	RoleCreate       EventType = "ROLE_CREATE"
	RoleUpdate       EventType = "ROLE_UPDATE"
	RoleDelete       EventType = "ROLE_DELETE"
	MemberRoleAdd    EventType = "MEMBER_ROLE_ADD"
	MemberRoleRemove EventType = "MEMBER_ROLE_REMOVE"

	// Voice events
	VoiceJoin  EventType = "VOICE_JOIN"
	VoiceLeave EventType = "VOICE_LEAVE"

	// Typing events
	TypingStart EventType = "TYPING_START"

	// Scheduled events
	TickerMinute EventType = "TICKER_MINUTE"
	TickerHour   EventType = "TICKER_HOUR"

	// Music events
	MusicUpdate EventType = "MUSIC_UPDATE"

	// Video/Streaming events
	VideoToggle       EventType = "VIDEO_TOGGLE"
	ScreenShareToggle EventType = "SCREEN_SHARE_TOGGLE"
)

// Event is the core payload flowing through the event bus.
type Event struct {
	ID        string                 `json:"id"`
	Type      EventType              `json:"type"`
	ServerID  string                 `json:"server_id,omitempty"`
	ChannelID string                 `json:"channel_id,omitempty"`
	UserID    string                 `json:"user_id,omitempty"`
	Data      map[string]interface{} `json:"data"`
	Timestamp time.Time              `json:"timestamp"`
}

// MessageData holds parsed data for MESSAGE_CREATE/UPDATE/DELETE events.
type MessageData struct {
	MessageID   string   `json:"message_id"`
	Content     string   `json:"content"`
	AuthorID    string   `json:"author_id"`
	ChannelID   string   `json:"channel_id"`
	ServerID    string   `json:"server_id"`
	Attachments []string `json:"attachments,omitempty"`
	MentionIDs  []string `json:"mention_ids,omitempty"`
}

// MemberData holds parsed data for MEMBER_JOIN/LEAVE events.
type MemberData struct {
	UserID    string `json:"user_id"`
	ServerID  string `json:"server_id"`
	Username  string `json:"username"`
	AvatarURL string `json:"avatar_url,omitempty"`
}

// ReactionData holds parsed data for REACTION_ADD/REMOVE events.
type ReactionData struct {
	MessageID string `json:"message_id"`
	ChannelID string `json:"channel_id"`
	ServerID  string `json:"server_id"`
	UserID    string `json:"user_id"`
	Emoji     string `json:"emoji"`
}

// CommandData holds parsed data for COMMAND_INVOKE events.
type CommandData struct {
	CommandName   string                 `json:"command_name"`
	ServerID      string                 `json:"server_id"`
	ChannelID     string                 `json:"channel_id"`
	UserID        string                 `json:"user_id"`
	Options       map[string]interface{} `json:"options,omitempty"`
	InteractionID string                 `json:"interaction_id"`
}

// ButtonData holds parsed data for BUTTON_CLICK events.
type ButtonData struct {
	CustomID      string `json:"custom_id"`
	ServerID      string `json:"server_id"`
	ChannelID     string `json:"channel_id"`
	UserID        string `json:"user_id"`
	MessageID     string `json:"message_id"`
	InteractionID string `json:"interaction_id"`
}
