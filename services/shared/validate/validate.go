// Package validate provides input sanitization and validation helpers
// for user-supplied data. Every string from a client is hostile until
// validated by this package.
//
// Design principle: validate at the boundary (handler layer), once.
// Service and repository layers assume data is already clean.
package validate

import (
	"fmt"
	"net/mail"
	"regexp"
	"strings"
	"unicode/utf8"

	flickoerrors "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
)

// --- Username ---

var usernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]{2,32}$`)

// Username validates a username: 2-32 chars, alphanumeric + underscore.
func Username(s string) error {
	if !usernameRegex.MatchString(s) {
		return flickoerrors.ErrValidation(
			"username must be 2-32 characters, alphanumeric and underscores only",
		)
	}
	return nil
}

// --- Email ---

// Email validates an email address format.
// We intentionally use a simple check (RFC 5322 parsing) rather than
// a regex. The real validation is the confirmation email.
func Email(s string) error {
	if len(s) > 255 {
		return flickoerrors.ErrValidation("email must not exceed 255 characters")
	}
	_, err := mail.ParseAddress(s)
	if err != nil {
		return flickoerrors.ErrValidation("invalid email format")
	}
	return nil
}

// --- Password ---

// Password validates password strength.
// Requirements: min 8 chars, at least 1 uppercase, 1 lowercase, 1 digit.
func Password(s string) error {
	if len(s) < 8 {
		return flickoerrors.ErrValidation("password must be at least 8 characters")
	}
	if len(s) > 128 {
		return flickoerrors.ErrValidation("password must not exceed 128 characters")
	}

	var hasUpper, hasLower, hasDigit bool
	for _, r := range s {
		switch {
		case r >= 'A' && r <= 'Z':
			hasUpper = true
		case r >= 'a' && r <= 'z':
			hasLower = true
		case r >= '0' && r <= '9':
			hasDigit = true
		}
	}

	if !hasUpper {
		return flickoerrors.ErrValidation("password must contain at least one uppercase letter")
	}
	if !hasLower {
		return flickoerrors.ErrValidation("password must contain at least one lowercase letter")
	}
	if !hasDigit {
		return flickoerrors.ErrValidation("password must contain at least one digit")
	}
	return nil
}

// --- Message Content ---

// MessageContent validates and sanitizes message content.
// Returns the sanitized content and an error if invalid.
func MessageContent(s string, maxLen int) (string, error) {
	// Trim whitespace
	s = strings.TrimSpace(s)

	if s == "" {
		return "", flickoerrors.ErrValidation("message content cannot be empty")
	}

	// Check length by rune count (not byte count) — emoji/CJK are multi-byte
	if utf8.RuneCountInString(s) > maxLen {
		return "", flickoerrors.New(
			flickoerrors.CodeMessageTooLong,
			fmt.Sprintf("message content exceeds %d characters", maxLen),
		)
	}

	// Strip null bytes (can break PostgreSQL TEXT columns)
	s = strings.ReplaceAll(s, "\x00", "")

	// Normalize line endings
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\r", "\n")

	// Limit consecutive newlines (anti-spam: giant whitespace messages)
	for strings.Contains(s, "\n\n\n") {
		s = strings.ReplaceAll(s, "\n\n\n", "\n\n")
	}

	return s, nil
}

// --- Channel Name ---

var channelNameRegex = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,99}$`)

// ChannelName validates and normalizes a channel name.
// Auto-lowercases and replaces spaces with hyphens (like Discord).
func ChannelName(s string) (string, error) {
	// Normalize: lowercase, spaces → hyphens
	s = strings.ToLower(strings.TrimSpace(s))
	s = strings.ReplaceAll(s, " ", "-")

	// Remove consecutive hyphens
	for strings.Contains(s, "--") {
		s = strings.ReplaceAll(s, "--", "-")
	}

	if !channelNameRegex.MatchString(s) {
		return "", flickoerrors.ErrValidation(
			"channel name must be 1-100 characters, lowercase alphanumeric, hyphens, and underscores",
		)
	}
	return s, nil
}

// --- Guild Name ---

// GuildName validates a guild/server name.
func GuildName(s string) error {
	s = strings.TrimSpace(s)
	runeCount := utf8.RuneCountInString(s)
	if runeCount < 2 || runeCount > 100 {
		return flickoerrors.ErrValidation("guild name must be 2-100 characters")
	}
	return nil
}

// --- ULID ---

// ULID validates that a string is a valid ULID.
// Use for validating path parameters and request body IDs.
func ULID(s string, fieldName string) error {
	if !id.IsValid(s) {
		return flickoerrors.ErrValidation(fmt.Sprintf("invalid %s: must be a valid ULID", fieldName))
	}
	return nil
}

// --- Nonce ---

// Nonce validates an idempotency nonce.
// Must be a valid ULID (client-generated).
func Nonce(s string) error {
	if s == "" {
		return flickoerrors.ErrMissingField("nonce")
	}
	return ULID(s, "nonce")
}

// --- Pagination ---

// Limit validates and constrains a pagination limit.
// Returns the constrained value within [1, max].
func Limit(requested, defaultVal, max int) int {
	if requested <= 0 {
		return defaultVal
	}
	if requested > max {
		return max
	}
	return requested
}

// --- Content Type ---

// AllowedContentTypes is the set of MIME types allowed for file uploads.
var AllowedContentTypes = map[string]bool{
	"image/jpeg":      true,
	"image/png":       true,
	"image/gif":       true,
	"image/webp":      true,
	"video/mp4":       true,
	"video/webm":      true,
	"audio/mpeg":      true,
	"audio/ogg":       true,
	"application/pdf": true,
}

// ContentType validates a file upload content type.
func ContentType(ct string) error {
	ct = strings.ToLower(strings.TrimSpace(ct))
	if !AllowedContentTypes[ct] {
		return flickoerrors.New(
			flickoerrors.CodeInvalidFileType,
			fmt.Sprintf("content type %q is not allowed", ct),
		)
	}
	return nil
}

// --- File Size ---

// FileSize validates an upload file size against a max (in bytes).
func FileSize(size, maxSize int64) error {
	if size <= 0 {
		return flickoerrors.ErrValidation("file size must be positive")
	}
	if size > maxSize {
		return flickoerrors.New(
			flickoerrors.CodeFileTooLarge,
			fmt.Sprintf("file size %d exceeds maximum %d bytes", size, maxSize),
		)
	}
	return nil
}
