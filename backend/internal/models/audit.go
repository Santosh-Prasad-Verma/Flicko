package models

import "time"

type AuditLogAction string

const (
	ActionMemberKick                AuditLogAction = "member_kick"
	ActionMemberBan                 AuditLogAction = "member_ban"
	ActionMemberUnban               AuditLogAction = "member_unban"
	ActionRoleCreate                AuditLogAction = "role_create"
	ActionRoleUpdate                AuditLogAction = "role_update"
	ActionRoleDelete                AuditLogAction = "role_delete"
	ActionChannelCreate             AuditLogAction = "channel_create"
	ActionChannelUpdate             AuditLogAction = "channel_update"
	ActionChannelDelete             AuditLogAction = "channel_delete"
	ActionMessageDelete             AuditLogAction = "message_delete"
	ActionMessageBulkDelete         AuditLogAction = "message_bulk_delete"
	ActionMemberRoleUpdate          AuditLogAction = "member_role_update"
	ActionPermissionOverwriteCreate AuditLogAction = "permission_overwrite_create"
	ActionPermissionOverwriteUpdate AuditLogAction = "permission_overwrite_update"
	ActionPermissionOverwriteDelete AuditLogAction = "permission_overwrite_delete"
	ActionMessageCrosspost          AuditLogAction = "message_crosspost"
	ActionServerCreate              AuditLogAction = "server_create"
	ActionServerUpdate              AuditLogAction = "server_update"
	ActionServerDelete              AuditLogAction = "server_delete"
	ActionMemberJoin                AuditLogAction = "member_join"
	ActionMemberLeave               AuditLogAction = "member_leave"
)

type AuditLog struct {
	ID         string         `json:"id" db:"id"`
	ServerID   string         `json:"server_id" db:"server_id"`
	ActorID    *string        `json:"actor_id,omitempty" db:"actor_id"` // null for system actions
	ActionType AuditLogAction `json:"action_type" db:"action_type"`
	TargetType string         `json:"target_type" db:"target_type"`
	TargetID   *string        `json:"target_id,omitempty" db:"target_id"`
	Reason     *string        `json:"reason,omitempty" db:"reason"`
	Changes    any            `json:"changes,omitempty" db:"changes"`
	CreatedAt  time.Time      `json:"created_at" db:"created_at"`
}
