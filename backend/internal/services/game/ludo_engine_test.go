package game

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// Mock implementations for unit testing the LudoEngine logic self-containedly

type mockLockService struct{}

func (l *mockLockService) AcquireLock(ctx context.Context, key, token string, ttl time.Duration) (bool, error) {
	return true, nil
}

func (l *mockLockService) ReleaseLock(ctx context.Context, key, token string) error {
	return nil
}

type mockRNGService struct {
	nextRoll int
}

func (r *mockRNGService) DiceRoll(sides int) (int, error) {
	if r.nextRoll == 0 {
		return 6, nil // Default fallback
	}
	return r.nextRoll, nil
}

type mockStateService struct {
	states   map[string]json.RawMessage
	moveNums map[string]int
}

func newMockStateService() *mockStateService {
	return &mockStateService{
		states:   make(map[string]json.RawMessage),
		moveNums: make(map[string]int),
	}
}

func (m *mockStateService) SaveState(ctx context.Context, gameID string, state json.RawMessage, moveNum int) error {
	m.states[gameID] = state
	m.moveNums[gameID] = moveNum
	return nil
}

func (m *mockStateService) GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error) {
	state, ok := m.states[gameID]
	if !ok {
		return nil, 0, ErrGameNotFound
	}
	return state, m.moveNums[gameID], nil
}

func (m *mockStateService) GetAuthoritativeMoveNum(ctx context.Context, gameID string) (int, string, error) {
	moveNum, ok := m.moveNums[gameID]
	if !ok {
		return 0, "not_found", nil
	}
	return moveNum, "ok", nil
}

func TestLudoEngine_InitializeGame(t *testing.T) {
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 6}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	engine := NewLudoEngine(stateSvc, validator, lockSvc, rngSvc)

	players := []string{"player_red", "player_green"}
	gameID := "game_123"

	state, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)
	assert.Equal(t, gameID, state.GameID)
	assert.Equal(t, players, state.Players)
	assert.Equal(t, 0, state.ActivePlayerIndex)
	assert.Equal(t, "active", state.Status)
	assert.Len(t, state.Tokens, 8) // 4 red, 4 green
	assert.Equal(t, -1, state.Tokens[0].ProgressionIndex)
	assert.Equal(t, 0, state.Tokens[0].ColorOffset)
	assert.Equal(t, 13, state.Tokens[4].ColorOffset)
}

func TestLudoEngine_RollDice_Normal(t *testing.T) {
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 5}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	engine := NewLudoEngine(stateSvc, validator, lockSvc, rngSvc)

	players := []string{"player_red", "player_green"}
	gameID := "game_123"

	// Init game
	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Since they all start in base (-1) and we roll a 5, there are NO legal moves!
	// Therefore, it should auto-consume and advance to the next player.
	state, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)
	assert.Equal(t, 1, state.ActivePlayerIndex) // Rotated to player_green
	assert.True(t, state.Turn.IsConsumed)
	assert.Equal(t, 0, state.Turn.DiceValue)
}

func TestLudoEngine_RollDice_SixexitsBase(t *testing.T) {
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 6}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	engine := NewLudoEngine(stateSvc, validator, lockSvc, rngSvc)

	players := []string{"player_red", "player_green"}
	gameID := "game_123"

	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Rolling a 6. Since player has pieces in base, they have legal moves!
	// Turn should NOT auto-advance and remain on player_red with active roll 6.
	state, err := engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)
	assert.Equal(t, 0, state.ActivePlayerIndex) // Remains player_red
	assert.False(t, state.Turn.IsConsumed)
	assert.Equal(t, 6, state.Turn.DiceValue)
}

func TestLudoEngine_MoveToken_ExitBaseAndMove(t *testing.T) {
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 6}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	engine := NewLudoEngine(stateSvc, validator, lockSvc, rngSvc)

	players := []string{"player_red", "player_green"}
	gameID := "game_123"

	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Roll 6
	_, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)

	// Move Red token 0 (currently at -1)
	state, err := engine.MoveToken(context.Background(), gameID, "player_red", 0)
	assert.NoError(t, err)
	assert.Equal(t, 0, state.Tokens[0].ProgressionIndex) // Exited base to cell 0
	assert.Equal(t, 0, state.ActivePlayerIndex)           // Earned another roll for rolling a 6!

	// Now roll a 4
	rngSvc.nextRoll = 4
	_, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)

	// Move Red token 0 (currently at 0)
	state, err = engine.MoveToken(context.Background(), gameID, "player_red", 0)
	assert.NoError(t, err)
	assert.Equal(t, 4, state.Tokens[0].ProgressionIndex) // Moved 4 spaces to 4
	assert.Equal(t, 1, state.ActivePlayerIndex)           // Normal turn rotation, next player green
}

func TestLudoEngine_TokenCapture(t *testing.T) {
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 1}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	engine := NewLudoEngine(stateSvc, validator, lockSvc, rngSvc)

	players := []string{"player_red", "player_green"}
	gameID := "game_123"

	// Starting setup
	state, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Position player_red token 0 at progression 14 (physical square 14)
	state.Tokens[0].ProgressionIndex = 14
	// Position player_green token 4 at progression 0 (physical square 13)
	state.Tokens[4].ProgressionIndex = 0

	// Write this state to state service
	stateBytes, _ := json.Marshal(state)
	_ = stateSvc.SaveState(context.Background(), gameID, stateBytes, 1)

	// Set green's turn
	state.ActivePlayerIndex = 1
	stateBytes, _ = json.Marshal(state)
	_ = stateSvc.SaveState(context.Background(), gameID, stateBytes, 2)

	// Green rolls a 1
	rngSvc.nextRoll = 1
	_, err = engine.RollDice(context.Background(), gameID, "player_green")
	assert.NoError(t, err)

	// Green moves token 4 (currently at 0 progression).
	// Green token 4 moves to progression 1 (physical square 14) and captures red token 0 (physical square 14)!
	state, err = engine.MoveToken(context.Background(), gameID, "player_green", 4)
	assert.NoError(t, err)

	// Red token 0 (previously at 13) should be captured and returned back to base (-1)!
	assert.Equal(t, -1, state.Tokens[0].ProgressionIndex)
	// Green token 4 is successfully at progression 1
	assert.Equal(t, 1, state.Tokens[4].ProgressionIndex)
	// Green gets another turn because green captured red!
	assert.Equal(t, 1, state.ActivePlayerIndex)
}
