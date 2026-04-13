package errors

import "net/http"

// HTTPStatus maps a domain error code to an HTTP status code.
// This is the SINGLE source of truth for code → status mapping.
// Handlers call: w.WriteHeader(errors.HTTPStatus(err))
func HTTPStatus(err error) int {
	code := GetCode(err)
	if status, ok := httpStatusMap[code]; ok {
		return status
	}
	return http.StatusInternalServerError
}

// ToHTTPStatus returns the HTTP status code for this domain error.
func (e *Error) ToHTTPStatus() int {
	if status, ok := httpStatusMap[e.code]; ok {
		return status
	}
	return http.StatusInternalServerError
}

var httpStatusMap = map[Code]int{
	CodeValidation:      http.StatusBadRequest,          // 400
	CodeInvalidJSON:     http.StatusBadRequest,          // 400
	CodeMissingField:    http.StatusBadRequest,          // 400
	CodeMessageTooLong:  http.StatusBadRequest,          // 400
	CodeMaxChannels:     http.StatusBadRequest,          // 400
	CodeMaxGuilds:       http.StatusBadRequest,          // 400
	CodeMaxAttachments:  http.StatusBadRequest,          // 400
	CodeFileTooLarge:    http.StatusBadRequest,          // 400
	CodeInvalidFileType: http.StatusBadRequest,          // 400
	CodeInviteExpired:   http.StatusBadRequest,          // 400
	CodeInvalidToken:    http.StatusUnauthorized,        // 401
	CodeMissingAuth:     http.StatusUnauthorized,        // 401
	CodeForbidden:       http.StatusForbidden,           // 403
	CodeNotMember:       http.StatusForbidden,           // 403
	CodeUserBanned:      http.StatusForbidden,           // 403
	CodeUserMuted:       http.StatusForbidden,           // 403
	CodeNotFound:        http.StatusNotFound,            // 404
	CodeConflict:        http.StatusConflict,            // 409
	CodeUsernameTaken:   http.StatusConflict,            // 409
	CodeEmailTaken:      http.StatusConflict,            // 409
	CodeAlreadyMember:   http.StatusConflict,            // 409
	CodeRateLimited:     http.StatusTooManyRequests,     // 429
	CodeInternal:        http.StatusInternalServerError, // 500
	CodeBackpressure:    http.StatusServiceUnavailable,  // 503
}

// WSCloseCode maps a domain error code to a WebSocket close code.
// These are custom close codes in the 4000-4999 range (application use).
// Standard WS close codes: https://datatracker.ietf.org/doc/html/rfc6455#section-7.4
type WSCloseCode int

const (
	WSCloseUnknown              WSCloseCode = 4000
	WSCloseInvalidPayload       WSCloseCode = 4001
	WSCloseNotAuthenticated     WSCloseCode = 4003
	WSCloseAuthFailed           WSCloseCode = 4004
	WSCloseAlreadyAuthenticated WSCloseCode = 4005
	WSCloseRateLimited          WSCloseCode = 4008
	WSCloseSessionTimeout       WSCloseCode = 4009
	WSCloseInvalidChannel       WSCloseCode = 4010
	WSCloseServerFull           WSCloseCode = 4011
	WSCloseSlowConsumer         WSCloseCode = 4012
	WSCloseMessageTooLong       WSCloseCode = 4013
)

// WSClose maps a domain error code to a WebSocket close code.
func WSClose(err error) WSCloseCode {
	code := GetCode(err)
	if ws, ok := wsCloseMap[code]; ok {
		return ws
	}
	return WSCloseUnknown
}

// ToWSCloseCode returns the WebSocket close code for this domain error.
func (e *Error) ToWSCloseCode() WSCloseCode {
	if ws, ok := wsCloseMap[e.code]; ok {
		return ws
	}
	return WSCloseUnknown
}

var wsCloseMap = map[Code]WSCloseCode{
	CodeInvalidJSON:    WSCloseInvalidPayload,
	CodeValidation:     WSCloseInvalidPayload,
	CodeMissingAuth:    WSCloseNotAuthenticated,
	CodeInvalidToken:   WSCloseAuthFailed,
	CodeForbidden:      WSCloseAuthFailed,
	CodeRateLimited:    WSCloseRateLimited,
	CodeNotFound:       WSCloseInvalidChannel,
	CodeBackpressure:   WSCloseServerFull,
	CodeSlowConsumer:   WSCloseSlowConsumer,
	CodeMessageTooLong: WSCloseMessageTooLong,
	CodeInternal:       WSCloseUnknown,
}
