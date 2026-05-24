package telemetry

import (
	"context"
	"fmt"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

var Tracer trace.Tracer

// InitTracer initializes the global TracerProvider and TextMapPropagator.
// If collectorEndpoint is empty, it initializes a no-op global setup for graceful local fallback.
func InitTracer(ctx context.Context, serviceName, collectorEndpoint string) (func(context.Context) error, error) {
	if collectorEndpoint == "" {
		// Fallback to local setup (no-op TracerProvider)
		res, _ := resource.New(ctx,
			resource.WithAttributes(
				attribute.String("service.name", serviceName),
			),
		)
		tp := sdktrace.NewTracerProvider(
			sdktrace.WithResource(res),
		)
		otel.SetTracerProvider(tp)
		otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
		Tracer = tp.Tracer(serviceName)
		return func(context.Context) error { return nil }, nil
	}

	// 1. Create OTLP trace exporter (gRPC)
	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithEndpoint(collectorEndpoint),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create OTLP trace exporter: %w", err)
	}

	// 2. Define resource attributes
	res, err := resource.New(ctx,
		resource.WithAttributes(
			attribute.String("service.name", serviceName),
			attribute.String("library.language", "go"),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// 3. Build TracerProvider
	bsp := sdktrace.NewBatchSpanProcessor(exporter)
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithSpanProcessor(bsp),
		sdktrace.WithResource(res),
	)

	// 4. Set global options
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))

	Tracer = tp.Tracer(serviceName)

	// 5. Return shutdown function
	shutdown := func(shutdownCtx context.Context) error {
		if err := tp.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("failed to shutdown TracerProvider: %w", err)
		}
		return nil
	}

	return shutdown, nil
}
