package middleware

import (
	"fmt"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/telemetry"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/propagation"
)

type statusResponseWriter struct {
	http.ResponseWriter
	statusCode   int
	bytesWritten int
}

func (w *statusResponseWriter) WriteHeader(code int) {
	w.statusCode = code
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusResponseWriter) Write(b []byte) (int, error) {
	if w.statusCode == 0 {
		w.statusCode = http.StatusOK
	}
	n, err := w.ResponseWriter.Write(b)
	w.bytesWritten += n
	return n, err
}

// Tracing returns a middleware that instruments HTTP handlers with OTel trace spans.
func Tracing(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 1. Extract W3C Trace Context propagation headers
		ctx := otel.GetTextMapPropagator().Extract(r.Context(), propagation.HeaderCarrier(r.Header))

		// 2. Start trace span
		spanName := fmt.Sprintf("%s %s", r.Method, r.URL.Path)
		if telemetry.Tracer == nil {
			// Fallback if tracer is not initialized (e.g. in simple tests)
			next.ServeHTTP(w, r)
			return
		}

		ctx, span := telemetry.Tracer.Start(ctx, spanName)
		defer span.End()

		// 3. Inject standard trace attributes
		span.SetAttributes(
			attribute.String("http.method", r.Method),
			attribute.String("http.url", r.URL.String()),
			attribute.String("http.target", r.URL.Path),
			attribute.String("http.host", r.Host),
			attribute.String("http.user_agent", r.UserAgent()),
		)

		// 4. Wrap ResponseWriter to record status code
		sw := &statusResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		// 5. Pass down the chain with tracing context
		next.ServeHTTP(sw, r.WithContext(ctx))

		// 6. Record response metrics
		span.SetAttributes(
			attribute.Int("http.status_code", sw.statusCode),
			attribute.Int("http.response_content_length", sw.bytesWritten),
		)
		if sw.statusCode >= 500 {
			span.SetStatus(codes.Error, fmt.Sprintf("HTTP error status: %d", sw.statusCode))
		}
	})
}
