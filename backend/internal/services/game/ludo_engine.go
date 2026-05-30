package game

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/flicko-org/flicko-backend/internal/services/lock"
	"github.com/flicko-org/flicko-backend/internal/services/rng"
)

type LudoGameState struct {
	GameID            string       `json:"game_id"`
	Players           []string     `json:"players"`
	ActivePlayerIndex int          `json:"active_player_index"`
	Status            string       `json:"status"` // "active", "completed", etc.
	Tokens            []*Token     `json:"tokens"`
	Turn              *TurnState   `json:"turn"`
	MoveNum           int          `json:"moveNum"`
}

type LudoEngine interface {
	InitializeGame(ctx context.Context, gameID string, players []string) (*LudoGameState, error)
	RollDice(ctx context.Context, gameID string, playerID string) (*LudoGameState, error)
	MoveToken(ctx context.Context, gameID string, playerID string, tokenID int) (*LudoGameState, error)
	GetGameState(ctx context.Context, gameID string) (*LudoGameState, error)
}

type ludoEngine struct {
	stateService  StateService
	ludoValidator *LudoValidator
	lockService   lock.LockService
	rngService    rng.RNGService
	publisher     centrifugo.Publisher
}

func NewLudoEngine(stateSvc StateService, ludoVal *LudoValidator, lockSvc lock.LockService, rngSvc rng.RNGService) LudoEngine {
	return &ludoEngine{
		stateService:  stateSvc,
		ludoValidator: ludoVal,
		lockService:   lockSvc,
		rngService:    rngSvc,
		publisher:     centrifugo.NopPublisher{},
	}
}

// NewLudoEngineWithPublisher wires a Centrifugo publisher so authoritative
// dice rolls / moves / winner notifications get broadcast on the
// `game:<gameID>` channel that mobile clients subscribe to.
func NewLudoEngineWithPublisher(
	stateSvc StateService,
	ludoVal *LudoValidator,
	lockSvc lock.LockService,
	rngSvc rng.RNGService,
	publisher centrifugo.Publisher,
) LudoEngine {
	if publisher == nil {
		publisher = centrifugo.NopPublisher{}
	}
	return &ludoEngine{
		stateService:  stateSvc,
		ludoValidator: ludoVal,
		lockService:   lockSvc,
		rngService:    rngSvc,
		publisher:     publisher,
	}
}

// channelForGame returns the Centrifugo channel name. The chess proxy
// already authorises subscriptions on `game:<id>`; we keep the same shape
// so the same proxy + subscribe hook serves both games.
func channelForGame(gameID string) string { return "game:" + gameID }

func (e *ludoEngine) GetGameState(ctx context.Context, gameID string) (*LudoGameState, error) {
	stateRaw, moveNum, err := e.stateService.GetGameState(ctx, gameID)
	if err != nil {
		return nil, err
	}
	var state LudoGameState
	if err := json.Unmarshal(stateRaw, &state); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ludo game state: %w", err)
	}
	state.MoveNum = moveNum
	return &state, nil
}

func (e *ludoEngine) acquireLock(ctx context.Context, gameID, playerID string) (string, error) {
	lockKey := "game:" + gameID + ":process_lock"
	token := playerID + "-" + fmt.Sprintf("%d", time.Now().UnixNano())

	acquired, err := e.lockService.AcquireLock(ctx, lockKey, token, 5*time.Second)
	if err != nil || !acquired {
		// single retry
		time.Sleep(100 * time.Millisecond)
		acquired, err = e.lockService.AcquireLock(ctx, lockKey, token, 5*time.Second)
		if err != nil || !acquired {
			return "", errors.New("could not acquire lock to process move (concurrency conflict)")
		}
	}
	return token, nil
}

