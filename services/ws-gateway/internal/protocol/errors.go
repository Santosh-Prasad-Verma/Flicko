package protocol

import (
	"fmt"

	proto "github.com/flicko-org/flicko/services/shared/protocol"
)

// WebSocket close codes — RFC 6455 application range (4000–4999).
// Re-exported from shared/protocol for gateway-internal use.
const (
	CloseUnknownError         = proto.CloseUnknownError         // 4000
	CloseInvalidPayload       = proto.CloseInvalidPayload       // 4001
	CloseNotAuthenticated     = proto.CloseNotAuthenticated     // 4003
	CloseAuthFailed           = proto.CloseAuthFailed           // 4004
	CloseAlreadyAuthenticated = proto.CloseAlreadyAuthenticated // 4005
	CloseRateLimited          = proto.CloseRateLimited          // 4008
	CloseSessionTimeout       = proto.CloseSessionTimeout       // 4009
	CloseInvalidChannel       = proto.CloseInvalidChannel       // 4010
	CloseServerFull           = proto.CloseServerFull           // 4011
)

// CloseText returns the human-readable text for a close code.
var CloseText = proto.CloseText

// IsRetryableClose reports whether the client should reconnect.
var IsRetryableClose = proto.IsRetryableClose

// CloseError is a structured error the gateway returns when it needs
// to close a WebSocket connection with an application close code.
// It implements the error interface so it can be returned up the
// handler chain and inspected by the connection writer.
type CloseError struct {
	// Code is the WebSocket close code (4000–4011).
	Code int
	// Text is the human-readable close reason.
	Text string
}

// Error implements the error interface.
func (e *CloseError) Error() string {
	return fmt.Sprintf("ws close %d: %s", e.Code, e.Text)
}

// NewCloseError creates a CloseError from a protocol close code.
// The human-readable text is looked up automatically.
func NewCloseError(code int) *CloseError {
	return &CloseError{
		Code: code,
		Text: CloseText(code),
	}
}

// ErrNotAuthenticated is returned when a client sends a non-Identify
// frame before authenticating.
var ErrNotAuthenticated = NewCloseError(CloseNotAuthenticated)

// ErrAuthFailed is returned when the Identify token is invalid.
var ErrAuthFailed = NewCloseError(CloseAuthFailed)

// ErrAlreadyAuthenticated is returned on a duplicate Identify.
var ErrAlreadyAuthenticated = NewCloseError(CloseAlreadyAuthenticated)

// ErrRateLimited is returned when the client exceeds message rate.
var ErrRateLimited = NewCloseError(CloseRateLimited)

// ErrSessionTimeout is returned on heartbeat miss or identify timeout.
var ErrSessionTimeout = NewCloseError(CloseSessionTimeout)

// ErrInvalidPayload is returned when a frame cannot be decoded.
var ErrInvalidPayload = NewCloseError(CloseInvalidPayload)

// ErrInvalidChannel is returned when a client references an
// inaccessible channel.
var ErrInvalidChannel = NewCloseError(CloseInvalidChannel)

// ErrServerFull is returned when max connections is reached.
var ErrServerFull = NewCloseError(CloseServerFull)
