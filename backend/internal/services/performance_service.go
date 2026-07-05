package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
)

// ─── Rate Limiter Service ───────────────────────────────────────────────────
// Implements sliding window rate limiting using Redis sorted sets.

type RateLimitService interface {
	// Allow checks if the action is permitted under the rate limit.
	// Returns (allowed bool, retryAfter time.Duration, error)
	Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error)
	// IsExempt checks if a user is exempt from rate limiting (server owners, admins).
	IsExempt(ctx context.Context, userID string) (bool, error)
}

// RateLimitConfig defines per-endpoint rate limits.
type RateLimitConfig struct {
	MessageCreate RateRule
	FriendRequest RateRule
	WebhookCall   RateRule
	APIGeneral    RateRule
}

type RateRule struct {
	MaxRequests int
	Window      time.Duration
}

var DefaultRateLimits = RateLimitConfig{
	MessageCreate: RateRule{MaxRequests: 5, Window: 5 * time.Second},
	FriendRequest: RateRule{MaxRequests: 10, Window: time.Hour},
	WebhookCall:   RateRule{MaxRequests: 30, Window: time.Minute},
	APIGeneral:    RateRule{MaxRequests: 50, Window: time.Second},
}

type rateLimitService struct {
	redis cache.CacheLayer
}

func NewRateLimitService(redis cache.CacheLayer) RateLimitService {
	return &rateLimitService{redis: redis}
}

// Allow implements a sliding window rate limiter using Redis.
// Pattern: ZADD sorted set with timestamps, ZRANGEBYSCORE to count recent entries.
func (s *rateLimitService) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error) {
	now := time.Now()
	windowStart := now.Add(-window)

	// Clean up old entries
	cleanKey := fmt.Sprintf("ratelimit:%s", key)

	// Remove entries outside the window
	err := s.redis.ZRemRangeByScore(ctx, cleanKey, "-inf", fmt.Sprintf("%d", windowStart.UnixMilli()))
	if err != nil {
		return false, 0, fmt.Errorf("failed to clean window: %w", err)
	}

	// Count current entries in window
	count, err := s.redis.ZCard(ctx, cleanKey)
	if err != nil {
		return false, 0, fmt.Errorf("failed to count requests: %w", err)
	}

	if count >= int64(limit) {
		// Find oldest entry to calculate retry-after
		oldest, err := s.redis.ZRangeFirst(ctx, cleanKey)
		if err != nil {
			return false, window, nil
		}
		retryAfter := window - now.Sub(time.UnixMilli(oldest))
		if retryAfter < 0 {
			retryAfter = time.Second
		}
		return false, retryAfter, nil
	}

	// Add current request
	err = s.redis.ZAdd(ctx, cleanKey, float64(now.UnixMilli()), fmt.Sprintf("%d", now.UnixNano()))
	if err != nil {
		return false, 0, fmt.Errorf("failed to record request: %w", err)
	}

	// Set TTL on the key
	_ = s.redis.Expire(ctx, cleanKey, window+time.Second)

	return true, 0, nil
}

func (s *rateLimitService) IsExempt(ctx context.Context, userID string) (bool, error) {
	exemptKey := fmt.Sprintf("ratelimit:exempt:%s", userID)
	val, err := s.redis.Get(ctx, exemptKey)
	if err != nil {
		return false, nil // Default to not exempt
	}
	return val == "true", nil
}

// ─── Caching Strategy Service ───────────────────────────────────────────────
// Implements the cache-aside pattern with configurable TTLs.

type CacheStrategy struct {
	UserSettingsTTL time.Duration
	PermissionTTL   time.Duration
	PresenceTTL     time.Duration
	MemberListTTL   time.Duration
	EmbedDataTTL    time.Duration
}

var DefaultCacheStrategy = CacheStrategy{
	UserSettingsTTL: time.Hour,
	PermissionTTL:   5 * time.Minute,
	PresenceTTL:     30 * time.Second,
	MemberListTTL:   5 * time.Minute,
	EmbedDataTTL:    24 * time.Hour,
}

type CacheManager interface {
	GetOrSet(ctx context.Context, key string, ttl time.Duration, loader func() (string, error)) (string, error)
	Invalidate(ctx context.Context, pattern string) error
	GetHitRate(ctx context.Context) (float64, error)
}

type cacheManager struct {
	redis cache.CacheLayer
	hits  int64
	total int64
}

