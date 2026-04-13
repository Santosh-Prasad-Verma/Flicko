package auth

import (
"errors"
"log/slog"
)

// Permission represents a capability in the system
type Permission string

const (
// Guild permissions
ManageGuilds   Permission = "MANAGE_GUILDS"
ManageChannels Permission = "MANAGE_CHANNELS"
ManageRoles    Permission = "MANAGE_ROLES"
ManageMessages Permission = "MANAGE_MESSAGES"

// Member permissions
Moderate        Permission = "MODERATE"
DeleteMessages  Permission = "DELETE_OTHER_MESSAGES"
PinMessages     Permission = "PIN_MESSAGES"
MuteMembers     Permission = "MUTE_MEMBERS"
)

// SecurityLog is a wrapper for audit logging authorization decisions
func SecurityLog(msg string, level string, fields ...interface{}) {
switch level {
case "warn":
slog.Warn(msg, fields...)
case "error":
slog.Error(msg, fields...)
default:
slog.Info(msg, fields...)
}
}

// HasPermission checks if a member's roles contain a specific permission
func HasPermission(memberRoles []string, requiredPerm Permission) bool {
permMap := permissionMap()

if len(memberRoles) == 0 {
return false
}

for _, role := range memberRoles {
if permissions, ok := permMap[role]; ok {
for _, perm := range permissions {
if perm == requiredPerm {
return true
}
}
}
}
return false
}

// IsGuildOwner checks if user is the guild owner
func IsGuildOwner(guildOwnerID, userID string) bool {
return guildOwnerID == userID
}

// IsMessageAuthor checks if user is the message author
func IsMessageAuthor(messageAuthorID, userID string) bool {
return messageAuthorID == userID
}

// CanEditChannel verifies caller can edit a channel
func CanEditChannel(guildOwnerID, callerID string, callerRoles []string) bool {
// Allowed: Guild owner, users with MANAGE_CHANNELS role
return IsGuildOwner(guildOwnerID, callerID) || HasPermission(callerRoles, ManageChannels)
}

// CanDeleteChannel verifies caller can delete a channel
func CanDeleteChannel(guildOwnerID, callerID string, callerRoles []string) bool {
// Allowed: Guild owner, users with MANAGE_CHANNELS role
return IsGuildOwner(guildOwnerID, callerID) || HasPermission(callerRoles, ManageChannels)
}

// CanDeleteMessage verifies caller can delete a message
func CanDeleteMessage(messageAuthorID, guildOwnerID, callerID string, callerRoles []string) bool {
// Allowed: Message author, guild owner, users with DELETE_OTHER_MESSAGES or MODERATE
if IsMessageAuthor(messageAuthorID, callerID) {
return true // Message author can always delete their own message
}
if IsGuildOwner(guildOwnerID, callerID) {
return true // Guild owner can delete any message
}
// Users with DELETE_OTHER_MESSAGES or MODERATE permission
return HasPermission(callerRoles, DeleteMessages) || HasPermission(callerRoles, Moderate)
}

// CanAddMemberToGuild verifies caller can add users to guild
func CanAddMemberToGuild(guildOwnerID, callerID, targetUserID string, callerRoles []string) (bool, error) {
// For now: Only allow self-join (body.UserID must be empty or match caller)
// Allowed: Only caller adding themselves, OR guild owner/admin using command with permission
if targetUserID != "" && targetUserID != callerID {
// Prevent arbitrary user addition via API
if !IsGuildOwner(guildOwnerID, callerID) && !HasPermission(callerRoles, ManageGuilds) {
SecurityLog("unauthorized guild member addition attempted",
"warn",
"caller_id", callerID,
"target_user_id", targetUserID,
"guild_owner", guildOwnerID,
)
return false, errors.New("only guild owner can add members")
}
}
return true, nil
}

// permissionMap returns role -> permissions mapping
func permissionMap() map[string][]Permission {
return map[string][]Permission{
"owner": {
ManageGuilds,
ManageChannels,
ManageRoles,
ManageMessages,
Moderate,
DeleteMessages,
PinMessages,
MuteMembers,
},
"admin": {
ManageGuilds,
ManageChannels,
ManageRoles,
ManageMessages,
Moderate,
DeleteMessages,
PinMessages,
MuteMembers,
},
"moderator": {
Moderate,
DeleteMessages,
PinMessages,
MuteMembers,
},
"member": {
// Can edit own messages and read channels (handled separately)
},
}
}
