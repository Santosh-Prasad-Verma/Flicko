package repo

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/google/uuid"
)

const collSystemAuditLogs = "system_audit_logs"

// AuditEvent represents a single audit trail entry stored in Astra DB.
type AuditEvent struct {
	ID         string         `json:"_id"`
	EventType  string         `json:"event_type"`
	ActorID    string         `json:"actor_id"`
	ActorName  string         `json:"actor_name"`
	TargetID   string         `json:"target_id"`
	TargetType string         `json:"target_type"`
	ServerID   string         `json:"server_id"`
	ServerName string         `json:"server_name"`
	Details    map[string]any `json:"details,omitempty"`
	IPAddress  string         `json:"ip_address,omitempty"`
	CreatedAt  time.Time      `json:"created_at"`
}

// AuditFilter defines query filters for audit log retrieval.
type AuditFilter struct {
	ServerID  string
	ActorID   string
	EventType string
	Limit     int
}

// AuditLogAstraRepo defines operations for audit log persistence in Astra DB.
type AuditLogAstraRepo interface {
	LogEvent(ctx context.Context, event *AuditEvent) error
	LogEventBatch(ctx context.Context, events []*AuditEvent) error
	QueryEvents(ctx context.Context, filter AuditFilter) ([]*AuditEvent, error)
}

type auditLogAstraRepo struct {
	astra database.AstraClient
}

// NewAuditLogAstraRepo creates a new Astra-backed AuditLogAstraRepo.
func NewAuditLogAstraRepo(astra database.AstraClient) AuditLogAstraRepo {
	return &auditLogAstraRepo{astra: astra}
}

func (r *auditLogAstraRepo) LogEvent(ctx context.Context, event *AuditEvent) error {
	if event.ID == "" {
		event.ID = uuid.NewString()
	}
	if event.CreatedAt.IsZero() {
		event.CreatedAt = time.Now().UTC()
	}

	doc, err := toMap(event)
	if err != nil {
		return fmt.Errorf("marshal audit event: %w", err)
	}

	if err := r.astra.InsertOne(ctx, collSystemAuditLogs, doc); err != nil {
		return fmt.Errorf("insert audit event: %w", err)
	}
	return nil
}

func (r *auditLogAstraRepo) LogEventBatch(ctx context.Context, events []*AuditEvent) error {
	docs := make([]map[string]any, 0, len(events))
	for _, event := range events {
		if event.ID == "" {
			event.ID = uuid.NewString()
		}
		if event.CreatedAt.IsZero() {
			event.CreatedAt = time.Now().UTC()
		}
		doc, err := toMap(event)
		if err != nil {
			return fmt.Errorf("marshal audit event batch item: %w", err)
		}
		docs = append(docs, doc)
	}

	if err := r.astra.InsertMany(ctx, collSystemAuditLogs, docs); err != nil {
		return fmt.Errorf("insert audit event batch: %w", err)
	}
	return nil
}

func (r *auditLogAstraRepo) QueryEvents(ctx context.Context, filter AuditFilter) ([]*AuditEvent, error) {
	queryFilter := make(map[string]any)
	if filter.ServerID != "" {
		queryFilter["server_id"] = filter.ServerID
	}
	if filter.ActorID != "" {
		queryFilter["actor_id"] = filter.ActorID
	}
	if filter.EventType != "" {
		queryFilter["event_type"] = filter.EventType
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}

	opts := &database.FindOptions{
		Limit: limit,
		Sort:  map[string]any{"created_at": -1},
	}

	docs, err := r.astra.Find(ctx, collSystemAuditLogs, queryFilter, opts)
	if err != nil {
		return nil, fmt.Errorf("find audit events: %w", err)
	}

	results := make([]*AuditEvent, 0, len(docs))
	for _, doc := range docs {
		event, err := fromMapAuditEvent(doc)
		if err != nil {
			return nil, fmt.Errorf("decode audit event: %w", err)
		}
		results = append(results, event)
	}
	return results, nil
}

func fromMapAuditEvent(m map[string]any) (*AuditEvent, error) {
	b, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	var event AuditEvent
	if err := json.Unmarshal(b, &event); err != nil {
		return nil, err
	}
	return &event, nil
}
