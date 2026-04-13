package middleware

import (
	"bytes"
	"net/http"
)

// maxCacheableBody is the maximum response body size we'll capture for
// idempotency caching. Responses larger than 10 KB are not cached — they're
// likely paginated lists or large payloads where the cost of Redis storage
// outweighs the deduplication benefit.
const maxCacheableBody = 10 * 1024 // 10 KB

// captureWriter wraps http.ResponseWriter to intercept the status code and
// response body as they're written. The captured data is used by the
// idempotency middleware to store the response in Redis for replay.
//
// Design decisions:
//   - Writes pass through immediately to the underlying ResponseWriter, so
//     the client sees the response without delay — we capture a copy.
//   - Only bodies ≤ maxCacheableBody (10 KB) are captured. If the handler
//     writes more than that, we stop buffering and mark the response as
//     not cacheable (overflow = true). The response still goes to the
//     client normally; we just don't cache it.
//   - Only 2xx responses are cached by the idempotency middleware (checked
//     externally). Errors, redirects, and other non-success responses are
//     not replayed on retry, allowing the client to get a fresh attempt.
type captureWriter struct {
	http.ResponseWriter
	status   int          // HTTP status code (defaults to 200 if WriteHeader isn't called)
	buf      bytes.Buffer // captured body bytes (up to maxCacheableBody)
	overflow bool         // true if body exceeded maxCacheableBody
	wroteHdr bool         // true after WriteHeader is called
}

// newCaptureWriter wraps an existing ResponseWriter for capture.
func newCaptureWriter(w http.ResponseWriter) *captureWriter {
	return &captureWriter{
		ResponseWriter: w,
		status:         http.StatusOK, // default per HTTP spec
	}
}

// WriteHeader captures the status code and passes it through.
// Per the http.ResponseWriter contract, WriteHeader can only be called once.
func (cw *captureWriter) WriteHeader(code int) {
	if cw.wroteHdr {
		return // idempotent: first call wins
	}
	cw.wroteHdr = true
	cw.status = code
	cw.ResponseWriter.WriteHeader(code)
}

// Write captures body bytes (up to the limit) and passes them through.
// If the total body exceeds maxCacheableBody, we stop buffering but
// the write to the client still succeeds — caching is best-effort.
func (cw *captureWriter) Write(b []byte) (int, error) {
	if !cw.wroteHdr {
		cw.WriteHeader(http.StatusOK) // implicit 200 per net/http spec
	}

	// Only buffer if we haven't overflowed yet.
	if !cw.overflow {
		remaining := maxCacheableBody - cw.buf.Len()
		if len(b) <= remaining {
			cw.buf.Write(b)
		} else {
			// Body too large — stop capturing.
			cw.overflow = true
			cw.buf.Reset() // free buffered memory
		}
	}

	return cw.ResponseWriter.Write(b)
}

// Unwrap returns the underlying ResponseWriter. This is required by
// chi/middleware and http.ResponseController to access the original
// writer for features like Flushing, Hijacking, etc.
func (cw *captureWriter) Unwrap() http.ResponseWriter {
	return cw.ResponseWriter
}

// isCacheable returns true if the captured response should be stored in
// Redis for idempotency replay.
//
// Criteria:
//   - Status is 2xx (success). Errors should not be cached — the client
//     may be retrying because the first attempt failed.
//   - Body did not overflow the capture buffer.
//   - Body is non-empty (nothing to replay for empty 204-style responses,
//     though we still allow them to be cacheable for correctness).
func (cw *captureWriter) isCacheable() bool {
	return cw.status >= 200 && cw.status < 300 && !cw.overflow
}

// capturedBody returns the buffered response body, or nil if uncacheable.
func (cw *captureWriter) capturedBody() []byte {
	if cw.overflow {
		return nil
	}
	return cw.buf.Bytes()
}
