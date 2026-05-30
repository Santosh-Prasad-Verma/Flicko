package message_summary

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
)

// RateLimit guards the summary endpoint against per-user abuse.
//
// We use a Redis sorted set per user with one entry per request. The score is
// the unix-millis timestamp of the request and the member is a unique nonce.
// On each call we:
//
//  1. trim entries older than the window
//  2. read the current count
//  3. if under the cap, ZADD a new entry and EXPIRE the key
//
// This is effectively a sliding-window rate limit: the limit is "X requests
// in the last Y" rather than the cheaper but bursty fixed-bucket approach.
type RateLimit struct {
	c cache.CacheLayer

	// Per-user cap.
	UserDailyCap int
	// Window length.
	Window time.Duration
}

// NewRateLimit returns a configured limiter. Defaults follow the PRD:
// 50 requests / 24h per user.
func NewRateLimit(c cache.CacheLayer) *RateLimit {
	return &RateLimit{
		c:            c,
		UserDailyCap: 50,
		Window:       24 * time.Hour,
	}
}

// Allow consumes 1 request token for userID; returns (allowed, remaining, err).
//
// remaining is a hint shown in the UI ("X of 50 left today"). On Redis
// failure we fail-open: it is a far worse user experience to refuse a free
// feature than to risk a brief over-cap window after a transient outage.
func (r *RateLimit) Allow(ctx context.Context, userID string) (bool, int, error) {
	if r == nil || r.c == nil {
		return true, r.cap(), nil
	}

	key := "summary:ratelimit:" + userID
	now := time.Now()
	windowStart := now.Add(-r.Window).UnixMilli()

	// Trim old entries. Use ZRemRangeByScore with -inf / windowStart.
	if err := r.c.ZRemRangeByScore(ctx, key, "-inf", strconv.FormatInt(windowStart, 10)); err != nil {
		return true, r.cap(), nil // fail-open
	}

	count, err := r.c.ZCard(ctx, key)
	if err != nil {
		return true, r.cap(), nil // fail-open
	}
	if int(count) >= r.cap() {
		return false, 0, nil
	}

	member := strconv.FormatInt(now.UnixNano(), 36)
	if err := r.c.ZAdd(ctx, key, float64(now.UnixMilli()), member); err != nil {
		return true, r.cap() - int(count), nil // fail-open
	}
	if err := r.c.Expire(ctx, key, r.Window); err != nil {
		// Non-fatal.
		_ = err
	}
	remaining := r.cap() - int(count) - 1
	if remaining < 0 {
		remaining = 0
	}
	return true, remaining, nil
}

// Remaining peeks the current count without consuming a token. Used to render
// "X left today" hints when the user opens the pill but hasn't tapped yet.
func (r *RateLimit) Remaining(ctx context.Context, userID string) (int, error) {
	if r == nil || r.c == nil {
		return r.cap(), nil
	}
	key := "summary:ratelimit:" + userID
	windowStart := time.Now().Add(-r.Window).UnixMilli()
	if err := r.c.ZRemRangeByScore(ctx, key, "-inf", strconv.FormatInt(windowStart, 10)); err != nil {
		return r.cap(), nil
	}
	count, err := r.c.ZCard(ctx, key)
	if err != nil {
		return r.cap(), nil
	}
	rem := r.cap() - int(count)
	if rem < 0 {
		rem = 0
	}
	return rem, nil
}

func (r *RateLimit) cap() int {
	if r.UserDailyCap <= 0 {
		return 50
	}
	return r.UserDailyCap
}

// FormatErr produces a stable refusal-reason string used in audit logs.
func FormatErr(remaining int) string {
	return fmt.Sprintf("rate_limited remaining=%d", remaining)
}