func (e *ludoEngine) InitializeGame(ctx context.Context, gameID string, players []string) (*LudoGameState, error) {
	if len(players) < 2 || len(players) > 4 {
		return nil, errors.New("ludo requires between 2 and 4 players")
	}

	tokens := make([]*Token, 0, len(players)*4)
	for i, playerID := range players {
		colorOffset := i * 13 // 0, 13, 26, 39
		for j := 0; j < 4; j++ {
			tokenID := i*4 + j
			tokens = append(tokens, &Token{
				ID:               tokenID,
				PlayerID:         playerID,
				ColorOffset:      colorOffset,
				ProgressionIndex: -1, // base
			})
		}
	}

	state := &LudoGameState{
		GameID:            gameID,
		Players:           players,
		ActivePlayerIndex: 0,
		Status:            "active",
		Tokens:            tokens,
		Turn: &TurnState{
			DiceValue:  0,
			RollID:     "",
			IsConsumed: true,
		},
		MoveNum: 0,
	}

	stateBytes, err := json.Marshal(state)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal starting ludo state: %w", err)
	}

	err = e.stateService.SaveState(ctx, gameID, stateBytes, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to save starting ludo state: %w", err)
	}

	return state, nil
}

func (e *ludoEngine) RollDice(ctx context.Context, gameID string, playerID string) (*LudoGameState, error) {
	lockToken, err := e.acquireLock(ctx, gameID, playerID)
	if err != nil {
		return nil, err
	}
	lockKey := "game:" + gameID + ":process_lock"
	defer e.lockService.ReleaseLock(context.Background(), lockKey, lockToken)

	state, err := e.GetGameState(ctx, gameID)
	if err != nil {
		return nil, err
	}

	if state.Status != "active" {
		return nil, errors.New("game is not active")
	}

	activePlayerID := state.Players[state.ActivePlayerIndex]
	if activePlayerID != playerID {
		return nil, fmt.Errorf("it is not player %s's turn", playerID)
	}

	if state.Turn != nil && !state.Turn.IsConsumed && state.Turn.DiceValue > 0 {
		return nil, errors.New("player has already rolled for this turn")
	}

	// secure roll
	roll, err := e.rngService.DiceRoll(6)
	if err != nil {
		return nil, fmt.Errorf("failed secure dice roll: %w", err)
	}

	rollID := uuid.New().String()
	state.Turn = &TurnState{
		DiceValue:  roll,
		RollID:     rollID,
		IsConsumed: false,
	}

	// Auto-advancement: does active player have ANY legal moves?
	hasLegalMoves := false
	for _, tok := range state.Tokens {
		if tok.PlayerID == playerID {
			if tok.ProgressionIndex == -1 {
				if roll == 6 {
					hasLegalMoves = true
					break
				}
			} else {
				if tok.ProgressionIndex+roll <= 57 {
					hasLegalMoves = true
					break
				}
			}
		}
	}

	if !hasLegalMoves {
		// auto-consume turn and advance
		state.Turn.IsConsumed = true
		if roll != 6 {
			state.ActivePlayerIndex = (state.ActivePlayerIndex + 1) % len(state.Players)
		}
		state.Turn = &TurnState{
			DiceValue:  0,
			RollID:     "",
			IsConsumed: true,
		}
	}

	stateBytes, err := json.Marshal(state)
	if err != nil {
		return nil, err
	}

	err = e.stateService.SaveState(ctx, gameID, stateBytes, state.MoveNum+1)
	if err != nil {
		return nil, err
	}

	state.MoveNum++

	// Authoritative dice broadcast. Best-effort; never fails the action.
	_ = e.publisher.Publish(ctx, channelForGame(gameID), map[string]any{
		"type":               "dice",
		"moveNum":            state.MoveNum,
		"playerIndex":        playerIndexOf(state, playerID),
		"value":              roll,
		"hasLegalMoves":      hasLegalMoves,
		"nextActivePlayerIndex": state.ActivePlayerIndex,
	})

	return state, nil
}

