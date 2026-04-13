package errors

import (
	"errors"
	"fmt"
	"net/http"
	"testing"
)

func TestNew(t *testing.T) {
	err := New(CodeNotFound, "guild not found")
	if err.Code() != CodeNotFound {
		t.Errorf("expected code %s, got %s", CodeNotFound, err.Code())
	}
	if err.Message() != "guild not found" {
		t.Errorf("expected message 'guild not found', got %q", err.Message())
	}
	if err.Unwrap() != nil {
		t.Error("expected nil cause")
	}
}

func TestWrap(t *testing.T) {
	cause := fmt.Errorf("connection refused")
	err := Wrap(CodeInternal, "database error", cause)

	if err.Unwrap() != cause {
		t.Error("expected wrapped cause to match")
	}

	// errors.Is should walk the chain
	if !errors.Is(err, cause) {
		t.Error("errors.Is should find the cause")
	}

	// Error string should include both message and cause
	errStr := err.Error()
	if errStr != "[INTERNAL_ERROR] database error: connection refused" {
		t.Errorf("unexpected error string: %s", errStr)
	}
}

func TestErrorsAs(t *testing.T) {
	err := ErrNotFound("channel")

	// Wrap in another error
	wrapped := fmt.Errorf("handler: %w", err)

	// errors.As should extract our *Error
	var domainErr *Error
	if !errors.As(wrapped, &domainErr) {
		t.Fatal("errors.As should find *Error in chain")
	}
	if domainErr.Code() != CodeNotFound {
		t.Errorf("expected code %s, got %s", CodeNotFound, domainErr.Code())
	}
}

func TestGetCode_DomainError(t *testing.T) {
	err := ErrRateLimited(1.5)
	code := GetCode(err)
	if code != CodeRateLimited {
		t.Errorf("expected %s, got %s", CodeRateLimited, code)
	}
}

func TestGetCode_NonDomainError(t *testing.T) {
	err := fmt.Errorf("random error")
	code := GetCode(err)
	if code != CodeInternal {
		t.Errorf("expected %s for non-domain error, got %s", CodeInternal, code)
	}
}

func TestGetCode_WrappedDomainError(t *testing.T) {
	inner := ErrForbidden("not allowed")
	wrapped := fmt.Errorf("handler: %w", inner)
	code := GetCode(wrapped)
	if code != CodeForbidden {
		t.Errorf("expected %s through wrap chain, got %s", CodeForbidden, code)
	}
}

func TestGetMessage_DomainError(t *testing.T) {
	err := ErrNotMember()
	msg := GetMessage(err)
	if msg != "you are not a member of this guild" {
		t.Errorf("unexpected message: %s", msg)
	}
}

func TestGetMessage_NonDomainError(t *testing.T) {
	err := fmt.Errorf("segfault at 0x00")
	msg := GetMessage(err)
	// Must NOT leak internal details
	if msg != "internal server error" {
		t.Errorf("expected generic message for non-domain error, got %q", msg)
	}
}

func TestHTTPStatus_AllMappings(t *testing.T) {
	tests := []struct {
		err        error
		wantStatus int
	}{
		{ErrValidation("bad input"), http.StatusBadRequest},
		{ErrMissingField("name"), http.StatusBadRequest},
		{ErrInvalidJSON(nil), http.StatusBadRequest},
		{ErrUnauthorized("expired"), http.StatusUnauthorized},
		{ErrMissingAuth(), http.StatusUnauthorized},
		{ErrForbidden("nope"), http.StatusForbidden},
		{ErrNotMember(), http.StatusForbidden},
		{ErrNotFound("guild"), http.StatusNotFound},
		{ErrConflict("exists"), http.StatusConflict},
		{ErrRateLimited(1.0), http.StatusTooManyRequests},
		{ErrBackpressure(), http.StatusServiceUnavailable},
		{ErrInternal(nil), http.StatusInternalServerError},
		{fmt.Errorf("unknown"), http.StatusInternalServerError}, // fallback
	}

	for _, tt := range tests {
		t.Run(tt.err.Error(), func(t *testing.T) {
			got := HTTPStatus(tt.err)
			if got != tt.wantStatus {
				t.Errorf("HTTPStatus(%v) = %d, want %d", tt.err, got, tt.wantStatus)
			}
		})
	}
}

func TestWSClose_Mappings(t *testing.T) {
	tests := []struct {
		err      error
		wantCode WSCloseCode
	}{
		{ErrMissingAuth(), WSCloseNotAuthenticated},
		{ErrUnauthorized("bad token"), WSCloseAuthFailed},
		{ErrRateLimited(1.0), WSCloseRateLimited},
		{ErrSlowConsumer(), WSCloseSlowConsumer},
		{ErrBackpressure(), WSCloseServerFull},
		{ErrNotFound("channel"), WSCloseInvalidChannel},
		{ErrInternal(nil), WSCloseUnknown}, // fallback
	}

	for _, tt := range tests {
		t.Run(tt.err.Error(), func(t *testing.T) {
			got := WSClose(tt.err)
			if got != tt.wantCode {
				t.Errorf("WSClose(%v) = %d, want %d", tt.err, got, tt.wantCode)
			}
		})
	}
}

func TestConvenienceConstructors(t *testing.T) {
	// Verify each constructor produces the right code
	checks := []struct {
		name string
		err  *Error
		code Code
	}{
		{"ErrValidation", ErrValidation("x"), CodeValidation},
		{"ErrMissingField", ErrMissingField("x"), CodeMissingField},
		{"ErrInvalidJSON", ErrInvalidJSON(nil), CodeInvalidJSON},
		{"ErrUnauthorized", ErrUnauthorized("x"), CodeInvalidToken},
		{"ErrMissingAuth", ErrMissingAuth(), CodeMissingAuth},
		{"ErrForbidden", ErrForbidden("x"), CodeForbidden},
		{"ErrNotMember", ErrNotMember(), CodeNotMember},
		{"ErrNotFound", ErrNotFound("x"), CodeNotFound},
		{"ErrConflict", ErrConflict("x"), CodeConflict},
		{"ErrRateLimited", ErrRateLimited(1), CodeRateLimited},
		{"ErrBackpressure", ErrBackpressure(), CodeBackpressure},
		{"ErrInternal", ErrInternal(nil), CodeInternal},
		{"ErrSlowConsumer", ErrSlowConsumer(), CodeSlowConsumer},
	}

	for _, c := range checks {
		t.Run(c.name, func(t *testing.T) {
			if c.err.Code() != c.code {
				t.Errorf("%s: expected code %s, got %s", c.name, c.code, c.err.Code())
			}
		})
	}
}