func NewCacheManager(redis cache.CacheLayer) CacheManager {
	return &cacheManager{redis: redis}
}

func (cm *cacheManager) GetOrSet(ctx context.Context, key string, ttl time.Duration, loader func() (string, error)) (string, error) {
	cm.total++

	// Try cache first
	val, err := cm.redis.Get(ctx, key)
	if err == nil && val != "" {
		cm.hits++
		return val, nil
	}

	// Cache miss — load from source
	result, err := loader()
	if err != nil {
		return "", err
	}

	// Store in cache
	_ = cm.redis.Set(ctx, key, result, ttl)
	return result, nil
}

func (cm *cacheManager) Invalidate(ctx context.Context, pattern string) error {
	return cm.redis.DeletePattern(ctx, pattern)
}

func (cm *cacheManager) GetHitRate(ctx context.Context) (float64, error) {
	if cm.total == 0 {
		return 0, nil
	}
	return float64(cm.hits) / float64(cm.total), nil
}

// ─── Monitoring Service ─────────────────────────────────────────────────────

type MetricsCollector interface {
	RecordAPILatency(endpoint string, duration time.Duration, statusCode int)
	RecordDBQueryTime(query string, duration time.Duration)
	RecordWSConnections(count int)
	RecordCacheHitRate(rate float64)
	RecordError(endpoint string, err error)
	GetMetrics(ctx context.Context) (*SystemMetrics, error)
}

type SystemMetrics struct {
	RequestsPerSecond float64        `json:"requests_per_second"`
	LatencyP50        time.Duration  `json:"latency_p50"`
	LatencyP95        time.Duration  `json:"latency_p95"`
	LatencyP99        time.Duration  `json:"latency_p99"`
	ErrorRate         float64        `json:"error_rate"`
	WSConnections     int            `json:"ws_connections"`
	CacheHitRate      float64        `json:"cache_hit_rate"`
	TopEndpoints      map[string]int `json:"top_endpoints"`
	SlowQueries       []SlowQuery    `json:"slow_queries"`
}

type SlowQuery struct {
	Query    string        `json:"query"`
	Duration time.Duration `json:"duration"`
	Time     time.Time     `json:"time"`
}

type metricsCollector struct {
	redis      cache.CacheLayer
	latencies  []latencyEntry
	errorCount int64
	totalCount int64
}

type latencyEntry struct {
	Endpoint   string
	Duration   time.Duration
	StatusCode int
	Time       time.Time
}

func NewMetricsCollector(redis cache.CacheLayer) MetricsCollector {
	return &metricsCollector{
		redis:     redis,
		latencies: make([]latencyEntry, 0, 1000),
	}
}

func (mc *metricsCollector) RecordAPILatency(endpoint string, duration time.Duration, statusCode int) {
	mc.totalCount++
	if statusCode >= 400 {
		mc.errorCount++
	}
	entry := latencyEntry{Endpoint: endpoint, Duration: duration, StatusCode: statusCode, Time: time.Now()}
	if len(mc.latencies) < 10000 { // Ring buffer cap
		mc.latencies = append(mc.latencies, entry)
	}
}

func (mc *metricsCollector) RecordDBQueryTime(query string, duration time.Duration) {
	// Log slow queries (> 100ms)
	if duration > 100*time.Millisecond {
		fmt.Printf("[SLOW_QUERY] %s took %v\n", query, duration)
	}
}

func (mc *metricsCollector) RecordWSConnections(count int) {
	_ = mc.redis.Set(context.Background(), "metrics:ws_connections", fmt.Sprintf("%d", count), time.Minute)
}

func (mc *metricsCollector) RecordCacheHitRate(rate float64) {
	_ = mc.redis.Set(context.Background(), "metrics:cache_hit_rate", fmt.Sprintf("%.4f", rate), time.Minute)
}

func (mc *metricsCollector) RecordError(endpoint string, err error) {
	mc.errorCount++
	fmt.Printf("[ERROR] %s: %v\n", endpoint, err)
}

func (mc *metricsCollector) GetMetrics(ctx context.Context) (*SystemMetrics, error) {
	metrics := &SystemMetrics{
		TopEndpoints: make(map[string]int),
	}

	if mc.totalCount > 0 {
		metrics.ErrorRate = float64(mc.errorCount) / float64(mc.totalCount)
	}

	return metrics, nil
}
