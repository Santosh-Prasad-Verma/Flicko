package middleware_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/telemetry"
	"github.com/stretchr/testify/assert"
	"go.opentelemetry.io/otel/trace"
)

func TestTracingMiddleware(t *testing.T) {
	// 1. Initialize global tracer provider (using local/fallback)
	ctx := context.Background()
	shutdown, err := telemetry.InitTracer(ctx, "test-api", "")
	assert.NoError(t, err)
	defer shutdown(ctx)

	// 2. Create http handler that checks context trace validity
	var spanFound bool
	var traceID string
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		span := trace.SpanFromContext(r.Context())
		if span.SpanContext().IsValid() {
			spanFound = true
			traceID = span.SpanContext().TraceID().String()
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// 3. Run request through middleware
	ts := httptest.NewServer(middleware.Tracing(handler))
	defer ts.Close()

	req, err := http.NewRequest("GET", ts.URL+"/test-route", nil)
	assert.NoError(t, err)

	// Set a mock traceparent header
	// Format: 00-traceID-spanID-traceFlags
	mockTraceID := "4bf92f3577b34da6a3ce929d0e0e4736"
	req.Header.Set("traceparent", "00-"+mockTraceID+"-00f067aa0ba902b7-01")

	resp, err := http.DefaultClient.Do(req)
	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	assert.True(t, spanFound, "Expected active span in request context")
	assert.Equal(t, mockTraceID, traceID, "Expected trace ID to match W3C traceparent header")
}
