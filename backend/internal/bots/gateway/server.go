package gateway

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
	"golang.org/x/net/websocket"
)

type Server struct {
	db             *pgxpool.Pool
	rdb            redis.Cmdable
	sessionManager *SessionManager
	tokenSecrets   map[string][]byte
	logger         *zap.Logger
}

func NewServer(db *pgxpool.Pool, rdb redis.Cmdable, jwtSecret string, logger *zap.Logger) *Server {
	return &Server{
		db:             db,
		rdb:            rdb,
		sessionManager: NewSessionManager(rdb),
		tokenSecrets: map[string][]byte{
			"v1": []byte(jwtSecret),
		},
		logger: logger.Named("gateway_server"),
	}
}

func (s *Server) HandleWebSocket() http.Handler {
	return websocket.Handler(s.handleConn)
}

func (s *Server) handleConn(ws *websocket.Conn) {
	defer ws.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Send Op 10 Hello
	helloPayload := GatewayPayload{
		Op: OpHello,
		D:  mustMarshal(HelloData{HeartbeatInterval: 41250}),
	}
	if err := websocket.JSON.Send(ws, helloPayload); err != nil {
		s.logger.Error("failed to send Hello payload", zap.Error(err))
		return
	}

	// 2. Wait for Identify or Resume
	_ = ws.SetReadDeadline(time.Now().Add(15 * time.Second))
	var initPayload GatewayPayload
	if err := websocket.JSON.Receive(ws, &initPayload); err != nil {
		s.logger.Warn("failed to receive Identify/Resume payload", zap.Error(err))
		return
	}

	var botID string
	var sessionID string

	if initPayload.Op == OpIdentify {
		var identify IdentifyData
		if err := json.Unmarshal(initPayload.D, &identify); err != nil {
			s.sendInvalidSession(ws)
			return
		}

		bID, err := s.validateBotToken(ctx, identify.Token)
		if err != nil {
			s.logger.Warn("invalid bot token on identify", zap.Error(err))
			s.sendInvalidSession(ws)
			return
		}
		botID = bID

		sessID, err := s.sessionManager.CreateSession(ctx, botID)
		if err != nil {
			s.logger.Error("failed to create session", zap.Error(err))
			s.sendInvalidSession(ws)
			return
		}
		sessionID = sessID

		// Send READY event
		readyData := ReadyData{
			V: 1,
			User: BotUser{
				ID:       botID,
				Username: "Bot",
				Bot:      true,
			},
			Guilds:    []string{},
			SessionID: sessionID,
		}

		readyPayload := GatewayPayload{
			Op: OpDispatch,
			S:  FormatSeq(1),
			T:  "READY",
			D:  mustMarshal(readyData),
		}
		if err := websocket.JSON.Send(ws, readyPayload); err != nil {
			return
		}

	} else if initPayload.Op == OpResume {
		var resume ResumeData
		if err := json.Unmarshal(initPayload.D, &resume); err != nil {
			s.sendInvalidSession(ws)
			return
		}

		bID, err := s.validateBotToken(ctx, resume.Token)
		if err != nil {
			s.sendInvalidSession(ws)
			return
		}
		botID = bID

		valid, err := s.sessionManager.ValidateSession(ctx, resume.SessionID, botID)
		if err != nil || !valid {
			s.sendInvalidSession(ws)
			return
		}
		sessionID = resume.SessionID

		// Replay missed events
		missedEvents, err := s.sessionManager.GetEventsAfterSequence(ctx, sessionID, resume.Seq)
		if err == nil {
			for _, ev := range missedEvents {
				_ = websocket.JSON.Send(ws, GatewayPayload{
					Op: OpDispatch,
					S:  FormatSeq(ev.Sequence),
					T:  ev.Type,
					D:  ev.Data,
				})
			}
		}
	} else {
		s.sendInvalidSession(ws)
		return
	}

	// 3. Connection Event Loop (Heartbeats & Incoming messages)
	heartbeatInterval := 41250 * time.Millisecond
	readDeadline := heartbeatInterval + 10*time.Second

	for {
		_ = ws.SetReadDeadline(time.Now().Add(readDeadline))
		var incoming GatewayPayload
		if err := websocket.JSON.Receive(ws, &incoming); err != nil {
			s.logger.Info("gateway connection closed or timed out", zap.String("session_id", sessionID), zap.Error(err))
			break
		}

		switch incoming.Op {
		case OpHeartbeat:
			// Send Heartbeat ACK
			ackPayload := GatewayPayload{Op: OpHeartbeatACK}
			if err := websocket.JSON.Send(ws, ackPayload); err != nil {
				return
			}
		default:
			s.logger.Debug("unhandled gateway opcode", zap.Int("op", incoming.Op))
		}
	}
}

func (s *Server) validateBotToken(ctx context.Context, tokenStr string) (string, error) {
	botUserID, err := auth.VerifyToken(tokenStr, s.tokenSecrets)
	if err != nil {
		return "", err
	}

	if s.db != nil {
		hashBytes := sha256.Sum256([]byte(tokenStr))
		tokenHash := hex.EncodeToString(hashBytes[:])

		var appID string
		err = s.db.QueryRow(ctx, `
			SELECT bt.application_id
			FROM public.bot_tokens bt
			JOIN public.applications a ON a.id = bt.application_id
			WHERE bt.token_hash = $1 AND bt.revoked_at IS NULL AND a.is_active = TRUE AND a.status = 'active'
		`, tokenHash).Scan(&appID)
		if err != nil {
			return "", fmt.Errorf("invalid token or suspended app")
		}
		if appID != botUserID {
			return "", fmt.Errorf("subject mismatch")
		}
	}

	return botUserID, nil
}

func (s *Server) sendInvalidSession(ws *websocket.Conn) {
	_ = websocket.JSON.Send(ws, GatewayPayload{
		Op: OpInvalidSession,
		D:  json.RawMessage("false"),
	})
}

func mustMarshal(v interface{}) json.RawMessage {
	b, _ := json.Marshal(v)
	return json.RawMessage(b)
}