func (e *ludoEngine) MoveToken(ctx context.Context, gameID string, playerID string, tokenID int) (*LudoGameState, error) {
	lockToken, err := e.acquireLock(ctx, gameID, playerID)
	if err != nil {
		return nil, err
	}
	lockKey := "game:" + gameID + ":process_lock"
	defer e.lockService.ReleaseLock(context.Background(), lockKey, lockToken)

	state, err := e.GetGameState(ctx, gameID)
	if err != nil {
		return nil, err
	}

	if state.Status != "active" {
		return nil, errors.New("game is not active")
	}

	activePlayerID := state.Players[state.ActivePlayerIndex]
	if activePlayerID != playerID {
		return nil, fmt.Errorf("it is not player %s's turn", playerID)
	}

	if state.Turn == nil || state.Turn.IsConsumed {
		return nil, errors.New("no active unconsumed dice roll available")
	}

	var activeToken *Token
	for _, tok := range state.Tokens {
		if tok.ID == tokenID {
			activeToken = tok
			break
		}
	}

	if activeToken == nil {
		return nil, fmt.Errorf("token %d not found on board", tokenID)
	}

	if activeToken.PlayerID != playerID {
		return nil, errors.New("this token belongs to another player")
	}

	// Capture-track: opponent positions before validation.
	opponentStatesBefore := make(map[int]int)
	for _, tok := range state.Tokens {
		if tok.PlayerID != playerID {
			opponentStatesBefore[tok.ID] = tok.ProgressionIndex
		}
	}
	// Active piece's pre-move position (for the broadcast diff).
	fromIndex := activeToken.ProgressionIndex
	diceValue := state.Turn.DiceValue

	// Validate move (mutates `activeToken` and possibly opponent tokens).
	err = e.ludoValidator.ValidateMove(activeToken, state.Turn, state.Tokens)
	if err != nil {
		return nil, err
	}

	// Capture checking — build full list of captured opponents (not just a bool).
	type capturedRef struct {
		PlayerIndex int `json:"playerIndex"`
		TokenID     int `json:"tokenId"`
	}
	captured := []capturedRef{}
	for _, tok := range state.Tokens {
		if tok.PlayerID != playerID {
			beforeIndex, exists := opponentStatesBefore[tok.ID]
			if exists && beforeIndex >= 0 && tok.ProgressionIndex == -1 {
				captured = append(captured, capturedRef{
					PlayerIndex: playerIndexOf(state, tok.PlayerID),
					TokenID:     tok.ID,
				})
			}
		}
	}
	captureOccurred := len(captured) > 0

	// Game completion check
	playerFinished := true
	for _, tok := range state.Tokens {
		if tok.PlayerID == playerID {
			if tok.ProgressionIndex != 57 {
				playerFinished = false
				break
			}
		}
	}

	if playerFinished {
		state.Status = "completed"
	} else {
		// Extra roll logic: rolling a 6 or capturing a token gives another turn!
		rolledSix := (state.Turn.DiceValue == 6)
		if !rolledSix && !captureOccurred {
			state.ActivePlayerIndex = (state.ActivePlayerIndex + 1) % len(state.Players)
		}
		state.Turn = &TurnState{
			DiceValue:  0,
			RollID:     "",
			IsConsumed: true,
		}
	}

	stateBytes, err := json.Marshal(state)
	if err != nil {
		return nil, err
	}

	err = e.stateService.SaveState(ctx, gameID, stateBytes, state.MoveNum+1)
	if err != nil {
		return nil, err
	}

	state.MoveNum++

	// Authoritative move broadcast. The Flutter port translates engine
	// (playerIndex, tokenId, progressionIndex) into its own (playerNo,
	// pieceId, absolute pos) vocabulary on receive.
	channel := channelForGame(gameID)
	_ = e.publisher.Publish(ctx, channel, map[string]any{
		"type":                  "move",
		"moveNum":               state.MoveNum,
		"playerIndex":           playerIndexOf(state, playerID),
		"tokenId":               tokenID,
		"from":                  fromIndex,
		"to":                    activeToken.ProgressionIndex,
		"diceValue":             diceValue,
		"captured":              captured,
		"captureOccurred":       captureOccurred,
		"nextActivePlayerIndex": state.ActivePlayerIndex,
	})

	if state.Status == "completed" {
		_ = e.publisher.Publish(ctx, channel, map[string]any{
			"type":        "winner",
			"moveNum":     state.MoveNum,
			"playerIndex": playerIndexOf(state, playerID),
		})
	}

	return state, nil
}

// playerIndexOf returns the 0-based seat for [playerID], or -1 if unknown.
func playerIndexOf(state *LudoGameState, playerID string) int {
	for i, p := range state.Players {
		if p == playerID {
			return i
		}
	}
	return -1
}
