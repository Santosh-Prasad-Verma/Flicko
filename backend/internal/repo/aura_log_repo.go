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

	doc, err := toMap(log)
	if err != nil {
		return fmt.Errorf("marshal aura log: %w", err)
	}

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
		doc, err := toMap(log)
		if err != nil {
			return fmt.Errorf("marshal aura log batch item: %w", err)
		}
		docs = append(docs, doc)
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

// toMap converts a struct to map[string]any via JSON round-trip.
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

// fromMapAuraLog converts a map to AuraChatLog via JSON round-trip.
func fromMapAuraLog(m map[string]any) (*AuraChatLog, error) {
	b, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	var log AuraChatLog
	if err := json.Unmarshal(b, &log); err != nil {
		return nil, err
	}
	return &log, nil
}
