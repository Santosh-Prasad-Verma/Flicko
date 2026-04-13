package protocol

// WebSocket close codes for the Flicko gateway protocol.
// Range 4000-4999 is reserved for application use per RFC 6455.
const (
// CloseUnknownError is a catch-all for unclassified errors.
CloseUnknownError = 4000

// CloseInvalidPayload means the message could not be decoded.
CloseInvalidPayload = 4001

// CloseNotAuthenticated means the client sent a non-Identify op
// before authenticating.
CloseNotAuthenticated = 4003

// CloseAuthFailed means the Identify token was invalid or expired.
CloseAuthFailed = 4004

// CloseAlreadyAuthenticated means the client sent Identify twice.
CloseAlreadyAuthenticated = 4005

// CloseRateLimited means the client exceeded the message rate limit.
CloseRateLimited = 4008

// CloseSessionTimeout means the client did not send Identify in time
// or missed too many heartbeats.
CloseSessionTimeout = 4009

// CloseInvalidChannel means the client referenced a channel it
// does not have access to.
CloseInvalidChannel = 4010

// CloseServerFull means the gateway has reached max connections.
CloseServerFull = 4011
)

// CloseCodeText maps close codes to human-readable descriptions.
var CloseCodeText = map[int]string{
CloseUnknownError:         "unknown error",
CloseInvalidPayload:       "invalid message payload",
CloseNotAuthenticated:     "not authenticated",
CloseAuthFailed:           "authentication failed",
CloseAlreadyAuthenticated: "already authenticated",
CloseRateLimited:          "rate limited",
CloseSessionTimeout:       "session timed out",
CloseInvalidChannel:       "invalid channel",
CloseServerFull:           "server full",
}

// CloseText returns the human-readable text for a close code,
// or "unknown error" if the code is not recognized.
func CloseText(code int) string {
if text, ok := CloseCodeText[code]; ok {
return text
}
return "unknown error"
}

// IsRetryableClose returns true if the client should attempt reconnection
// after receiving this close code.
func IsRetryableClose(code int) bool {
switch code {
case CloseRateLimited, CloseSessionTimeout, CloseServerFull:
return true
default:
return false
}
}
