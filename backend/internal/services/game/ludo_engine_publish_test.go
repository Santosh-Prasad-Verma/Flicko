package game

import (
	"context"
	"encoding/json"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/flicko-org/flicko-backend/internal/services/centrifugo"
)

// recordingPublisher captures all Publish calls for assertion in tests.
type recordingPublisher struct {
	mu    sync.Mutex
	calls []recordedCall
}

type recordedCall struct {
	Channel string
	Payload map[string]any
}

func (p *recordingPublisher) Publish(_ context.Context, channel string, data any) error {
	raw, _ := json.Marshal(data)
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	p.mu.Lock()
	p.calls = append(p.calls, recordedCall{Channel: channel, Payload: m})
	p.mu.Unlock()
	return nil
}

func (p *recordingPublisher) findFirst(eventType string) *recordedCall {
	p.mu.Lock()
	defer p.mu.Unlock()
	for i := range p.calls {
		if p.calls[i].Payload["type"] == eventType {
			return &p.calls[i]
		}
	}
	return nil
}

// Compile-time check that recordingPublisher satisfies the Publisher contract.
var _ centrifugo.Publisher = (*recordingPublisher)(nil)

func newEngineWithPublisher(t *testing.T) (LudoEngine, *recordingPublisher, *mockStateService, *mockRNGService) {
	t.Helper()
	stateSvc := newMockStateService()
	rngSvc := &mockRNGService{nextRoll: 6}
	lockSvc := &mockLockService{}
	validator := NewLudoValidator(rngSvc)
	pub := &recordingPublisher{}
	engine := NewLudoEngineWithPublisher(stateSvc, validator, lockSvc, rngSvc, pub)
	return engine, pub, stateSvc, rngSvc
}

func TestPublish_RollDiceEmitsDiceEvent(t *testing.T) {
	engine, pub, _, _ := newEngineWithPublisher(t)

	players := []string{"player_red", "player_green"}
	const gameID = "game_pub_1"
	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	_, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)

	dice := pub.findFirst("dice")
	assert.NotNil(t, dice, "expected a 'dice' event to be published")
	if dice == nil {
		return
	}
	assert.Equal(t, "game:"+gameID, dice.Channel)
	assert.Equal(t, float64(0), dice.Payload["playerIndex"])
	assert.Equal(t, float64(6), dice.Payload["value"])
	assert.Equal(t, true, dice.Payload["hasLegalMoves"])
	assert.GreaterOrEqual(t, dice.Payload["moveNum"].(float64), float64(1))
}

func TestPublish_MoveTokenEmitsMoveEvent(t *testing.T) {
	engine, pub, _, _ := newEngineWithPublisher(t)

	players := []string{"player_red", "player_green"}
	const gameID = "game_pub_2"
	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Roll a 6.
	_, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)

	// Move red token 0 out of base.
	_, err = engine.MoveToken(context.Background(), gameID, "player_red", 0)
	assert.NoError(t, err)

	move := pub.findFirst("move")
	assert.NotNil(t, move, "expected a 'move' event to be published")
	if move == nil {
		return
	}
	assert.Equal(t, "game:"+gameID, move.Channel)
	assert.Equal(t, float64(0), move.Payload["playerIndex"])
	assert.Equal(t, float64(0), move.Payload["tokenId"])
	assert.Equal(t, float64(-1), move.Payload["from"])
	assert.Equal(t, float64(0), move.Payload["to"])
	assert.Equal(t, float64(6), move.Payload["diceValue"])
	assert.Equal(t, false, move.Payload["captureOccurred"])
}

func TestPublish_NoEventWhenRollDiceFails(t *testing.T) {
	engine, pub, _, _ := newEngineWithPublisher(t)

	// Roll dice on a non-existent game — engine returns error, publisher must not fire.
	_, err := engine.RollDice(context.Background(), "nope", "player_red")
	assert.Error(t, err)

	assert.Empty(t, pub.calls, "no events should be published when the action errors")
}

func TestPublish_WinnerEventOnGameComplete(t *testing.T) {
	engine, pub, stateSvc, rngSvc := newEngineWithPublisher(t)

	players := []string{"player_red", "player_green"}
	const gameID = "game_pub_3"
	_, err := engine.InitializeGame(context.Background(), gameID, players)
	assert.NoError(t, err)

	// Hand-craft a state where red has 3 tokens already home and 1 token at
	// progression 56 — one square away from finishing the game.
	state, err := engine.GetGameState(context.Background(), gameID)
	assert.NoError(t, err)
	for i := 0; i < 4; i++ {
		state.Tokens[i].ProgressionIndex = 57
	}
	state.Tokens[0].ProgressionIndex = 56
	stateBytes, _ := json.Marshal(state)
	_ = stateSvc.SaveState(context.Background(), gameID, stateBytes, 1)

	// Roll a 1, move token 0 → progression 57 → win.
	rngSvc.nextRoll = 1
	_, err = engine.RollDice(context.Background(), gameID, "player_red")
	assert.NoError(t, err)
	_, err = engine.MoveToken(context.Background(), gameID, "player_red", 0)
	assert.NoError(t, err)

	winner := pub.findFirst("winner")
	assert.NotNil(t, winner, "expected a 'winner' event when the player finishes")
	if winner == nil {
		return
	}
	assert.Equal(t, "game:"+gameID, winner.Channel)
	assert.Equal(t, float64(0), winner.Payload["playerIndex"])
}
