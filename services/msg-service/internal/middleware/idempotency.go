package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const (
	// headerIdempotencyKey is the request header clients must set.
	headerIdempotencyKey = "Idempotency-Key"

	// headerIdempotencyStatus is the response header indicating cache hit/miss.
	headerIdempotencyStatus = "Idempotency-Status"

	// keyPrefix is the Redis key namespace.
	keyPrefix = "flicko:idempotency:"

	// sentinel is written to Redis via SET NX when a request starts processing.
	// Concurrent duplicates see this value and poll until the real response
	// replaces it, or until pollTimeout expires.
	sentinel = "__processing__"

	// pollInterval is how often a waiting duplicate checks for the result.
	pollInterval = 50 * time.Millisecond

	// pollTimeout is the maximum time a duplicate request waits for the
	// first request to finish and store a result.
	pollTimeout = 5 * time.Second
)

// ─────────────────────────────────────────────────────────────────────────────
// Key validation
// ─────────────────────────────────────────────────────────────────────────────

// ulidPattern matches a Crockford Base32 ULID (26 uppercase alphanumeric chars).
var ulidPattern = regexp.MustCompile(`^[0-9A-HJKMNP-TV-Z]{26}$`)

// uuidPattern matches a standard UUID with hyphens (8-4-4-4-12).
var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// isValidKey checks whether the nonce is a valid ULID or UUID.
func isValidKey(key string) bool {
	return ulidPattern.MatchString(key) || uuidPattern.MatchString(key)
}

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

// IdempotencyConfig controls the middleware's behavior.
type IdempotencyConfig struct {
	TTL          time.Duration // How long cached responses live in Redis.
	PollInterval time.Duration // How often duplicates poll for a result.
	PollTimeout  time.Duration // Max wait time for a concurrent duplicate.
}

