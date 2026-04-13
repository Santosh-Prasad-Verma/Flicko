package logger

import (
	"testing"

	"go.uber.org/zap"
	"go.uber.org/zap/zaptest/observer"
)

func TestNew_Dev(t *testing.T) {
	log := New(true)
	if log == nil {
		t.Fatal("expected non-nil logger")
	}
	// dev logger should be at debug level — logging debug must not panic
	log.Debug("dev debug")
	log.Info("dev info")
}

func TestNew_Prod(t *testing.T) {
	log := New(false)
	if log == nil {
		t.Fatal("expected non-nil logger")
	}
	log.Info("prod info", zap.Int("port", 8080))
}

func TestWithRequest_Full(t *testing.T) {
	core, recorded := observer.New(zap.DebugLevel)
	base := zap.New(core)

	child := WithRequest(base, "req-123", "user-456")
	child.Info("hello")

	if recorded.Len() != 1 {
		t.Fatalf("expected 1 log entry, got %d", recorded.Len())
	}

	entry := recorded.All()[0]
	var gotReqID, gotUserID string
	for _, f := range entry.Context {
		switch f.Key {
		case "request_id":
			gotReqID = f.String
		case "user_id":
			gotUserID = f.String
		}
	}
	if gotReqID != "req-123" {
		t.Errorf("request_id = %q, want %q", gotReqID, "req-123")
	}
	if gotUserID != "user-456" {
		t.Errorf("user_id = %q, want %q", gotUserID, "user-456")
	}
}

func TestWithRequest_NoUserID(t *testing.T) {
	core, recorded := observer.New(zap.DebugLevel)
	base := zap.New(core)

	child := WithRequest(base, "req-789", "")
	child.Info("anon request")

	if recorded.Len() != 1 {
		t.Fatalf("expected 1 log entry, got %d", recorded.Len())
	}

	entry := recorded.All()[0]
	for _, f := range entry.Context {
		if f.Key == "user_id" {
			t.Error("user_id field should not be present when empty")
		}
	}
}
