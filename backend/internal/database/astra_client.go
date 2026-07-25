package database

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
)

type AstraClient interface {
	InsertOne(ctx context.Context, collection string, doc map[string]any) error
	InsertMany(ctx context.Context, collection string, docs []map[string]any) error
	FindOne(ctx context.Context, collection string, filter map[string]any) (map[string]any, error)
	Find(ctx context.Context, collection string, filter map[string]any, opts *FindOptions) ([]map[string]any, error)
	UpdateOne(ctx context.Context, collection string, filter, update map[string]any) error
	DeleteOne(ctx context.Context, collection string, filter map[string]any) error
	VectorSearch(ctx context.Context, collection string, vector []float32, limit int, filter map[string]any) ([]map[string]any, error)
	Close()
	Ping(ctx context.Context) error
}

type FindOptions struct {
	Limit      int
	Sort       map[string]any
	Projection map[string]any
}

type astraClient struct {
	httpClient *http.Client
	baseURL    string
	token      string
	logger     *zap.Logger
	tracer     trace.Tracer
}

func NewAstraClient(endpoint, token string, logger *zap.Logger) AstraClient {
	if endpoint == "" {
		logger.Warn("AstraDB endpoint is empty")
	}
	if token == "" {
		logger.Warn("AstraDB token is empty")
	}

	endpoint = strings.TrimSuffix(endpoint, "/")

	return &astraClient{
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: endpoint,
		token:   token,
		logger:  logger,
		tracer:  otel.Tracer("astra"),
	}
}

func (c *astraClient) doRequest(ctx context.Context, method, path string, body any) ([]byte, error) {
	var bodyReader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal body: %w", err)
		}
		bodyReader = bytes.NewReader(b)
	}

	url := c.baseURL
	if path != "" {
		url = fmt.Sprintf("%s%s", c.baseURL, path)
	}

	req, err := http.NewRequestWithContext(ctx, method, url, bodyReader)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Token", c.token)
	req.Header.Set("Accept", "application/json")

	var respBytes []byte
	var lastErr error

	backoffs := []time.Duration{500 * time.Millisecond, 1 * time.Second, 2 * time.Second}
	start := time.Now()

	for attempt := 0; attempt <= len(backoffs); attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(backoffs[attempt-1]):
			}
		}

		// Important: Must recreate reader because io.Reader cannot simply be reused after read failure in some cases
		// However bytes.Reader can be Seek'd, but recreating request body for retry is safer if request was consumed.
		if body != nil && attempt > 0 {
			b, _ := json.Marshal(body)
			req.Body = io.NopCloser(bytes.NewReader(b))
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		respBytes, err = io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode >= 500 {
			lastErr = fmt.Errorf("server error: %d, body: %s", resp.StatusCode, string(respBytes))
			continue
		}

		if resp.StatusCode >= 400 {
			return nil, fmt.Errorf("client error: %d, body: %s", resp.StatusCode, string(respBytes))
		}

		duration := time.Since(start)
		if duration > 1*time.Second {
			c.logger.Warn("Slow AstraDB query", zap.String("path", path), zap.Duration("duration", duration))
		}

		return respBytes, nil
	}

	return nil, fmt.Errorf("request failed after %d attempts: %w", len(backoffs)+1, lastErr)
}

func (c *astraClient) getPath(collection string) string {
	return fmt.Sprintf("/api/json/v1/default_keyspace/%s", collection)
}

func (c *astraClient) startSpan(ctx context.Context, op, collection string) (context.Context, trace.Span) {
	ctx, span := c.tracer.Start(ctx, fmt.Sprintf("AstraDB %s", op))
	span.SetAttributes(
		attribute.String("db.system", "cassandra"),
		attribute.String("db.operation", op),
	)
	if collection != "" {
		span.SetAttributes(attribute.String("db.collection", collection))
	}
	return ctx, span
}

func (c *astraClient) InsertOne(ctx context.Context, collection string, doc map[string]any) error {
	ctx, span := c.startSpan(ctx, "InsertOne", collection)
	defer span.End()

	body := map[string]any{"insertOne": map[string]any{"document": doc}}
	_, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("InsertOne failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return err
	}
	return nil
}

