// Package errors defines Flicko's domain error types.
// These errors are the contract between service layers:
//
//	Repository returns → Service catches → Handler maps to HTTP/WS code
//
// Every error type carries a machine-readable Code and a human-readable
// Message. Codes are stable (never change). Messages may be refined.
package errors

import (
	"errors"
	"fmt"
)

// Code is a machine-readable error identifier.
// Sent in API responses as {"error": {"code": "RATE_LIMITED", ...}}.
// These are the ONLY error codes your API will ever return.
// Adding a new code is a minor API change. Removing one is breaking.
type Code string

const (
	CodeValidation      Code = "VALIDATION_ERROR"
	CodeInvalidJSON     Code = "INVALID_JSON"
	CodeMissingField    Code = "MISSING_FIELD"
	CodeInvalidToken    Code = "INVALID_TOKEN"
	CodeMissingAuth     Code = "MISSING_AUTH"
	CodeForbidden       Code = "FORBIDDEN"
	CodeNotMember       Code = "NOT_MEMBER"
	CodeNotFound        Code = "RESOURCE_NOT_FOUND"
	CodeConflict        Code = "CONFLICT"
	CodeUsernameTaken   Code = "USERNAME_TAKEN"
	CodeEmailTaken      Code = "EMAIL_TAKEN"
	CodeAlreadyMember   Code = "ALREADY_MEMBER"
	CodeRateLimited     Code = "RATE_LIMITED"
	CodeMessageTooLong  Code = "MESSAGE_TOO_LONG"
	CodeMaxChannels     Code = "MAX_CHANNELS"
	CodeMaxGuilds       Code = "MAX_GUILDS"
	CodeMaxAttachments  Code = "MAX_ATTACHMENTS"
	CodeFileTooLarge    Code = "FILE_TOO_LARGE"
	CodeInvalidFileType Code = "INVALID_FILE_TYPE"
	CodeInviteExpired   Code = "INVITE_EXPIRED"
	CodeUserBanned      Code = "USER_BANNED"
	CodeUserMuted       Code = "USER_MUTED"
	CodeBackpressure    Code = "BACKPRESSURE"
	CodeInternal        Code = "INTERNAL_ERROR"
	CodeSlowConsumer    Code = "SLOW_CONSUMER"
)

// Error is the base domain error type. All Flicko errors embed this.
// It satisfies the error interface and supports errors.Is/As.
type Error struct {
	code    Code
	message string
	cause   error // Wrapped original error (may be nil)
}

// New creates a domain error with a code and message.
func New(code Code, message string) *Error {
	return &Error{code: code, message: message}
}

// Wrap creates a domain error wrapping an underlying cause.
// The cause is included in Unwrap() for errors.Is/As chains
// but NEVER exposed in API responses (security).
func Wrap(code Code, message string, cause error) *Error {
	return &Error{code: code, message: message, cause: cause}
}

// Error implements the error interface.
func (e *Error) Error() string {
	if e.cause != nil {
		return fmt.Sprintf("[%s] %s: %v", e.code, e.message, e.cause)
	}
	return fmt.Sprintf("[%s] %s", e.code, e.message)
}

// Code returns the machine-readable error code.
func (e *Error) Code() Code {
	return e.code
}

// Message returns the human-readable error message.
func (e *Error) Message() string {
	return e.message
}

// Unwrap returns the wrapped cause (for errors.Is / errors.As).
func (e *Error) Unwrap() error {
	return e.cause
}

// Is reports whether target matches this error.
// Two *Error values match if they share the same Code,
// which lets callers write: errors.Is(err, ErrNotFound(""))
// and match any "not found" domain error regardless of message.
func (e *Error) Is(target error) bool {
	var t *Error
	if errors.As(target, &t) {
		return e.code == t.code
	}
	return false
}

// --- Convenience constructors ---
// Each returns a typed *Error. Handlers use GetCode() to map to HTTP status.

func ErrValidation(msg string) *Error {
	return New(CodeValidation, msg)
}

func ErrMissingField(field string) *Error {
	return New(CodeMissingField, fmt.Sprintf("missing required field: %s", field))
}

func ErrInvalidJSON(cause error) *Error {
	return Wrap(CodeInvalidJSON, "malformed JSON in request body", cause)
}

func ErrUnauthorized(msg string) *Error {
	return New(CodeInvalidToken, msg)
}

func ErrMissingAuth() *Error {
	return New(CodeMissingAuth, "authorization header is required")
}

func ErrForbidden(msg string) *Error {
	return New(CodeForbidden, msg)
}

func ErrNotMember() *Error {
	return New(CodeNotMember, "you are not a member of this guild")
}

func ErrNotFound(resource string) *Error {
	return New(CodeNotFound, fmt.Sprintf("%s not found", resource))
}

func ErrConflict(msg string) *Error {
	return New(CodeConflict, msg)
}

func ErrRateLimited(retryAfter float64) *Error {
	return New(CodeRateLimited, fmt.Sprintf("rate limited, retry after %.1fs", retryAfter))
}

func ErrBackpressure() *Error {
	return New(CodeBackpressure, "server is overloaded, please retry")
}

func ErrInternal(cause error) *Error {
	// Internal errors always wrap a cause for logging,
	// but the cause is NEVER sent to the client.
	return Wrap(CodeInternal, "internal server error", cause)
}

func ErrSlowConsumer() *Error {
	return New(CodeSlowConsumer, "client too slow to consume messages")
}

// --- Extraction helpers ---

// GetCode extracts the Flicko error code from any error.
// Returns CodeInternal if the error is not a *Error.
func GetCode(err error) Code {
	var e *Error
	if errors.As(err, &e) {
		return e.code
	}
	return CodeInternal
}

// GetMessage extracts the safe client-facing message from any error.
// Returns a generic message for non-domain errors (no internal leak).
func GetMessage(err error) string {
	var e *Error
	if errors.As(err, &e) {
		return e.message
	}
	return "internal server error"
}
