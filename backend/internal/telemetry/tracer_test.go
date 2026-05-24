package telemetry_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/telemetry"
	"github.com/stretchr/testify/assert"
)

func TestInitTracer_Fallback(t *testing.T) {
	ctx := context.Background()
	shutdown, err := telemetry.InitTracer(ctx, "test-service", "")
	assert.NoError(t, err)
	assert.NotNil(t, shutdown)

	err = shutdown(ctx)
	assert.NoError(t, err)
}
