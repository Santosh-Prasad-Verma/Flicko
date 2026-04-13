package middleware

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// testRedis spins up a miniredis instance and returns an in-process redis.Cmdable.
func testRedis(t *testing.T) (*miniredis.Miniredis, redis.Cmdable) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = rdb.Close() })
	return mr, rdb
}

// testConfig returns a fast-poll config suitable for tests.
func testConfig() IdempotencyConfig {
	return IdempotencyConfig{
		TTL:          10 * time.Second,
		PollInterval: 5 * time.Millisecond,
		PollTimeout:  2 * time.Second,
	}
}

// validULID is a syntactically valid ULID for test use.
const validULID = "01ARZ3NDEKTSV4RRFFQ69G5FAV"

// validUUID is a syntactically valid UUID v4 for test use.
const validUUID = "550e8400-e29b-41d4-a716-446655440000"

// echoHandler replies with a fixed JSON body and 201 status.
func echoHandler(status int, body string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	})
}

// slowHandler takes a controlled amount of time before responding.
func slowHandler(delay time.Duration, status int, body string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(delay)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	})
}

// countHandler increments an atomic counter on each invocation.
func countHandler(counter *atomic.Int32, status int, body string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		counter.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	})
}

func doRequest(handler http.Handler, method, path, idempotencyKey string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, nil)
	if idempotencyKey != "" {
		req.Header.Set("Idempotency-Key", idempotencyKey)
	}
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	return rr
}

func parseError(t *testing.T, body []byte) (code, message string) {
	t.Helper()
	var resp struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		t.Fatalf("failed to parse error body: %v\nbody: %s", err, body)
	}
	return resp.Error.Code, resp.Error.Message
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

func TestIdempotency_POST_MissingKey_Returns400(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(echoHandler(201, `{"id":"1"}`))

	rr := doRequest(handler, http.MethodPost, "/test", "")

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}

	code, _ := parseError(t, rr.Body.Bytes())
	if code != "MISSING_IDEMPOTENCY_KEY" {
		t.Fatalf("expected MISSING_IDEMPOTENCY_KEY, got %q", code)
	}
}

func TestIdempotency_POST_InvalidKeyFormat_Returns400(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(echoHandler(201, `{"id":"1"}`))

	for _, key := range []string{"short", "not-a-valid-ulid-or-uuid!", ""} {
		if key == "" {
			continue // tested separately
		}
		rr := doRequest(handler, http.MethodPost, "/test", key)
		if rr.Code != http.StatusBadRequest {
			t.Fatalf("key=%q: expected 400, got %d", key, rr.Code)
		}
		code, _ := parseError(t, rr.Body.Bytes())
		if code != "INVALID_IDEMPOTENCY_KEY" {
			t.Fatalf("key=%q: expected INVALID_IDEMPOTENCY_KEY, got %q", key, code)
		}
	}
}

func TestIdempotency_POST_ValidULID_FirstCall_StatusMiss(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(echoHandler(201, `{"id":"1"}`))

	rr := doRequest(handler, http.MethodPost, "/test", validULID)

	if rr.Code != 201 {
		t.Fatalf("expected 201, got %d", rr.Code)
	}
	if got := rr.Header().Get("Idempotency-Status"); got != "miss" {
		t.Fatalf("expected Idempotency-Status=miss, got %q", got)
	}
	if body := rr.Body.String(); body != `{"id":"1"}` {
		t.Fatalf("unexpected body: %s", body)
	}
}

func TestIdempotency_POST_ValidUUID_FirstCall_StatusMiss(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(echoHandler(201, `{"id":"1"}`))

	rr := doRequest(handler, http.MethodPost, "/test", validUUID)

	if rr.Code != 201 {
		t.Fatalf("expected 201, got %d", rr.Code)
	}
	if got := rr.Header().Get("Idempotency-Status"); got != "miss" {
		t.Fatalf("expected Idempotency-Status=miss, got %q", got)
	}
}

func TestIdempotency_POST_DuplicateReturnsCache_StatusHit(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 201, `{"id":"1"}`))

	// First call
	rr1 := doRequest(handler, http.MethodPost, "/test", validULID)
	if rr1.Code != 201 {
		t.Fatalf("first call: expected 201, got %d", rr1.Code)
	}

	// Second call — same key
	rr2 := doRequest(handler, http.MethodPost, "/test", validULID)
	if rr2.Code != 201 {
		t.Fatalf("second call: expected 201, got %d", rr2.Code)
	}
	if got := rr2.Header().Get("Idempotency-Status"); got != "hit" {
		t.Fatalf("expected Idempotency-Status=hit, got %q", got)
	}
	if body := rr2.Body.String(); body != `{"id":"1"}` {
		t.Fatalf("cached body mismatch: %s", body)
	}

	// Handler should only have been called once.
	if c := calls.Load(); c != 1 {
		t.Fatalf("expected handler called 1 time, got %d", c)
	}
}

