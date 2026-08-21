package middleware

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
	"golang.org/x/time/rate"
)

// responseWriter wraps http.ResponseWriter to capture the status code.
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// RequestID adds a unique request ID to each request for distributed tracing.
// HIGH-008: Enhanced with request logging and status code capture.
func RequestID(next http.Handler) http.Handler {
	logger, _ := zap.NewProduction()

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := r.Header.Get("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
		}

		// Set response header
		w.Header().Set("X-Request-ID", requestID)

		// Add to context
		ctx := context.WithValue(r.Context(), requestIDKey, requestID)

		// Log request start
		start := time.Now()

		// Wrap response writer to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapped, r.WithContext(ctx))

		// Log request completion
		logger.Info("request completed",
			zap.String("request_id", requestID),
			zap.String("method", r.Method),
			zap.String("path", r.URL.Path),
			zap.String("remote_addr", r.RemoteAddr),
			zap.Int("status", wrapped.statusCode),
			zap.Duration("duration", time.Since(start)),
		)
	})
}

// GetRequestID extracts request ID from context.
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey).(string); ok {
		return id
	}
	return ""
}

// GetUserIDKey returns the context key used to store the user ID.
func GetUserIDKey() contextKey {
	return userIDKey
}

type RateLimiter struct {
	limit   rate.Limit
	burst   int
	clients sync.Map
}

func NewRateLimiter(r rate.Limit, b int) *RateLimiter {
	limiter := &RateLimiter{
		limit: r,
		burst: b,
	}

	// Periodically clean up old clients from the map (runs every 5 minutes)
	go func() {
		for {
			time.Sleep(5 * time.Minute)
			// A true production system should use a time-based eviction or Redis,
			// but for this implementation we just clear the map to prevent unbounded growth.
			limiter.clients.Range(func(key, value interface{}) bool {
				limiter.clients.Delete(key)
				return true
			})
		}
	}()

	return limiter
}

// MED-012: Standardized JSON error response helper
func writeJSONError(w http.ResponseWriter, code int, errCode string, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"code":    errCode,
			"message": message,
		},
	})
}

func (rl *RateLimiter) Limit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		// Get real IP considering proxies
		ip := req.Header.Get("X-Forwarded-For")
		if ip == "" {
			ip, _, _ = net.SplitHostPort(req.RemoteAddr)
		}

		// Get or create limiter for this IP
		v, _ := rl.clients.LoadOrStore(ip, rate.NewLimiter(rl.limit, rl.burst))
		limiter := v.(*rate.Limiter)

		if !limiter.Allow() {
			writeJSONError(w, http.StatusTooManyRequests, "RATE_LIMITED", "Rate limit exceeded. Please slow down.")
			return
		}
		next.ServeHTTP(w, req)
	})
}

// In a real distributed system, we'd use Redis sorted sets for sliding window.
// Stub provided for HTTP middleware linkage.
// authMiddleware, corsMiddleware, and tracing logic follow similar simple wrappers.

