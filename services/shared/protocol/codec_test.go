package protocol

import (
"encoding/json"
"testing"
)

func TestJSONCodec_RoundTrip(t *testing.T) {
codec := JSONCodec{}

original := &GatewayMessage{
Op: OpMessageCreate,
D:  json.RawMessage(`{"channel_id":"ch-1","content":"hello","nonce":"abc"}`),
N:  "abc",
}

data, err := codec.Encode(original)
if err != nil {
t.Fatalf("Encode: %v", err)
}

decoded, err := codec.Decode(data)
if err != nil {
t.Fatalf("Decode: %v", err)
}

if decoded.Op != original.Op {
t.Errorf("Op = %d, want %d", decoded.Op, original.Op)
}
if decoded.N != original.N {
t.Errorf("N = %q, want %q", decoded.N, original.N)
}
if string(decoded.D) != string(original.D) {
t.Errorf("D = %s, want %s", decoded.D, original.D)
}
}

func TestJSONCodec_Decode_InvalidJSON(t *testing.T) {
codec := JSONCodec{}
_, err := codec.Decode([]byte("not json"))
if err == nil {
t.Error("expected error for invalid JSON")
}
}

func TestJSONCodec_Dispatch_RoundTrip(t *testing.T) {
codec := JSONCodec{}

msg, err := NewDispatch("MESSAGE_CREATE", 42, MessagePayload{
ID:        "01ABC",
ChannelID: "ch-1",
AuthorID:  "user-1",
Content:   "hello world",
Nonce:     "nonce-1",
Timestamp: 1700000000000,
})
if err != nil {
t.Fatalf("NewDispatch: %v", err)
}

data, err := codec.Encode(msg)
if err != nil {
t.Fatalf("Encode: %v", err)
}

decoded, err := codec.Decode(data)
if err != nil {
t.Fatalf("Decode: %v", err)
}

if decoded.Op != OpDispatch {
t.Errorf("Op = %d, want %d", decoded.Op, OpDispatch)
}
if decoded.S != 42 {
t.Errorf("S = %d, want 42", decoded.S)
}
if decoded.T != "MESSAGE_CREATE" {
t.Errorf("T = %q, want MESSAGE_CREATE", decoded.T)
}

payload, err := DecodePayload[MessagePayload](decoded)
if err != nil {
t.Fatalf("DecodePayload: %v", err)
}
if payload.Content != "hello world" {
t.Errorf("Content = %q, want %q", payload.Content, "hello world")
}
if payload.ChannelID != "ch-1" {
t.Errorf("ChannelID = %q, want %q", payload.ChannelID, "ch-1")
}
}

func TestDecodePayload_Generic(t *testing.T) {
msg, err := NewMessage(OpIdentify, IdentifyPayload{
Token:    "jwt-token-here",
DeviceID: "device-123",
})
if err != nil {
t.Fatalf("NewMessage: %v", err)
}

payload, err := DecodePayload[IdentifyPayload](msg)
if err != nil {
t.Fatalf("DecodePayload: %v", err)
}
if payload.Token != "jwt-token-here" {
t.Errorf("Token = %q, want %q", payload.Token, "jwt-token-here")
}
if payload.DeviceID != "device-123" {
t.Errorf("DeviceID = %q, want %q", payload.DeviceID, "device-123")
}
}

func TestDecodePayload_InvalidPayload(t *testing.T) {
msg := &GatewayMessage{
Op: OpIdentify,
D:  json.RawMessage(`{"not":"an identify"}`),
}

payload, err := DecodePayload[IdentifyPayload](msg)
// JSON unmarshal won't fail on extra fields — but required fields will be zero.
if err != nil {
t.Fatalf("unexpected error: %v", err)
}
if payload.Token != "" {
t.Errorf("Token should be empty for wrong payload, got %q", payload.Token)
}
}

func TestDecodePayload_MalformedJSON(t *testing.T) {
msg := &GatewayMessage{
Op: OpIdentify,
D:  json.RawMessage(`{broken`),
}

_, err := DecodePayload[IdentifyPayload](msg)
if err == nil {
t.Error("expected error for malformed JSON payload")
}
}

func TestNewError(t *testing.T) {
msg, err := NewError(CloseRateLimited, "too fast", true)
if err != nil {
t.Fatalf("NewError: %v", err)
}
if msg.Op != OpError {
t.Errorf("Op = %d, want %d", msg.Op, OpError)
}

payload, err := DecodePayload[ErrorPayload](msg)
if err != nil {
t.Fatalf("DecodePayload: %v", err)
}
if payload.Code != CloseRateLimited {
t.Errorf("Code = %d, want %d", payload.Code, CloseRateLimited)
}
if !payload.Retry {
t.Error("expected Retry=true")
}
}

func TestNewAck(t *testing.T) {
msg, err := NewAck("nonce-abc", "01HXYZ")
if err != nil {
t.Fatalf("NewAck: %v", err)
}
if msg.Op != OpMessageAck {
t.Errorf("Op = %d, want %d", msg.Op, OpMessageAck)
}

payload, err := DecodePayload[AckPayload](msg)
if err != nil {
t.Fatalf("DecodePayload: %v", err)
}
if payload.Nonce != "nonce-abc" {
t.Errorf("Nonce = %q, want %q", payload.Nonce, "nonce-abc")
}
if payload.MessageID != "01HXYZ" {
t.Errorf("MessageID = %q, want %q", payload.MessageID, "01HXYZ")
}
}

func TestMustEncode(t *testing.T) {
msg, _ := NewMessage(OpHeartbeat, nil)
data := MustEncode(msg)
if len(data) == 0 {
t.Error("MustEncode returned empty bytes")
}
}

func TestMustEncode_OmitsEmptyFields(t *testing.T) {
msg := &GatewayMessage{
Op: OpHeartbeat,
D:  json.RawMessage(`5`),
}
data := MustEncode(msg)
// S, T, N should be omitted (zero values with omitempty)
var raw map[string]json.RawMessage
if err := json.Unmarshal(data, &raw); err != nil {
t.Fatalf("unmarshal: %v", err)
}
if _, ok := raw["s"]; ok {
t.Error("s should be omitted when zero")
}
if _, ok := raw["t"]; ok {
t.Error("t should be omitted when empty")
}
if _, ok := raw["n"]; ok {
t.Error("n should be omitted when empty")
}
}

func BenchmarkJSONCodec_Encode(b *testing.B) {
codec := JSONCodec{}
msg, _ := NewDispatch("MESSAGE_CREATE", 1, MessagePayload{
ID:        "01HXYZ",
ChannelID: "ch-1",
AuthorID:  "user-1",
Content:   "benchmark message",
Nonce:     "n-1",
Timestamp: 1700000000000,
})

b.ResetTimer()
for i := 0; i < b.N; i++ {
codec.Encode(msg)
}
}

func BenchmarkJSONCodec_Decode(b *testing.B) {
codec := JSONCodec{}
msg, _ := NewDispatch("MESSAGE_CREATE", 1, MessagePayload{
ID:        "01HXYZ",
ChannelID: "ch-1",
AuthorID:  "user-1",
Content:   "benchmark message",
Nonce:     "n-1",
Timestamp: 1700000000000,
})
data, _ := codec.Encode(msg)

b.ResetTimer()
for i := 0; i < b.N; i++ {
codec.Decode(data)
}
}