func TestIdempotency_POST_DifferentNonces_ProcessIndependently(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 200, `{"ok":true}`))

	_ = doRequest(handler, http.MethodPost, "/test", validULID)
	_ = doRequest(handler, http.MethodPost, "/test", validUUID)

	if c := calls.Load(); c != 2 {
		t.Fatalf("expected handler called 2 times for different nonces, got %d", c)
	}
}

func TestIdempotency_POST_ConcurrentDuplicates_OnlyOneProcesses(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(slowHandler(100*time.Millisecond, 201, `{"id":"concurrent"}`))

	var wg sync.WaitGroup
	results := make([]*httptest.ResponseRecorder, 2)

	wg.Add(2)
	go func() {
		defer wg.Done()
		results[0] = doRequest(handler, http.MethodPost, "/test", validULID)
	}()
	// Small delay so second request arrives while first holds the lock.
	time.Sleep(10 * time.Millisecond)
	go func() {
		defer wg.Done()
		results[1] = doRequest(handler, http.MethodPost, "/test", validULID)
	}()
	wg.Wait()

	// Both should return 201 with the same body.
	for i, rr := range results {
		if rr.Code != 201 {
			t.Fatalf("goroutine %d: expected 201, got %d", i, rr.Code)
		}
		if body := rr.Body.String(); body != `{"id":"concurrent"}` {
			t.Fatalf("goroutine %d: unexpected body: %s", i, body)
		}
	}

	// Exactly one should be a "hit".
	var hits, misses int
	for _, rr := range results {
		switch rr.Header().Get("Idempotency-Status") {
		case "hit":
			hits++
		case "miss":
			misses++
		}
	}
	if hits != 1 || misses != 1 {
		t.Fatalf("expected 1 hit + 1 miss, got hits=%d misses=%d", hits, misses)
	}
}

func TestIdempotency_POST_Non2xx_NotCached(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 422, `{"error":"bad"}`))

	_ = doRequest(handler, http.MethodPost, "/test", validULID)
	_ = doRequest(handler, http.MethodPost, "/test", validULID)

	// Non-2xx should NOT be cached — handler called both times.
	if c := calls.Load(); c != 2 {
		t.Fatalf("expected handler called 2 times for non-2xx, got %d", c)
	}
}

func TestIdempotency_POST_LargeBody_NotCached(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	// 12 KB body — exceeds the 10 KB maxCacheableBody limit in captureWriter.
	bigBody := strings.Repeat("X", 12*1024)

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 200, bigBody))

	_ = doRequest(handler, http.MethodPost, "/test", validULID)
	_ = doRequest(handler, http.MethodPost, "/test", validULID)

	// Large body → not cacheable → handler called both times.
	if c := calls.Load(); c != 2 {
		t.Fatalf("expected handler called 2 times for large body, got %d", c)
	}
}

func TestIdempotency_POST_ExpiredNonce_AllowsReprocessing(t *testing.T) {
	mr, rdb := testRedis(t)
	log := zap.NewNop()

	cfg := testConfig()
	cfg.TTL = 1 * time.Second

	var calls atomic.Int32
	mw := Idempotency(rdb, cfg, log)
	handler := mw(countHandler(&calls, 200, `{"ok":true}`))

	_ = doRequest(handler, http.MethodPost, "/test", validULID)
	if c := calls.Load(); c != 1 {
		t.Fatalf("expected 1 call after first request, got %d", c)
	}

	// Fast-forward miniredis past the TTL.
	mr.FastForward(2 * time.Second)

	_ = doRequest(handler, http.MethodPost, "/test", validULID)
	if c := calls.Load(); c != 2 {
		t.Fatalf("expected 2 calls after TTL expiry, got %d", c)
	}
}

func TestIdempotency_PATCH_MissingKey_SkipsIdempotency(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 200, `{"ok":true}`))

	rr := doRequest(handler, http.MethodPatch, "/test", "")

	if rr.Code != 200 {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	// No idempotency header should be set.
	if got := rr.Header().Get("Idempotency-Status"); got != "" {
		t.Fatalf("expected no Idempotency-Status header, got %q", got)
	}
	if c := calls.Load(); c != 1 {
		t.Fatalf("expected handler called once, got %d", c)
	}
}

func TestIdempotency_PATCH_WithKey_DeduplicatesLikePOST(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 200, `{"updated":true}`))

	rr1 := doRequest(handler, http.MethodPatch, "/test", validULID)
	if rr1.Code != 200 {
		t.Fatalf("expected 200, got %d", rr1.Code)
	}
	if got := rr1.Header().Get("Idempotency-Status"); got != "miss" {
		t.Fatalf("expected miss, got %q", got)
	}

	rr2 := doRequest(handler, http.MethodPatch, "/test", validULID)
	if rr2.Code != 200 {
		t.Fatalf("expected 200, got %d", rr2.Code)
	}
	if got := rr2.Header().Get("Idempotency-Status"); got != "hit" {
		t.Fatalf("expected hit, got %q", got)
	}

	if c := calls.Load(); c != 1 {
		t.Fatalf("expected handler called once, got %d", c)
	}
}

