package bots

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	gameSvc "github.com/flicko-org/flicko-backend/internal/services/game"
	"github.com/hibiken/asynq"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

// Self-contained mocks for testing AsynqBotCoordinator

type mockLockService struct{}

func (l *mockLockService) AcquireLock(ctx context.Context, key, token string, ttl time.Duration) (bool, error) {
	return true, nil
}

func (l *mockLockService) ReleaseLock(ctx context.Context, key, token string) error {
	return nil
}

type mockStateReader struct {
	state []byte
}

func (r *mockStateReader) GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error) {
	return r.state, 1, nil
}

type mockStockfishPool struct{}

func (p *mockStockfishPool) GetNextMove(ctx context.Context, fen string, difficulty int) (string, error) {
	return "e2e4", nil
}

type mockGameService struct{}

func (s *mockGameService) ProcessMove(ctx context.Context, gameID, playerID, move string) error {
	return nil
}

type mockLudoEngine struct {
	state *gameSvc.LudoGameState
}

func (m *mockLudoEngine) GetGameState(ctx context.Context, gameID string) (*gameSvc.LudoGameState, error) {
	return m.state, nil
}

func (m *mockLudoEngine) RollDice(ctx context.Context, gameID, playerID string) (*gameSvc.LudoGameState, error) {
	m.state.Turn = &gameSvc.TurnState{
		DiceValue:  6,
		RollID:     "mock-roll",
		IsConsumed: false,
	}
	return m.state, nil
}

func (m *mockLudoEngine) MoveToken(ctx context.Context, gameID, playerID string, tokenID int) (*gameSvc.LudoGameState, error) {
	m.state.Turn.IsConsumed = true
	for _, tok := range m.state.Tokens {
		if tok.ID == tokenID {
			tok.ProgressionIndex = 0 // Exit base
			break
		}
	}
	return m.state, nil
}

func (m *mockLudoEngine) InitializeGame(ctx context.Context, gameID string, players []string) (*gameSvc.LudoGameState, error) {
	return m.state, nil
}

func TestAsynqBotCoordinator_HandleChessBotMove(t *testing.T) {
	logger := zap.NewNop()
	pool := &mockStockfishPool{}
	gameService := &mockGameService{}
	lockService := &mockLockService{}
	stateReader := &mockStateReader{}
	ludoEngine := &mockLudoEngine{}

	// Initialize coordinator (asynq.Client can remain uninitialized as we don't call Enqueue in this test)
	coord := NewAsynqBotCoordinator(nil, pool, gameService, lockService, stateReader, ludoEngine, logger)

	payloadBytes, _ := json.Marshal(BotMovePayload{
		GameID:     "game_chess",
		PlayerID:   "bot_1",
		FEN:        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
		Difficulty: 1,
	})

	task := asynq.NewTask(TypeBotMove, payloadBytes)
	err := coord.HandleBotMoveTask(context.Background(), task)
	assert.NoError(t, err)
}

func TestAsynqBotCoordinator_HandleLudoBotMove(t *testing.T) {
	logger := zap.NewNop()
	pool := &mockStockfishPool{}
	gameService := &mockGameService{}
	lockService := &mockLockService{}
	stateReader := &mockStateReader{}

	players := []string{"player_red", "bot_green"}
	gameID := "game_ludo"

	// Mock Ludo State: green bot's turn, green pieces in base (-1)
	tokens := []*gameSvc.Token{
		{ID: 0, PlayerID: "player_red", ColorOffset: 0, ProgressionIndex: 0},
		{ID: 1, PlayerID: "player_red", ColorOffset: 0, ProgressionIndex: -1},
		{ID: 2, PlayerID: "player_red", ColorOffset: 0, ProgressionIndex: -1},
		{ID: 3, PlayerID: "player_red", ColorOffset: 0, ProgressionIndex: -1},
		{ID: 4, PlayerID: "bot_green", ColorOffset: 13, ProgressionIndex: -1}, // In base
		{ID: 5, PlayerID: "bot_green", ColorOffset: 13, ProgressionIndex: -1},
		{ID: 6, PlayerID: "bot_green", ColorOffset: 13, ProgressionIndex: -1},
		{ID: 7, PlayerID: "bot_green", ColorOffset: 13, ProgressionIndex: -1},
	}

	ludoState := &gameSvc.LudoGameState{
		GameID:            gameID,
		Players:           players,
		ActivePlayerIndex: 1, // Green bot
		Status:            "active",
		Tokens:            tokens,
		Turn: &gameSvc.TurnState{
			DiceValue:  0,
			RollID:     "",
			IsConsumed: true, // Needs roll
		},
		MoveNum: 3,
	}

	ludoEngine := &mockLudoEngine{state: ludoState}
	coord := NewAsynqBotCoordinator(nil, pool, gameService, lockService, stateReader, ludoEngine, logger)

	payloadBytes, _ := json.Marshal(LudoBotMovePayload{
		GameID:   gameID,
		PlayerID: "bot_green",
	})

	task := asynq.NewTask(TypeLudoBotMove, payloadBytes)
	err := coord.HandleLudoBotMoveTask(context.Background(), task)
	assert.NoError(t, err)

	// Verify that green token 4 successfully exited base (progression 0)
	assert.Equal(t, 0, ludoState.Tokens[4].ProgressionIndex)
}
