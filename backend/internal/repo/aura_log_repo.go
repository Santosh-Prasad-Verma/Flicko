package repo

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/google/uuid"
)

const collAuraChatLogs = "aura_chat_logs"

// AuraChatLog represents a single turn in an AI Aura conversation.
type AuraChatLog struct {
	ID        string         `json:"_id"`
	UserID    string         `json:"user_id"`
	SessionID string         `json:"session_id"`
	Role      string         `json:"role"` // "user" or "assistant"
	Content   string         `json:"content"`
	ToolCalls []ToolCall     `json:"tool_calls,omitempty"`
	Metadata  map[string]any `json:"metadata,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
	Vector    []float32      `json:"$vector,omitempty"`
}

// ToolCall represents a function call made by the AI assistant.
type ToolCall struct {
	Name string         `json:"name"`
	Args map[string]any `json:"args,omitempty"`
}

// AuraLogRepo defines operations for AI Aura conversation persistence.
type AuraLogRepo interface {
	SaveConversationTurn(ctx context.Context, log *AuraChatLog) error
	SaveConversationBatch(ctx context.Context, logs []*AuraChatLog) error
	GetHistory(ctx context.Context, userID string, limit int) ([]*AuraChatLog, error)
	SemanticSearch(ctx context.Context, userID string, vector []float32, limit int) ([]*AuraChatLog, error)
}

type auraLogRepo struct {
	astra database.AstraClient
}

// NewAuraLogRepo creates a new Astra-backed AuraLogRepo.
func NewAuraLogRepo(astra database.AstraClient) AuraLogRepo {
	return &auraLogRepo{astra: astra}
}

func (r *auraLogRepo) SaveConversationTurn(ctx context.Context, log *AuraChatLog) error {
	if log.ID == "" {
		log.ID = uuid.NewString()
	}
	if log.CreatedAt.IsZero() {
		log.CreatedAt = time.Now().UTC()
	}

	doc := auraLogToMap(log)
	if err := r.astra.InsertOne(ctx, collAuraChatLogs, doc); err != nil {
		return fmt.Errorf("insert aura log: %w", err)
	}
	return nil
}

func (r *auraLogRepo) SaveConversationBatch(ctx context.Context, logs []*AuraChatLog) error {
	docs := make([]map[string]any, 0, len(logs))
	for _, log := range logs {
		if log.ID == "" {
			log.ID = uuid.NewString()
		}
		if log.CreatedAt.IsZero() {
			log.CreatedAt = time.Now().UTC()
		}
		docs = append(docs, auraLogToMap(log))
	}

	if err := r.astra.InsertMany(ctx, collAuraChatLogs, docs); err != nil {
		return fmt.Errorf("insert aura log batch: %w", err)
	}
	return nil
}

func (r *auraLogRepo) GetHistory(ctx context.Context, userID string, limit int) ([]*AuraChatLog, error) {
	filter := map[string]any{"user_id": userID}
	opts := &database.FindOptions{
		Limit: limit,
		Sort:  map[string]any{"created_at": -1},
	}

	docs, err := r.astra.Find(ctx, collAuraChatLogs, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("find aura logs: %w", err)
	}

	results := make([]*AuraChatLog, 0, len(docs))
	for _, doc := range docs {
		log, err := fromMapAuraLog(doc)
		if err != nil {
			return nil, fmt.Errorf("decode aura log: %w", err)
		}
		results = append(results, log)
	}
	return results, nil
}

func (r *auraLogRepo) SemanticSearch(ctx context.Context, userID string, vector []float32, limit int) ([]*AuraChatLog, error) {
	filter := map[string]any{"user_id": userID}

	docs, err := r.astra.VectorSearch(ctx, collAuraChatLogs, vector, limit, filter)
	if err != nil {
		return nil, fmt.Errorf("vector search aura logs: %w", err)
	}

	results := make([]*AuraChatLog, 0, len(docs))
	for _, doc := range docs {
		log, err := fromMapAuraLog(doc)
		if err != nil {
			return nil, fmt.Errorf("decode aura log: %w", err)
		}
		results = append(results, log)
	}
	return results, nil
}

func auraLogToMap(log *AuraChatLog) map[string]any {
	doc := map[string]any{
		"_id":        log.ID,
		"user_id":    log.UserID,
		"session_id": log.SessionID,
		"role":       log.Role,
		"content":    log.Content,
		"created_at": log.CreatedAt,
	}
	if len(log.ToolCalls) > 0 {
		doc["tool_calls"] = log.ToolCalls
	}
	if len(log.Metadata) > 0 {
		doc["metadata"] = log.Metadata
	}
	if len(log.Vector) > 0 {
		doc["$vector"] = log.Vector
	}
	return doc
}

// fromMapAuraLog converts a map to AuraChatLog with direct extraction and fast fallback.
func fromMapAuraLog(m map[string]any) (*AuraChatLog, error) {
	if m == nil {
		return nil, fmt.Errorf("nil aura log map")
	}
	log := &AuraChatLog{}
	if id, ok := m["_id"].(string); ok {
		log.ID = id
	} else if id, ok := m["id"].(string); ok {
		log.ID = id
	}
	if uID, ok := m["user_id"].(string); ok {
		log.UserID = uID
	}
	if sID, ok := m["session_id"].(string); ok {
		log.SessionID = sID
	}
	if role, ok := m["role"].(string); ok {
		log.Role = role
	}
	if content, ok := m["content"].(string); ok {
		log.Content = content
	}
	if metadata, ok := m["metadata"].(map[string]any); ok {
		log.Metadata = metadata
	}
	if rawCreatedAt, ok := m["created_at"]; ok {
		switch t := rawCreatedAt.(type) {
		case time.Time:
			log.CreatedAt = t
		case string:
			if parsed, err := time.Parse(time.RFC3339, t); err == nil {
				log.CreatedAt = parsed
			}
		}
	}
	// If tool calls or vector are present, safely decode
	if rawTools, ok := m["tool_calls"]; ok && rawTools != nil {
		if b, err := json.Marshal(rawTools); err == nil {
			_ = json.Unmarshal(b, &log.ToolCalls)
		}
	}
	return log, nil
}

// toMap converts a struct to map[string]any via JSON round-trip for generic callers.
func toMap(v any) (map[string]any, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	return m, nil
}