func TestIdempotency_GET_PassesThrough(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 200, `{"list":[]}`))

	rr := doRequest(handler, http.MethodGet, "/test", validULID)

	if rr.Code != 200 {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	// No idempotency headers on GET.
	if got := rr.Header().Get("Idempotency-Status"); got != "" {
		t.Fatalf("expected no Idempotency-Status for GET, got %q", got)
	}
}

func TestIdempotency_DELETE_PassesThrough(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 204, ""))

	rr := doRequest(handler, http.MethodDelete, "/test", validULID)

	if rr.Code != 204 {
		t.Fatalf("expected 204, got %d", rr.Code)
	}
}

func TestIdempotency_RedisDown_SkipsDedup(t *testing.T) {
	mr, rdb := testRedis(t)
	log := zap.NewNop()

	var calls atomic.Int32
	mw := Idempotency(rdb, testConfig(), log)
	handler := mw(countHandler(&calls, 201, `{"id":"1"}`))

	// Close Redis to simulate failure.
	mr.Close()

	rr := doRequest(handler, http.MethodPost, "/test", validULID)

	// Request should succeed despite Redis being down.
	if rr.Code != 201 {
		t.Fatalf("expected 201 even with Redis down, got %d", rr.Code)
	}
	if c := calls.Load(); c != 1 {
		t.Fatalf("expected handler called once, got %d", c)
	}
}

func TestIdempotency_PollTimeout_FallsThrough(t *testing.T) {
	_, rdb := testRedis(t)
	log := zap.NewNop()

	cfg := testConfig()
	cfg.PollTimeout = 50 * time.Millisecond

	// Pre-set a "processing" sentinel in Redis to simulate a stuck request.
	key := keyPrefix + validULID
	_ = rdb.(*redis.Client).Set(context.Background(), key, sentinel, 10*time.Second).Err()

	var calls atomic.Int32
	mw := Idempotency(rdb, cfg, log)
	handler := mw(countHandler(&calls, 201, `{"id":"1"}`))

	rr := doRequest(handler, http.MethodPost, "/test", validULID)

	// After poll timeout, should process normally.
	if rr.Code != 201 {
		t.Fatalf("expected 201 after poll timeout, got %d", rr.Code)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// isValidKey unit tests
// ─────────────────────────────────────────────────────────────────────────────

func TestIsValidKey(t *testing.T) {
	tests := []struct {
		key  string
		want bool
	}{
		// Valid ULIDs
		{"01ARZ3NDEKTSV4RRFFQ69G5FAV", true},
		{"7ZZZZZZZZZZZZZZZZZZZZZZZZZ", true},

		// Valid UUIDs
		{"550e8400-e29b-41d4-a716-446655440000", true},
		{"00000000-0000-0000-0000-000000000000", true},
		{"ffffffff-ffff-ffff-ffff-ffffffffffff", true},

		// Invalid
		{"", false},
		{"too-short", false},
		{"01ARZ3NDEKTSV4RRFFQ69G5FA", false},   // 25 chars (ULID minus one)
		{"01ARZ3NDEKTSV4RRFFQ69G5FAVX", false}, // 27 chars (ULID plus one)
		{"01arz3ndektsv4rrffq69g5fav", false},  // lowercase ULID (invalid Crockford)
		{"550e8400-e29b-41d4-a716", false},     // truncated UUID
		{"not-a-valid-key-at-all!!", false},
	}

	for _, tt := range tests {
		if got := isValidKey(tt.key); got != tt.want {
			t.Errorf("isValidKey(%q) = %v, want %v", tt.key, got, tt.want)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// encodeResponse / decodeResponse unit tests
// ─────────────────────────────────────────────────────────────────────────────

func TestEncodeDecodeResponse(t *testing.T) {
	tests := []struct {
		status int
		body   string
	}{
		{200, `{"ok":true}`},
		{201, `{"id":"01ARZ3NDEKTSV4RRFFQ69G5FAV"}`},
		{204, ""},
		{200, `{"data":"has:colons:in:body"}`},
	}

	for _, tt := range tests {
		encoded := encodeResponse(tt.status, []byte(tt.body))
		status, body, err := decodeResponse(encoded)
		if err != nil {
			t.Fatalf("decodeResponse(%q) error: %v", encoded, err)
		}
		if status != tt.status {
			t.Errorf("status: got %d, want %d", status, tt.status)
		}
		if string(body) != tt.body {
			t.Errorf("body: got %q, want %q", body, tt.body)
		}
	}
}

func TestDecodeResponse_InvalidFormat(t *testing.T) {
	invalids := []string{
		"",
		"nodash",
		"abc:body",
	}
	for _, s := range invalids {
		_, _, err := decodeResponse(s)
		if err == nil {
			t.Errorf("decodeResponse(%q) expected error, got nil", s)
		}
	}
}
