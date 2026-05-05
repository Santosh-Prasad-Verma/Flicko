package game

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/notnil/chess"
	"github.com/flicko-org/flicko-backend/internal/services/lock" // Assumed module path, adjust if necessary
)

type ChessValidator struct {
	lockService lock.LockService
}

func NewChessValidator(ls lock.LockService) *ChessValidator {
	return &ChessValidator{lockService: ls}
}

// ProcessMove acquires the distributed game lock (with a 100ms retry) and validates a chess move
func (v *ChessValidator) ProcessMove(ctx context.Context, gameID, playerID, fen string, moveStr string) (*chess.Game, string, error) {
	lockKey := "game:" + gameID + ":process_lock"
	token := playerID + "-" + fmt.Sprintf("%d", time.Now().UnixNano())

	// Non-blocking acquire with a single 100ms retry
	acquired, err := v.lockService.AcquireLock(ctx, lockKey, token, 5*time.Second)
	if err != nil || !acquired {
		time.Sleep(100 * time.Millisecond)
		acquired, err = v.lockService.AcquireLock(ctx, lockKey, token, 5*time.Second)
		if err != nil || !acquired {
			return nil, "", errors.New("could not acquire lock to process move (concurrency conflict)")
		}
	}
	defer v.lockService.ReleaseLock(context.Background(), lockKey, token)

	// Validate the incoming FEN state
	fenFunc, err := chess.FEN(fen)
	if err != nil {
		return nil, "", fmt.Errorf("invalid starting FEN: %w", err)
	}
	game := chess.NewGame(fenFunc)

	// Validate and apply the move string (algebraic or UCI)
	err = game.MoveStr(moveStr)
	if err != nil {
		return nil, "", fmt.Errorf("invalid or illegal move: %w", err)
	}

	// Detect draw conditions or completion natively via notnil/chess
	method := game.Method()
	outcome := game.Outcome()

	status := "active"
	if outcome != chess.NoOutcome {
		status = "completed"
		// Specifically detect draw methods
		if method == chess.Stalemate || method == chess.ThreefoldRepetition || method == chess.FiftyMoveRule || method == chess.InsufficientMaterial {
			status = "draw"
		} else if method == chess.Checkmate {
			status = "checkmate"
		} else if method == chess.Resignation || method == chess.DrawOffer {
			// Explicit user actions
			if outcome == chess.Draw {
				status = "draw"
			}
		}
	}

	return game, status, nil
}