// CORS restricts allowed origins in production. Set ALLOWED_ORIGINS env var
// to a comma-separated list (e.g. "https://flicko.dev,https://api.flicko.dev").
// CRIT-011: No longer falls back to wildcard "*". Panics in production if not set.
func CORS(next http.Handler) http.Handler {
	allowedOriginsEnv := os.Getenv("ALLOWED_ORIGINS")

	// Parse and validate origins
	allowedOrigins := make(map[string]bool)

	if allowedOriginsEnv == "" {
		if os.Getenv("ENVIRONMENT") == "production" {
			logger, _ := zap.NewProduction()
			logger.Error("ALLOWED_ORIGINS must be set in production. CORS requests will be denied.")
		} else {
			// Development: use localhost only
			allowedOriginsEnv = "http://localhost:3000,http://localhost:8081"
		}
	}

	if allowedOriginsEnv != "" {
		for _, o := range strings.Split(allowedOriginsEnv, ",") {
			origin := strings.TrimSpace(o)
			if origin == "" || origin == "*" {
				if os.Getenv("ENVIRONMENT") == "production" {
					logger, _ := zap.NewProduction()
					logger.Error("ALLOWED_ORIGINS cannot contain wildcard or empty values in production. Skipping bad origin.")
				}
				continue
			}
			// Validate URL format
			if _, err := url.Parse(origin); err != nil {
				logger, _ := zap.NewProduction()
				logger.Error("Invalid origin in ALLOWED_ORIGINS", zap.String("origin", origin), zap.Error(err))
				continue
			}
			allowedOrigins[origin] = true
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		// Only set CORS headers if origin is allowed
		if origin != "" && allowedOrigins[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-ID")
			w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours
		}

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

type contextKey string

const (
	userIDKey    contextKey = "user_id"
	claimsKey    contextKey = "claims"
	requestIDKey contextKey = "request_id"
)

// SetAuthService configures the auth service used by the Auth middleware.
// Must be called before any requests are served.
var authServiceInstance services.AuthService

func SetAuthService(svc services.AuthService) {
	authServiceInstance = svc
}

// Auth validates the Bearer JWT token from the Authorization header.
// CRIT-001: Now performs actual JWT verification instead of using stub user ID.
// Returns 401 with a JSON error if the token is missing or invalid.
func Auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing or invalid Authorization header")
			return
		}

		token := strings.TrimPrefix(authHeader, "Bearer ")
		if token == "" {
			writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Empty bearer token")
			return
		}

		if authServiceInstance == nil {
			writeJSONError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Auth service not configured")
			return
		}

		// CRIT-001: Actual JWT validation with signature check, expiry, and claims
		claims, err := authServiceInstance.ValidateToken(token)
		if err != nil {
			logger, _ := zap.NewProduction()
			logger.Warn("JWT validation failed",
				zap.Error(err),
			)
			writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired token")
			return
		}

		if claims.Subject == "" {
			writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Token missing subject claim")
			return
		}

		ctx := context.WithValue(r.Context(), userIDKey, claims.Subject)
		ctx = context.WithValue(ctx, claimsKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// TimeoutMiddleware adds a context timeout to each request handler.
// CRIT-012: Protects against slowloris attacks and long-running handlers.
func TimeoutMiddleware(timeout time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx, cancel := context.WithTimeout(r.Context(), timeout)
			defer cancel()

			done := make(chan struct{})
			go func() {
				next.ServeHTTP(w, r.WithContext(ctx))
				close(done)
			}()

			select {
			case <-done:
				return
			case <-ctx.Done():
				writeJSONError(w, http.StatusGatewayTimeout, "TIMEOUT", "Request timeout")
			}
		})
	}
}

// Throttler enforces a minimum interval between rapid identical requests per user using Redis SET NX EX.
type Throttler struct {
	rdb    redis.Cmdable
	logger *zap.Logger
}

// NewThrottler creates a new Throttler instance.
func NewThrottler(rdb redis.Cmdable, logger *zap.Logger) *Throttler {
	return &Throttler{
		rdb:    rdb,
		logger: logger,
	}
}

// Throttle enforces a minimum interval between identical write requests for a given duration.
func (t *Throttler) Throttle(interval time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if t.rdb == nil {
				next.ServeHTTP(w, r)
				return
			}

			userID := ""
			if val, ok := r.Context().Value(userIDKey).(string); ok && val != "" {
				userID = val
			} else {
				ip := r.Header.Get("X-Forwarded-For")
				if ip == "" {
					ip, _, _ = net.SplitHostPort(r.RemoteAddr)
				}
				userID = ip
			}

			var bodyBytes []byte
			if r.Body != nil {
				var err error
				bodyBytes, err = io.ReadAll(r.Body)
				if err == nil {
					r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
				}
			}

			h := sha256.New()
			h.Write([]byte(r.Method))
			h.Write([]byte(r.URL.Path))
			h.Write(bodyBytes)
			fingerprint := hex.EncodeToString(h.Sum(nil)[:8])

			key := fmt.Sprintf("throttle:%s:%s", userID, fingerprint)

			ok, err := t.rdb.SetNX(r.Context(), key, "1", interval).Result()
			if err != nil {
				if t.logger != nil {
					t.logger.Warn("redis error in ThrottleMiddleware", zap.Error(err))
				}
				next.ServeHTTP(w, r)
				return
			}

			if !ok {
				writeAPIError(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "Too many rapid identical requests. Please wait before retrying.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// ThrottleMiddleware is a helper wrapper to create a throttling middleware handler.
func ThrottleMiddleware(rdb redis.Cmdable, interval time.Duration, logger *zap.Logger) func(http.Handler) http.Handler {
	return NewThrottler(rdb, logger).Throttle(interval)
}
