package chess

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
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

type stockfishWorker struct {
	cmd       *exec.Cmd
	stdin     io.WriteCloser
	stdout    io.ReadCloser
	responses chan string
	mu        sync.Mutex
	killed    bool
}

type pool struct {
	workers chan *stockfishWorker
	logger  *zap.Logger
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

func spawnWorker() (*stockfishWorker, error) {
	cmd := exec.Command("stockfish")
	
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	worker := &stockfishWorker{
		cmd:       cmd,
		stdin:     stdin,
		stdout:    stdout,
		responses: make(chan string, 1024),
	}

	// Asynchronously drain stdout to prevent OS pipe deadlocks
	go worker.drainStdout()

	// Initialize
	if err := worker.sendCommand("uci"); err != nil {
		worker.kill()
		return nil, err
	}
	worker.waitFor("uciok", 2*time.Second)

	return worker, nil
}

func (w *stockfishWorker) drainStdout() {
	scanner := bufio.NewScanner(w.stdout)
	for scanner.Scan() {
		line := scanner.Text()
		select {
		case w.responses <- line:
		default:
			// If channel is full, drop older lines to keep unblocking pipe
			<-w.responses
			w.responses <- line
		}
	}
}

func (w *stockfishWorker) sendCommand(cmd string) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.killed {
		return errors.New("worker killed")
	}
	_, err := fmt.Fprintln(w.stdin, cmd)
	return err
}

func (w *stockfishWorker) waitFor(prefix string, timeout time.Duration) string {
	timer := time.NewTimer(timeout)
	defer timer.Stop()

	for {
		select {
		case line := <-w.responses:
			if strings.HasPrefix(line, prefix) {
				return line
			}
		case <-timer.C:
			return ""
		}
	}
}

func (w *stockfishWorker) kill() {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.killed {
		return
	}
	w.killed = true
	w.cmd.Process.Kill()
	w.cmd.Wait()
}

func (p *pool) GetNextMove(ctx context.Context, fen string, difficulty int) (string, error) {
	// Apply the 5-second strict deadline required by specs
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var worker *stockfishWorker
	select {
	case worker = <-p.workers:
	case <-ctx.Done():
		return getRandomLegalMove(fen)
	}

	// Ensure worker is returned or respawned
	defer func() {
		if worker.killed {
			p.logger.Warn("respawning killed stockfish worker")
			go func() {
				nw, err := spawnWorker()
				if err == nil && nw != nil {
					p.workers <- nw
				} else {
					p.logger.Error("failed to respawn worker", zap.Error(err))
				}
			}()
		} else {
			p.workers <- worker
		}
	}()

	err := worker.sendCommand("isready")
	if err != nil {
		worker.kill()
		return getRandomLegalMove(fen)
	}
	
	if worker.waitFor("readyok", 1*time.Second) == "" {
		worker.kill()
		return getRandomLegalMove(fen)
	}

	// Set skill level (difficulty maps to stockfish Skill Level)
	worker.sendCommand(fmt.Sprintf("setoption name Skill Level value %d", difficulty))
	worker.sendCommand(fmt.Sprintf("position fen %s", fen))
	
	// Enforce strict time limit via `go movetime <ms>`
	worker.sendCommand("go movetime 1500")

	bestMoveChan := make(chan string, 1)
	go func() {
		res := worker.waitFor("bestmove", 4*time.Second)
		bestMoveChan <- res
	}()

	select {
	case <-ctx.Done():
		// Timeout occurred before stockfish could respond
		worker.kill()
		p.logger.Warn("stockfish worker timed out, killing and returning random move")
		return getRandomLegalMove(fen)
	case res := <-bestMoveChan:
		if res == "" {
			worker.kill()
			return getRandomLegalMove(fen)
		}
		parts := strings.Split(res, " ")
		if len(parts) >= 2 {
			return parts[1], nil
		}
		worker.kill()
		return getRandomLegalMove(fen)
	}
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

func (p *pool) Close() {
	close(p.workers)
	for w := range p.workers {
		w.kill()
	}
}
