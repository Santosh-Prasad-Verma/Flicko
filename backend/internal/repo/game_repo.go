package repo

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/metrics"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// GameStateRecord represents a single game state snapshot to be persisted
type GameStateRecord struct {
	GameID    string
	State     json.RawMessage
	MoveNum   int
	CreatedAt time.Time
}

// GameRepo manages persistence of games and async batching for game_states
type GameRepo interface {
	QueueStateSave(record GameStateRecord)
	StartAsyncWriter(ctx context.Context)
	StopAsyncWriter()
	GetLatestGameState(ctx context.Context, gameID string) (GameStateRecord, error)
}

type gameRepo struct {
	pool        *pgxpool.Pool
	logger      *zap.Logger
	stateBuffer chan GameStateRecord
	batchSize   int
	flushTimer  time.Duration
	done        chan struct{}
	wg          sync.WaitGroup
}

// NewGameRepo creates a new repository with an async copyFrom buffer
func NewGameRepo(pool *pgxpool.Pool, logger *zap.Logger, bufferSize, batchSize int, flushTimer time.Duration) GameRepo {
	return &gameRepo{
		pool:        pool,
		logger:      logger,
		stateBuffer: make(chan GameStateRecord, bufferSize),
		batchSize:   batchSize,
		flushTimer:  flushTimer,
		done:        make(chan struct{}),
	}
}

// QueueStateSave enqueues a game state to be written asynchronously
func (r *gameRepo) QueueStateSave(record GameStateRecord) {
	select {
	case r.stateBuffer <- record:
	default:
		// If buffer is full, we log a warning. In a production system, we might want
		// to drop older state snapshots or temporarily block, depending on guarantees.
		r.logger.Warn("game state buffer full, dropping snapshot", zap.String("game_id", record.GameID), zap.Int("move_num", record.MoveNum))
	}
}

// StartAsyncWriter starts the background worker that flushes game states using pgx.CopyFrom
func (r *gameRepo) StartAsyncWriter(ctx context.Context) {
	r.logger.Info("starting async game state writer")
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		defer close(r.done)
		
		var batch []GameStateRecord
		ticker := time.NewTicker(r.flushTimer)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				r.flushBatch(batch)
				return
			case record, ok := <-r.stateBuffer:
				if !ok {
					r.flushBatch(batch)
					return
				}
				batch = append(batch, record)
				if len(batch) >= r.batchSize {
					r.flushBatch(batch)
					batch = batch[:0]
				}
			case <-ticker.C:
				if len(batch) > 0 {
					r.flushBatch(batch)
					batch = batch[:0]
				}
			}
		}
	}()
}

func (r *gameRepo) StopAsyncWriter() {
	close(r.stateBuffer) // Prevents new states from entering the channel
	r.wg.Wait()          // Wait for the worker to drain the channel and flush to Postgres
	r.logger.Info("async game state writer stopped cleanly")
}

// flushBatch executes pgx.CopyFrom for high-throughput persistence
func (r *gameRepo) flushBatch(batch []GameStateRecord) {
	if len(batch) == 0 {
		return
	}

	// Prepare data for CopyFrom
	rows := make([][]any, 0, len(batch))
	for _, record := range batch {
		rows = append(rows, []any{
			record.GameID,
			record.State,
			record.MoveNum,
			record.CreatedAt,
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	start := time.Now()
	// Use CopyFrom for binary-streaming bulk inserts
	copyCount, err := r.pool.CopyFrom(
		ctx,
		pgx.Identifier{"game_states"},
		[]string{"game_id", "state", "move_num", "created_at"},
		pgx.CopyFromRows(rows),
	)

	duration := time.Since(start).Seconds()

	if err != nil {
		metrics.DBFlushLatency.WithLabelValues("error").Observe(duration)
		r.logger.Error("failed to bulk insert game states", zap.Error(err), zap.Int("batch_size", len(batch)))
		return
	}

	metrics.DBFlushLatency.WithLabelValues("success").Observe(duration)
	r.logger.Debug("bulk inserted game states successfully", zap.Int64("copied_rows", copyCount))
}

// GetLatestGameState fetches the most recent state for a given game from Postgres
func (r *gameRepo) GetLatestGameState(ctx context.Context, gameID string) (GameStateRecord, error) {
	var record GameStateRecord
	query := `
		SELECT game_id, state, move_num, created_at 
		FROM game_states 
		WHERE game_id = $1 
		ORDER BY move_num DESC 
		LIMIT 1`
	
	err := r.pool.QueryRow(ctx, query, gameID).Scan(&record.GameID, &record.State, &record.MoveNum, &record.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return record, err
		}
		r.logger.Error("failed to get latest game state", zap.Error(err), zap.String("game_id", gameID))
		return record, err
	}
	
	return record, nil
}
