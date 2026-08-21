// Package models defines data structures shared across the mail gateway.
package models

// AuthHookPayload represents the JSON body sent by Auth webhooks.
// Supports BOTH formats:
//   - Standard Webhook format: { type, user, data }
//   - Auth Hook (send_email) format: { user, email_data } where type is in email_data.email_action_type
type AuthHookPayload struct {
	// Type is the email event type: "signup", "recovery", "magiclink", "email_change"
	// May be empty in Auth Hook format (derived from EmailData.EmailActionType).
	Type string `json:"type"`

	// User contains the target user's basic info
	User HookUser `json:"user"`

	// Data contains tokens and URLs needed to build the action link (Standard Webhook format)
	Data HookData `json:"data"`

	// EmailData contains tokens and URLs in the Auth Hook (send_email) format.
	// When present, Normalize() copies these values into Data and Type.
	EmailData HookData `json:"email_data"`
}

// SupabaseHookPayload is an alias for backwards compatibility.
type SupabaseHookPayload = AuthHookPayload

// HookUser represents the user object within the webhook payload.
type HookUser struct {
	// ID is the user UUID
	ID string `json:"id"`

	// Email is the user's email address — the recipient of the email
	Email string `json:"email"`

	// UserMetadata contains custom data set during signUp (e.g. username, display_name).
	UserMetadata map[string]interface{} `json:"user_metadata,omitempty"`
}

// DisplayName extracts the best display name from user metadata.
// Priority: username > display_name > email prefix > email.
func (u HookUser) DisplayName() string {
	if u.UserMetadata != nil {
		if username, ok := u.UserMetadata["username"].(string); ok && username != "" {
			return username
		}
		if displayName, ok := u.UserMetadata["display_name"].(string); ok && displayName != "" {
			return displayName
		}
	}
	// Fallback: email prefix (everything before @)
	for i, c := range u.Email {
		if c == '@' {
			return u.Email[:i]
		}
	}
	return u.Email
}

// HookData contains the token and redirect information.
// The Auth Hook (send_email) format includes a pre-built ConfirmationURL
// that should be used directly instead of building the URL manually.
type HookData struct {
	// Token is the raw confirmation/reset token (used in some flows)
	Token string `json:"token"`

	// TokenHash is the hashed token used in verification URLs
	TokenHash string `json:"token_hash"`

	// RedirectTo is the URL to redirect the user to after verification
	RedirectTo string `json:"redirect_to"`

	// EmailActionType mirrors the parent Type field for additional routing context
	EmailActionType string `json:"email_action_type"`

	// SiteURL is the application's base URL
	SiteURL string `json:"site_url"`

	// ConfirmationURL is the pre-built verification URL provided by Auth Hooks.
	// When present, this should be used as the action link instead of building one manually.
	ConfirmationURL string `json:"confirmation_url"`
}

// Normalize unifies both webhook payload formats into a single canonical form.
// Call this BEFORE Validate().
//
// Auth Hook format has no top-level "type" — it's inside email_data.email_action_type.
// Auth Hook format uses "email_data" instead of "data".
func (p *AuthHookPayload) Normalize() {
	// Auth Hook format: type lives inside email_data.email_action_type
	if p.Type == "" && p.EmailData.EmailActionType != "" {
		p.Type = p.EmailData.EmailActionType
	}

	// Auth Hook format: tokens are in email_data, not data
	if (p.Data.TokenHash == "" && p.Data.Token == "") &&
		(p.EmailData.TokenHash != "" || p.EmailData.Token != "") {
		p.Data = p.EmailData
	}
}

// Validate checks that the payload contains all required fields.
// Returns an error describing what's missing.
// Call Normalize() first to handle both webhook formats.
func (p *AuthHookPayload) Validate() error {
	if p.Type == "" {
		return ErrMissingType
	}
	if p.User.Email == "" {
		return ErrMissingEmail
	}
	// Auth Hook payloads may have confirmation_url without separate tokens
	if p.Data.TokenHash == "" && p.Data.Token == "" && p.Data.ConfirmationURL == "" {
		return ErrMissingToken
	}
	return nil
}

// IsKnownType returns true if the event type is one we handle.
func (p *AuthHookPayload) IsKnownType() bool {
	switch p.Type {
	case "signup", "recovery", "magiclink", "email_change", "invite", "reauthentication":
		return true
	default:
		return false
	}
}