// DefaultIdempotencyConfig returns production defaults.
func DefaultIdempotencyConfig() IdempotencyConfig {
	return IdempotencyConfig{
		TTL:          300 * time.Second, // 5 minutes
		PollInterval: pollInterval,
		PollTimeout:  pollTimeout,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Middleware
// ─────────────────────────────────────────────────────────────────────────────

// Idempotency returns chi middleware that deduplicates POST and PATCH requests
// using the Idempotency-Key header and Redis.
//
// Behavior by method:
//   - POST:  Idempotency-Key is REQUIRED. Missing → 400.
//   - PATCH: Idempotency-Key is optional. Missing → skip idempotency.
//   - Other: Middleware is a no-op (passes through).
//
// Concurrency:
//
//	Uses Redis SET NX with a "processing" sentinel. The first request
//	acquires the lock. Concurrent duplicates poll every 50 ms (max 5 s)
//	until the result appears.
//
// Redis failure:
//
//	If Redis is unreachable, the middleware logs a warning and passes
//	the request through without deduplication. Availability > consistency.
func Idempotency(rdb redis.Cmdable, cfg IdempotencyConfig, log *zap.Logger) func(http.Handler) http.Handler {
	if cfg.TTL <= 0 {
		cfg.TTL = 300 * time.Second
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = pollInterval
	}
	if cfg.PollTimeout <= 0 {
		cfg.PollTimeout = pollTimeout
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// ── Method gate ────────────────────────────────────────
			if r.Method != http.MethodPost && r.Method != http.MethodPatch {
				next.ServeHTTP(w, r)
				return
			}

			// ── Extract key ────────────────────────────────────────
			nonce := r.Header.Get(headerIdempotencyKey)

			if nonce == "" {
				if r.Method == http.MethodPost {
					// POST requires an idempotency key.
					writeIdempotencyError(w, http.StatusBadRequest,
						"MISSING_IDEMPOTENCY_KEY",
						"Idempotency-Key header is required for POST requests")
					return
				}
				// PATCH: optional — skip idempotency.
				next.ServeHTTP(w, r)
				return
			}

			// ── Validate key format ────────────────────────────────
			if !isValidKey(nonce) {
				writeIdempotencyError(w, http.StatusBadRequest,
					"INVALID_IDEMPOTENCY_KEY",
					"Idempotency-Key must be a valid ULID or UUID")
				return
			}

			redisKey := keyPrefix + nonce

			// ── Try to acquire processing lock ─────────────────────
			// SET NX with TTL: if the key doesn't exist, we set "processing"
			// and proceed. If it exists (duplicate), we enter the poll loop.
			acquired, err := rdb.SetNX(r.Context(), redisKey, sentinel, cfg.TTL).Result()
			if err != nil {
				// Redis is down — degrade gracefully.
				log.Warn("idempotency: redis SetNX failed, skipping dedup",
					zap.String("nonce", nonce),
					zap.Error(err),
				)
				next.ServeHTTP(w, r)
				return
			}

			if !acquired {
				// Key already exists — either a completed response or "processing".
				cached, hitErr := waitForResult(r.Context(), rdb, redisKey, cfg)
				if hitErr != nil {
					// Timeout or Redis failure while polling.
					log.Warn("idempotency: poll failed, processing request normally",
						zap.String("nonce", nonce),
						zap.Error(hitErr),
					)
					next.ServeHTTP(w, r)
					return
				}

				// Replay the cached response.
				w.Header().Set(headerIdempotencyStatus, "hit")
				replayCachedResponse(w, cached)
				return
			}

			// ── We own this nonce — process the request ────────────
			cw := newCaptureWriter(w)
			cw.Header().Set(headerIdempotencyStatus, "miss")
			next.ServeHTTP(cw, r)

			// ── Store the response in Redis ────────────────────────
			if cw.isCacheable() {
				encoded := encodeResponse(cw.status, cw.capturedBody())
				if setErr := rdb.Set(r.Context(), redisKey, encoded, cfg.TTL).Err(); setErr != nil {
					log.Warn("idempotency: failed to store response",
						zap.String("nonce", nonce),
						zap.Error(setErr),
					)
					// Delete the sentinel so future retries aren't stuck.
					_ = rdb.Del(context.Background(), redisKey)
				}
			} else {
				// Response is not cacheable (non-2xx or too large).
				// Delete the sentinel so future retries try again.
				_ = rdb.Del(context.Background(), redisKey)
			}
		})
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Concurrent duplicate handling
// ─────────────────────────────────────────────────────────────────────────────

// waitForResult polls Redis for a completed response. If the key holds the
// "processing" sentinel, we wait up to PollTimeout. Returns the raw cached
// value once it's a real response.
func waitForResult(ctx context.Context, rdb redis.Cmdable, key string, cfg IdempotencyConfig) (string, error) {
	deadline := time.After(cfg.PollTimeout)
	ticker := time.NewTicker(cfg.PollInterval)
	defer ticker.Stop()

	for {
		val, err := rdb.Get(ctx, key).Result()
		if err != nil {
			return "", fmt.Errorf("redis GET: %w", err)
		}

		// If it's no longer the sentinel, the first request finished.
		if val != sentinel {
			return val, nil
		}

		// Still processing — wait and retry.
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-deadline:
			return "", fmt.Errorf("timeout waiting for idempotent response (key=%s)", key)
		case <-ticker.C:
			// retry
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Response encoding / decoding / replay
// ─────────────────────────────────────────────────────────────────────────────

// Cached format: "{status_code}:{response_body}"
// Example: "201:{\"id\":\"01ARZ3NDEKTSV4RRFFQ69G5FAV\"}"

// encodeResponse serializes status + body for Redis storage.
func encodeResponse(status int, body []byte) string {
	return strconv.Itoa(status) + ":" + string(body)
}

// decodeResponse parses a cached value into status + body.
func decodeResponse(cached string) (int, []byte, error) {
	// Find the first colon (status codes are always 3 digits).
	idx := strings.IndexByte(cached, ':')
	if idx < 1 {
		return 0, nil, fmt.Errorf("invalid cached response format: %q", cached)
	}

	status, err := strconv.Atoi(cached[:idx])
	if err != nil {
		return 0, nil, fmt.Errorf("invalid status in cached response: %w", err)
	}

	body := []byte(cached[idx+1:])
	return status, body, nil
}

// replayCachedResponse writes the previously captured response to the client.
func replayCachedResponse(w http.ResponseWriter, cached string) {
	status, body, err := decodeResponse(cached)
	if err != nil {
		// Corrupt cache entry — shouldn't happen, but handle defensively.
		writeIdempotencyError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "idempotency cache corrupted")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if len(body) > 0 {
		// nosemgrep: go.lang.security.audit.xss.no-direct-write-to-responsewriter
		_, _ = w.Write(body)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Error helper
// ─────────────────────────────────────────────────────────────────────────────

// writeIdempotencyError writes a structured JSON error response.
func writeIdempotencyError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"code":    code,
			"message": message,
		},
	})
}
