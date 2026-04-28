package auth

import (
"strings"
)

// Allowed scopes in Flicko Bot Marketplace implementation
const (
ScopeMessagesWrite = "messages.write"
ScopeMessagesRead  = "messages.read"
ScopeMembersRead   = "members.read"
ScopeGuildsRead    = "guilds.read"
)

var AllScopes = []string{
ScopeMessagesWrite,
ScopeMessagesRead,
ScopeMembersRead,
ScopeGuildsRead,
}

// HasScope generic check
func HasScope(granted []string, required string) bool {
for _, s := range granted {
if strings.EqualFold(s, required) {
return true
}
}
return false
}

// ValidateScopes validates requested scopes against what's permissible globally
func ValidateScopes(requested []string) bool {
validMap := map[string]bool{}
for _, s := range AllScopes {
validMap[s] = true
}

for _, req := range requested {
if !validMap[req] {
return false
}
}
return true
}
