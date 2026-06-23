package chess

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/notnil/chess"
	"go.uber.org/zap"
)

var (
	ErrPoolExhausted = errors.New("stockfish pool exhausted")
)

type StockfishPool interface {
	GetNextMove(ctx context.Context, fen string, difficulty int) (string, error)
	Close()
}

type fallbackPool struct{}

func (f *fallbackPool) GetNextMove(ctx context.Context, fen string, difficulty int) (string, error) {
	return getRandomLegalMove(fen)
}

func (f *fallbackPool) Close() {}

func NewStockfishPool(size int, logger *zap.Logger) (StockfishPool, error) {
	logger.Info("stockfish pool disabled; using random chess move generator fallback")
	return &fallbackPool{}, nil
}

func getRandomLegalMove(fen string) (string, error) {
	// Parse the FEN using notnil/chess
	fenFunc, err := chess.FEN(fen)
	if err != nil {
		return "", fmt.Errorf("invalid fen for fallback: %w", err)
	}
	game := chess.NewGame(fenFunc)
	
	moves := game.ValidMoves()
	if len(moves) == 0 {
		return "", errors.New("no legal moves available")
	}

	index := time.Now().UnixNano() % int64(len(moves))
	return moves[index].String(), nil
}
