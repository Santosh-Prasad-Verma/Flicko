package ratelimit

import "time"

// Tier defines a named rate-limit configuration.
type Tier struct {
	Name   string
	Limit  int
	Window time.Duration
}

// Pre-defined tiers from the Flicko production architecture.
var (
	// TierAPIGeneral is the default tier for authenticated API calls.
	TierAPIGeneral = Tier{Name: "api_general", Limit: 50, Window: 1 * time.Second}

	// TierMessageCreate is the tier for message creation (5 messages per 10 seconds).
	TierMessageCreate = Tier{Name: "msg_create", Limit: 5, Window: 10 * time.Second}

	// TierAuth is the tier for authentication endpoints (per IP).
	TierAuth = Tier{Name: "auth", Limit: 5, Window: 1 * time.Minute}

	// TierWSConnect is the tier for WebSocket connect attempts (per IP).
	TierWSConnect = Tier{Name: "ws_connect", Limit: 5, Window: 1 * time.Second}

	// TierUpload is the tier for presigned upload URLs.
	TierUpload = Tier{Name: "upload", Limit: 2, Window: 1 * time.Second}

	// TierGuildJoin is the tier for guild join operations.
	TierGuildJoin = Tier{Name: "guild_join", Limit: 10, Window: 1 * time.Hour}
)

// Key builds the full rate-limit key for a tier. Example:
//
// TierAPIGeneral.Key("user123") → "api_general:user123"
func (t Tier) Key(identity string) string {
	return t.Name + ":" + identity
}
