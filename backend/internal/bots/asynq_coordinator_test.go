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

func TestAsynqBotCoordinator_HandleLudoBotMove(t *testing.T) {
	logger := zap.NewNop()
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
	coord := NewAsynqBotCoordinator(nil, lockService, stateReader, ludoEngine, logger)

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
