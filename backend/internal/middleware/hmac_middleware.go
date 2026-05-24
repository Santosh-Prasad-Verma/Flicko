package middleware

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// HMACSigningMiddleware creates an HTTP middleware that verifies HMAC-SHA256 request signatures.
// If secret is empty, it attempts to load from environment variable "HMAC_CLIENT_SECRET".
func HMACSigningMiddleware(rdb redis.Cmdable, logger *zap.Logger, secret string) func(http.Handler) http.Handler {
	if secret == "" {
		secret = os.Getenv("HMAC_CLIENT_SECRET")
		if secret == "" {
			secret = "flicko_secure_default_secret_key_change_in_production"
		}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// 1. Extract signature, timestamp and nonce headers
			signature := r.Header.Get("X-Signature")
			timestampStr := r.Header.Get("X-Timestamp")
			nonce := r.Header.Get("X-Nonce")

			if signature == "" || timestampStr == "" || nonce == "" {
				logger.Warn("HMAC verification failed: missing headers",
					zap.String("signature", signature),
					zap.String("timestamp", timestampStr),
					zap.String("nonce", nonce),
					zap.String("path", r.URL.Path),
				)
				writeJSONError(w, http.StatusUnauthorized, "HMAC_SIGNATURE_MISSING", "Missing required security headers")
				return
			}

			// 2. Validate timestamp (within 5 minutes window)
			timestamp, err := strconv.ParseInt(timestampStr, 10, 64)
			if err != nil {
				logger.Warn("HMAC verification failed: invalid timestamp format",
					zap.String("timestamp", timestampStr),
				)
				writeJSONError(w, http.StatusUnauthorized, "HMAC_INVALID_TIMESTAMP", "Invalid timestamp format")
				return
			}

			now := time.Now().Unix()
			diff := now - timestamp
			if diff < -300 || diff > 300 {
				logger.Warn("HMAC verification failed: replay attack detected or clock drift",
					zap.Int64("timestamp", timestamp),
					zap.Int64("now", now),
					zap.Int64("drift", diff),
				)
				writeJSONError(w, http.StatusUnauthorized, "HMAC_TIMESTAMP_OUT_OF_RANGE", "Request timestamp is out of the valid range (5-minute window)")
				return
			}

			// 3. Verify Nonce uniqueness in Redis
			if rdb != nil {
				ctx, cancel := context.WithTimeout(r.Context(), 100*time.Millisecond)
				defer cancel()

				nonceKey := "nonce:" + nonce
				// SETNX returns true if the key did not exist and was successfully set.
				// We set a 5-minute TTL to match our replay window.
				ok, err := rdb.SetNX(ctx, nonceKey, "1", 5*time.Minute).Result()
				if err != nil {
					// Fallback gracefully on Redis error (Availability > Enforcement)
					logger.Error("HMAC verification: Redis nonce check failed, bypassing nonce uniqueness",
						zap.String("nonce", nonce),
						zap.Error(err),
					)
				} else if !ok {
					// Nonce has been used, replay attack!
					logger.Warn("HMAC verification failed: duplicate nonce detected (replay attack)",
						zap.String("nonce", nonce),
					)
					writeJSONError(w, http.StatusUnauthorized, "HMAC_DUPLICATE_NONCE", "Nonce already used")
					return
				}
			}

			// 4. Read body and restore it for downstream handlers
			var bodyBytes []byte
			if r.Body != nil {
				var err error
				bodyBytes, err = io.ReadAll(r.Body)
				if err != nil {
					logger.Error("HMAC verification: failed to read body", zap.Error(err))
					writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", "Failed to read request body")
					return
				}
				// Restore request body
				r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			}

			// 5. Construct payload to sign: body + timestamp + nonce
			var payload []byte
			payload = append(payload, bodyBytes...)
			payload = append(payload, []byte(timestampStr)...)
			payload = append(payload, []byte(nonce)...)

			// 6. Recalculate HMAC-SHA256 signature
			mac := hmac.New(sha256.New, []byte(secret))
			mac.Write(payload)
			expectedMAC := mac.Sum(nil)

			// 7. Securely compare signatures in constant time
			sigBytes, err := hex.DecodeString(signature)
			if err != nil {
				logger.Warn("HMAC verification failed: invalid signature hex encoding",
					zap.String("signature", signature),
				)
				writeJSONError(w, http.StatusUnauthorized, "HMAC_INVALID_SIGNATURE", "Invalid signature encoding")
				return
			}

			if subtle.ConstantTimeCompare(sigBytes, expectedMAC) != 1 {
				logger.Warn("HMAC verification failed: signature mismatch",
					zap.String("path", r.URL.Path),
				)
				writeJSONError(w, http.StatusUnauthorized, "HMAC_SIGNATURE_MISMATCH", "Invalid signature")
				return
			}

			// Signature is valid, proceed
			next.ServeHTTP(w, r)
		})
	}
}
