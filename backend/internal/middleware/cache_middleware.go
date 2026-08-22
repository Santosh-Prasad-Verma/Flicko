package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// TTL Tiers for response caching
const (
	CacheShort  = 30 * time.Second
	CacheMedium = 5 * time.Minute
	CacheLong   = 30 * time.Minute
)

// cachedResponse represents a serialized HTTP response stored in Redis.
type cachedResponse struct {
	Status int                 `json:"status"`
	Header map[string][]string `json:"header"`
	Body   []byte              `json:"body"`
	ETag   string              `json:"etag"`
}

// CacheMiddleware provides Redis-backed response caching for GET requests.
type CacheMiddleware struct {
	rdb    redis.Cmdable
	logger *zap.Logger
}

// NewCacheMiddleware creates a new CacheMiddleware instance.
func NewCacheMiddleware(rdb redis.Cmdable, logger *zap.Logger) *CacheMiddleware {
	return &CacheMiddleware{
		rdb:    rdb,
		logger: logger,
	}
}

// responseBuffer captures response headers, status code, and body for caching.
type responseBuffer struct {
	http.ResponseWriter
	statusCode int
	body       bytes.Buffer
}

func (rb *responseBuffer) WriteHeader(statusCode int) {
	rb.statusCode = statusCode
	rb.ResponseWriter.WriteHeader(statusCode)
}

func (rb *responseBuffer) Write(b []byte) (int, error) {
	if rb.statusCode == 0 {
		rb.statusCode = http.StatusOK
	}
	rb.body.Write(b)
	return rb.ResponseWriter.Write(b)
}

func computeQueryHash(query string) string {
	if query == "" {
		return "empty"
	}
	sum := sha256.Sum256([]byte(query))
	return hex.EncodeToString(sum[:8])
}

// Cache returns a middleware handler that caches GET responses for the given TTL.
func (cm *CacheMiddleware) Cache(ttl time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Only cache GET requests
			if r.Method != http.MethodGet {
				next.ServeHTTP(w, r)
				return
			}

			// Check Cache-Control request header to skip cache if requested
			cc := r.Header.Get("Cache-Control")
			if strings.Contains(cc, "no-cache") || strings.Contains(cc, "no-store") {
				w.Header().Set("X-Cache", "MISS")
				next.ServeHTTP(w, r)
				return
			}

			userID := ""
			if val, ok := r.Context().Value(userIDKey).(string); ok && val != "" {
				userID = val
			} else {
				userID = "anon"
			}

			queryHash := computeQueryHash(r.URL.RawQuery)
			cacheKey := fmt.Sprintf("cache:%s:%s:%s", r.URL.Path, userID, queryHash)

			// Try fetching from Redis
			cachedData, err := cm.rdb.Get(r.Context(), cacheKey).Bytes()
			if err == nil && len(cachedData) > 0 {
				var cached cachedResponse
				if err := json.Unmarshal(cachedData, &cached); err == nil {
					// Check ETag for 304 Not Modified
					clientETag := r.Header.Get("If-None-Match")
					if clientETag != "" && clientETag == cached.ETag {
						w.Header().Set("ETag", cached.ETag)
						w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", int(ttl.Seconds())))
						w.Header().Set("X-Cache", "HIT")
						w.WriteHeader(http.StatusNotModified)
						return
					}

					// Write cached response headers
					for k, vals := range cached.Header {
						for _, v := range vals {
							w.Header().Add(k, v)
						}
					}
					w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", int(ttl.Seconds())))
					w.Header().Set("ETag", cached.ETag)
					w.Header().Set("X-Cache", "HIT")
					w.WriteHeader(cached.Status)
					// nosemgrep: go.lang.security.audit.xss.no-direct-write-to-responsewriter
					_, _ = w.Write(cached.Body)
					return
				}
			}

			// Cache Miss: record response
			buf := &responseBuffer{
				ResponseWriter: w,
				statusCode:     0,
			}
			buf.Header().Set("X-Cache", "MISS")

			next.ServeHTTP(buf, r)

			// Only cache successful 200 OK responses
			if buf.statusCode == http.StatusOK && cm.rdb != nil {
				etagSum := sha256.Sum256(buf.body.Bytes())
				etag := fmt.Sprintf("\"%x\"", etagSum[:16])

				// Prepare header map for serialization
				headers := make(map[string][]string)
				for k, v := range buf.Header() {
					headers[k] = v
				}

				cachedObj := cachedResponse{
					Status: buf.statusCode,
					Header: headers,
					Body:   buf.body.Bytes(),
					ETag:   etag,
				}

				if data, err := json.Marshal(cachedObj); err == nil {
					if err := cm.rdb.Set(r.Context(), cacheKey, data, ttl).Err(); err != nil && cm.logger != nil {
						cm.logger.Warn("failed to write response to redis cache", zap.String("key", cacheKey), zap.Error(err))
					}
				}

				w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", int(ttl.Seconds())))
				w.Header().Set("ETag", etag)
			}
		})
	}
}
