// Package middleware provides HTTP middleware for the mail gateway.
package middleware

import (
	"net/http"
	"time"

	"github.com/go-chi/httprate"
)

// RateLimit returns an HTTP middleware that limits requests by IP address.
// Default: 60 requests per minute per IP on the webhook endpoint.
// This prevents abuse and protects the SMTP quota.
func RateLimit(requestsPerMinute int) func(http.Handler) http.Handler {
	if requestsPerMinute <= 0 {
		requestsPerMinute = 60
	}
	return httprate.LimitByIP(requestsPerMinute, time.Minute)
}