func (c *astraClient) InsertMany(ctx context.Context, collection string, docs []map[string]any) error {
	ctx, span := c.startSpan(ctx, "InsertMany", collection)
	defer span.End()

	body := map[string]any{"insertMany": map[string]any{"documents": docs}}
	_, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("InsertMany failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return err
	}
	return nil
}

func (c *astraClient) FindOne(ctx context.Context, collection string, filter map[string]any) (map[string]any, error) {
	ctx, span := c.startSpan(ctx, "FindOne", collection)
	defer span.End()

	body := map[string]any{"findOne": map[string]any{"filter": filter}}
	respBytes, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("FindOne failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return nil, err
	}

	var res struct {
		Data struct {
			Document map[string]any `json:"document"`
		} `json:"data"`
	}
	if err := json.Unmarshal(respBytes, &res); err != nil {
		return nil, fmt.Errorf("failed to decode FindOne response: %w", err)
	}
	return res.Data.Document, nil
}

func (c *astraClient) Find(ctx context.Context, collection string, filter map[string]any, opts *FindOptions) ([]map[string]any, error) {
	ctx, span := c.startSpan(ctx, "Find", collection)
	defer span.End()

	findOp := map[string]any{"filter": filter}
	if opts != nil {
		if opts.Limit > 0 {
			findOp["options"] = map[string]any{"limit": opts.Limit}
		}
		if len(opts.Sort) > 0 {
			findOp["sort"] = opts.Sort
		}
		if len(opts.Projection) > 0 {
			findOp["projection"] = opts.Projection
		}
	}
	
	body := map[string]any{"find": findOp}
	respBytes, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("Find failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return nil, err
	}

	var res struct {
		Data struct {
			Documents []map[string]any `json:"documents"`
		} `json:"data"`
	}
	if err := json.Unmarshal(respBytes, &res); err != nil {
		return nil, fmt.Errorf("failed to decode Find response: %w", err)
	}
	return res.Data.Documents, nil
}

func (c *astraClient) UpdateOne(ctx context.Context, collection string, filter, update map[string]any) error {
	ctx, span := c.startSpan(ctx, "UpdateOne", collection)
	defer span.End()

	body := map[string]any{"updateOne": map[string]any{"filter": filter, "update": map[string]any{"$set": update}}}
	_, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("UpdateOne failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return err
	}
	return nil
}

func (c *astraClient) DeleteOne(ctx context.Context, collection string, filter map[string]any) error {
	ctx, span := c.startSpan(ctx, "DeleteOne", collection)
	defer span.End()

	body := map[string]any{"deleteOne": map[string]any{"filter": filter}}
	_, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("DeleteOne failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return err
	}
	return nil
}

func (c *astraClient) VectorSearch(ctx context.Context, collection string, vector []float32, limit int, filter map[string]any) ([]map[string]any, error) {
	ctx, span := c.startSpan(ctx, "VectorSearch", collection)
	defer span.End()

	findOp := map[string]any{
		"sort": map[string]any{"$vector": vector},
	}
	if limit > 0 {
		findOp["options"] = map[string]any{"limit": limit}
	}
	if len(filter) > 0 {
		findOp["filter"] = filter
	}

	body := map[string]any{"find": findOp}
	respBytes, err := c.doRequest(ctx, http.MethodPost, c.getPath(collection), body)
	if err != nil {
		c.logger.Error("VectorSearch failed", zap.Error(err), zap.String("collection", collection))
		span.RecordError(err)
		return nil, err
	}

	var res struct {
		Data struct {
			Documents []map[string]any `json:"documents"`
		} `json:"data"`
	}
	if err := json.Unmarshal(respBytes, &res); err != nil {
		return nil, fmt.Errorf("failed to decode VectorSearch response: %w", err)
	}
	return res.Data.Documents, nil
}

func (c *astraClient) Close() {
	c.httpClient.CloseIdleConnections()
}

func (c *astraClient) Ping(ctx context.Context) error {
	ctx, span := c.startSpan(ctx, "Ping", "")
	defer span.End()

	_, err := c.doRequest(ctx, http.MethodGet, "", nil)
	if err != nil {
		c.logger.Error("Ping failed", zap.Error(err))
		span.RecordError(err)
		return err
	}
	return nil
}
