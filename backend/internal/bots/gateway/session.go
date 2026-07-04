package gateway

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type SessionManager struct {
	rdb redis.Cmdable
}

func NewSessionManager(rdb redis.Cmdable) *SessionManager {
	return &SessionManager{rdb: rdb}
}

func (sm *SessionManager) CreateSession(ctx context.Context, botID string) (string, error) {
	sessionID := uuid.New().String()
	sessionKey := fmt.Sprintf("gateway_session:%s", sessionID)

	if sm.rdb != nil {
		err := sm.rdb.Set(ctx, sessionKey, botID, 24*time.Hour).Err()
		if err != nil {
			return "", fmt.Errorf("failed to store session in redis: %w", err)
		}
	}
	return sessionID, nil
}

func (sm *SessionManager) ValidateSession(ctx context.Context, sessionID, expectedBotID string) (bool, error) {
	if sm.rdb == nil {
		return true, nil
	}
	sessionKey := fmt.Sprintf("gateway_session:%s", sessionID)
	botID, err := sm.rdb.Get(ctx, sessionKey).Result()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return botID == expectedBotID, nil
}

func (sm *SessionManager) BufferEvent(ctx context.Context, sessionID string, eventType string, eventData []byte) (int64, error) {
	if sm.rdb == nil {
		return 1, nil
	}

	seqKey := fmt.Sprintf("gateway_seq:%s", sessionID)
	bufferKey := fmt.Sprintf("gateway_buffer:%s", sessionID)

	seq, err := sm.rdb.Incr(ctx, seqKey).Result()
	if err != nil {
		return 0, fmt.Errorf("failed to increment sequence: %w", err)
	}

	payload := EventPayload{
		Sequence: seq,
		Type:     eventType,
		Data:     json.RawMessage(eventData),
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return 0, fmt.Errorf("failed to marshal event payload: %w", err)
	}

	pipe := sm.rdb.Pipeline()
	pipe.RPush(ctx, bufferKey, string(payloadBytes))
	pipe.LTrim(ctx, bufferKey, -1000, -1) // Keep last 1000 events max
	pipe.Expire(ctx, bufferKey, 10*time.Minute)
	pipe.Expire(ctx, seqKey, 10*time.Minute)

	_, err = pipe.Exec(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to buffer event: %w", err)
	}

	return seq, nil
}

func (sm *SessionManager) GetEventsAfterSequence(ctx context.Context, sessionID string, afterSeq int64) ([]EventPayload, error) {
	if sm.rdb == nil {
		return nil, nil
	}

	bufferKey := fmt.Sprintf("gateway_buffer:%s", sessionID)
	rawEvents, err := sm.rdb.LRange(ctx, bufferKey, 0, -1).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch buffer: %w", err)
	}

	events := make([]EventPayload, 0)
	for _, raw := range rawEvents {
		var ev EventPayload
		if err := json.Unmarshal([]byte(raw), &ev); err == nil {
			if ev.Sequence > afterSeq {
				events = append(events, ev)
			}
		}
	}

	return events, nil
}

func FormatSeq(seq int64) *int64 {
	return &seq
}

func ParseInt64(s string) int64 {
	v, _ := strconv.ParseInt(s, 10, 64)
	return v
}
