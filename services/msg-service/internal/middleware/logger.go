package middleware

import (
	"net/http"
	"time"

	"go.uber.org/zap"
)

// statusWriter wraps http.ResponseWriter to capture the status code.
type statusWriter struct {
	http.ResponseWriter
	code    int
	written bool
}

func (sw *statusWriter) WriteHeader(code int) {
	if !sw.written {
		sw.code = code
		sw.written = true
	}
	sw.ResponseWriter.WriteHeader(code)
}

func (sw *statusWriter) Write(b []byte) (int, error) {
	if !sw.written {
		sw.code = http.StatusOK
		sw.written = true
	}
	return sw.ResponseWriter.Write(b)
}

// Logger logs every HTTP request with method, path, status, and duration.
func Logger(log *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			sw := &statusWriter{ResponseWriter: w, code: http.StatusOK}

			next.ServeHTTP(sw, r)

			log.Info("http",
				zap.String("method", r.Method),
				zap.String("path", r.URL.Path),
				zap.Int("status", sw.code),
				zap.Duration("dur", time.Since(start)),
				zap.String("rid", GetRequestID(r.Context())),
				zap.String("ip", r.RemoteAddr),
			)
		})
	}
}
