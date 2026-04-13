package protocol

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

// ── Encode / Decode round-trip ──────────────────────────────────────

func TestEncodeDecode_MessageCreate(t *testing.T) {
	payload := MessagePayload{
		ChannelID: "01HXYZ",
		Content:   "hello from tests",
		Nonce:     "nonce-abc",
	}

	raw, err := Encode(OpMessageCreate, payload)
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	if msg.Op != OpMessageCreate {
		t.Errorf("Op = %d, want %d", msg.Op, OpMessageCreate)
	}

	got, err := DecodePayload[MessagePayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if got.ChannelID != "01HXYZ" {
		t.Errorf("ChannelID = %q, want %q", got.ChannelID, "01HXYZ")
	}
	if got.Content != "hello from tests" {
		t.Errorf("Content = %q, want %q", got.Content, "hello from tests")
	}
	if got.Nonce != "nonce-abc" {
		t.Errorf("Nonce = %q, want %q", got.Nonce, "nonce-abc")
	}
}

func TestEncodeDecodeDispatch(t *testing.T) {
	payload := MessagePayload{
		ID:        "01ABC",
		ChannelID: "ch-1",
		AuthorID:  "user-1",
		Content:   "dispatched",
		Nonce:     "n-1",
		Timestamp: 1700000000000,
	}

	raw, err := EncodeDispatch("MESSAGE_CREATE", 42, payload)
	if err != nil {
		t.Fatalf("EncodeDispatch: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	if msg.Op != OpDispatch {
		t.Errorf("Op = %d, want %d (Dispatch)", msg.Op, OpDispatch)
	}
	if msg.S != 42 {
		t.Errorf("S = %d, want 42", msg.S)
	}
	if msg.T != "MESSAGE_CREATE" {
		t.Errorf("T = %q, want MESSAGE_CREATE", msg.T)
	}

	got, err := DecodePayload[MessagePayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if got.Content != "dispatched" {
		t.Errorf("Content = %q, want %q", got.Content, "dispatched")
	}
}

// ── Generic DecodePayload ───────────────────────────────────────────

func TestDecodePayload_Identify(t *testing.T) {
	raw, err := Encode(OpIdentify, IdentifyPayload{
		Token:    "jwt.token.here",
		DeviceID: "device-42",
	})
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	id, err := DecodePayload[IdentifyPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if id.Token != "jwt.token.here" {
		t.Errorf("Token = %q, want %q", id.Token, "jwt.token.here")
	}
	if id.DeviceID != "device-42" {
		t.Errorf("DeviceID = %q, want %q", id.DeviceID, "device-42")
	}
}

func TestDecodePayload_Typing(t *testing.T) {
	raw, err := Encode(OpTypingStart, TypingPayload{
		ChannelID: "ch-5",
		UserID:    "user-9",
		Timestamp: 1700000001000,
	})
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	tp, err := DecodePayload[TypingPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if tp.ChannelID != "ch-5" {
		t.Errorf("ChannelID = %q, want ch-5", tp.ChannelID)
	}
}

func TestDecodePayload_Presence(t *testing.T) {
	raw, err := Encode(OpPresenceUpdate, PresencePayload{
		UserID:   "user-1",
		Status:   "idle",
		LastSeen: 1700000002000,
	})
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	pp, err := DecodePayload[PresencePayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if pp.Status != "idle" {
		t.Errorf("Status = %q, want idle", pp.Status)
	}
}

func TestDecodePayload_ChannelSub(t *testing.T) {
	raw, err := Encode(OpChannelSub, ChannelSubPayload{ChannelID: "ch-99"})
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}

	cs, err := DecodePayload[ChannelSubPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if cs.ChannelID != "ch-99" {
		t.Errorf("ChannelID = %q, want ch-99", cs.ChannelID)
	}
}

// ── Invalid payload handling ────────────────────────────────────────

func TestDecode_InvalidJSON(t *testing.T) {
	_, err := Decode([]byte("{broken"))
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestDecode_FrameTooLarge(t *testing.T) {
	huge := make([]byte, MaxFrameSize+1)
	for i := range huge {
		huge[i] = 'x'
	}
	_, err := Decode(huge)
	if err == nil {
		t.Fatal("expected error for oversized frame")
	}
	if !strings.Contains(err.Error(), "exceeds limit") {
		t.Errorf("error %q should mention exceeds limit", err.Error())
	}
}

func TestDecodePayload_MalformedD(t *testing.T) {
	msg := &GatewayMessage{
		Op: OpIdentify,
		D:  json.RawMessage(`{bad`),
	}
	_, err := DecodePayload[IdentifyPayload](msg)
	if err == nil {
		t.Fatal("expected error for malformed D field")
	}
}

func TestDecodePayload_WrongType(t *testing.T) {
	raw, _ := Encode(OpTypingStart, TypingPayload{
		ChannelID: "ch-1",
		UserID:    "user-1",
		Timestamp: 123,
	})
	msg, _ := Decode(raw)

	id, err := DecodePayload[IdentifyPayload](msg)
	if err != nil {
		t.Fatalf("unexpected error (JSON is lenient with extra fields): %v", err)
	}
	if id.Token != "" {
		t.Errorf("Token should be zero-value, got %q", id.Token)
	}
}

func TestDecode_EmptyPayload(t *testing.T) {
	raw := []byte(`{"op":1,"d":null}`)
	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if msg.Op != OpHeartbeat {
		t.Errorf("Op = %d, want %d", msg.Op, OpHeartbeat)
	}
}

// ── Server message builders ─────────────────────────────────────────

func TestNewReadyMessage(t *testing.T) {
	raw, err := NewReadyMessage("sess-1", "user-1", []string{"g1", "g2"}, "wss://resume")
	if err != nil {
		t.Fatalf("NewReadyMessage: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if msg.Op != OpReady {
		t.Errorf("Op = %d, want %d", msg.Op, OpReady)
	}

	rp, err := DecodePayload[ReadyPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if rp.SessionID != "sess-1" {
		t.Errorf("SessionID = %q, want sess-1", rp.SessionID)
	}
	if rp.UserID != "user-1" {
		t.Errorf("UserID = %q, want user-1", rp.UserID)
	}
	if len(rp.Guilds) != 2 {
		t.Errorf("Guilds len = %d, want 2", len(rp.Guilds))
	}
	if rp.ResumeURL != "wss://resume" {
		t.Errorf("ResumeURL = %q, want wss://resume", rp.ResumeURL)
	}
}

func TestNewErrorMessage(t *testing.T) {
	raw, err := NewErrorMessage(CloseRateLimited, "too fast", true)
	if err != nil {
		t.Fatalf("NewErrorMessage: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if msg.Op != OpError {
		t.Errorf("Op = %d, want %d", msg.Op, OpError)
	}

	ep, err := DecodePayload[ErrorPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if ep.Code != CloseRateLimited {
		t.Errorf("Code = %d, want %d", ep.Code, CloseRateLimited)
	}
	if !ep.Retry {
		t.Error("Retry should be true")
	}
}

func TestNewAckMessage(t *testing.T) {
	raw, err := NewAckMessage("nonce-x", "01HXYZ")
	if err != nil {
		t.Fatalf("NewAckMessage: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if msg.Op != OpMessageAck {
		t.Errorf("Op = %d, want %d", msg.Op, OpMessageAck)
	}

	ap, err := DecodePayload[AckPayload](msg)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if ap.Nonce != "nonce-x" {
		t.Errorf("Nonce = %q, want nonce-x", ap.Nonce)
	}
	if ap.MessageID != "01HXYZ" {
		t.Errorf("MessageID = %q, want 01HXYZ", ap.MessageID)
	}
}

func TestNewHeartbeatAck(t *testing.T) {
	raw, err := NewHeartbeatAck()
	if err != nil {
		t.Fatalf("NewHeartbeatAck: %v", err)
	}

	msg, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if msg.Op != OpHeartbeat {
		t.Errorf("Op = %d, want %d", msg.Op, OpHeartbeat)
	}
}

// ── OmitEmpty on envelope fields ────────────────────────────────────

func TestEncode_OmitsEmptyOptionalFields(t *testing.T) {
	raw, err := Encode(OpHeartbeat, 5)
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}

	var m map[string]json.RawMessage
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	for _, key := range []string{"s", "t", "n"} {
		if _, ok := m[key]; ok {
			t.Errorf("key %q should be omitted (zero-value + omitempty)", key)
		}
	}
}

// ── CloseError ──────────────────────────────────────────────────────

func TestCloseError(t *testing.T) {
	ce := NewCloseError(CloseRateLimited)
	if ce.Code != 4008 {
		t.Errorf("Code = %d, want 4008", ce.Code)
	}
	if ce.Text != "rate limited" {
		t.Errorf("Text = %q, want %q", ce.Text, "rate limited")
	}
	if !strings.Contains(ce.Error(), "4008") {
		t.Errorf("Error() = %q, should contain 4008", ce.Error())
	}
}

func TestCloseError_Sentinel(t *testing.T) {
	var err error = ErrNotAuthenticated

	var ce *CloseError
	if !errors.As(err, &ce) {
		t.Fatal("errors.As should find *CloseError")
	}
	if ce.Code != CloseNotAuthenticated {
		t.Errorf("Code = %d, want %d", ce.Code, CloseNotAuthenticated)
	}
}

func TestCloseCodeValues(t *testing.T) {
	tests := []struct {
		name string
		code int
		want int
	}{
		{"Unknown", CloseUnknownError, 4000},
		{"InvalidPayload", CloseInvalidPayload, 4001},
		{"NotAuthenticated", CloseNotAuthenticated, 4003},
		{"AuthFailed", CloseAuthFailed, 4004},
		{"AlreadyAuthenticated", CloseAlreadyAuthenticated, 4005},
		{"RateLimited", CloseRateLimited, 4008},
		{"SessionTimeout", CloseSessionTimeout, 4009},
		{"InvalidChannel", CloseInvalidChannel, 4010},
		{"ServerFull", CloseServerFull, 4011},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.code != tc.want {
				t.Errorf("%s = %d, want %d", tc.name, tc.code, tc.want)
			}
		})
	}
}

func TestIsRetryableClose_Codes(t *testing.T) {
	retryable := []int{CloseRateLimited, CloseSessionTimeout, CloseServerFull}
	for _, code := range retryable {
		if !IsRetryableClose(code) {
			t.Errorf("code %d should be retryable", code)
		}
	}

	nonRetryable := []int{
		CloseUnknownError, CloseInvalidPayload,
		CloseNotAuthenticated, CloseAuthFailed,
		CloseAlreadyAuthenticated, CloseInvalidChannel,
	}
	for _, code := range nonRetryable {
		if IsRetryableClose(code) {
			t.Errorf("code %d should NOT be retryable", code)
		}
	}
}

// ── OpCode value & direction ────────────────────────────────────────

func TestOpCodeValues(t *testing.T) {
	tests := []struct {
		op   OpCode
		want int
	}{
		{OpDispatch, 0}, {OpHeartbeat, 1}, {OpIdentify, 2},
		{OpPresenceUpdate, 3}, {OpTypingStart, 4}, {OpMessageCreate, 5},
		{OpMessageAck, 6}, {OpError, 7}, {OpChannelSub, 8},
		{OpChannelUnsub, 9}, {OpReady, 10},
	}
	for _, tc := range tests {
		if int(tc.op) != tc.want {
			t.Errorf("%s = %d, want %d", tc.op, tc.op, tc.want)
		}
	}
}

func TestOpCode_String(t *testing.T) {
	if OpDispatch.String() != "DISPATCH" {
		t.Errorf("OpDispatch.String() = %q", OpDispatch.String())
	}
	if OpReady.String() != "READY" {
		t.Errorf("OpReady.String() = %q", OpReady.String())
	}
}

func TestOpCode_IsClientOp(t *testing.T) {
	clientOps := []OpCode{
		OpHeartbeat, OpIdentify, OpPresenceUpdate,
		OpTypingStart, OpMessageCreate, OpChannelSub, OpChannelUnsub,
	}
	for _, op := range clientOps {
		if !op.IsClientOp() {
			t.Errorf("%s should be a client op", op)
		}
	}

	serverOnly := []OpCode{OpDispatch, OpMessageAck, OpError, OpReady}
	for _, op := range serverOnly {
		if op.IsClientOp() {
			t.Errorf("%s should NOT be a client op", op)
		}
	}
}
