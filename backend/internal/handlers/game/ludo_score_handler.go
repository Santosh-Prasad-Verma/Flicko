package game

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// LudoScoreHandler persists Ludo match outcomes (winner/loser/team) and
// updates the players' ELO. Designed for the offline + bot games where the
// device is the source of truth; for online matches this should be wired to
// the authoritative ludo_engine instead of trusted from the client.
type LudoScoreHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewLudoScoreHandler(db *pgxpool.Pool, logger *zap.Logger) *LudoScoreHandler {
	return &LudoScoreHandler{db: db, logger: logger}
}

type ludoScoreRequest struct {
	GameID    string   `json:"game_id"`
	WinnerID  string   `json:"winner_id"`
	LoserIDs  []string `json:"loser_ids"`
	IsBotGame bool     `json:"is_bot_game"`
	Reason    string   `json:"reason"` // "checkmate" semantic; for ludo we use "home_win"
}

func (h *LudoScoreHandler) HandleSubmitScore(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value("userID").(string)
	if userID == "" {
		http.Error(w, "unauthenticated", http.StatusUnauthorized)
		return
	}

	var req ludoScoreRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.WinnerID == "" {
		http.Error(w, "winner_id required", http.StatusBadRequest)
		return
	}

	// Best-effort persistence — we never fail the user's request because
	// the client already has the result locally.
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Warn("ludo score: begin tx failed", zap.Error(err))
		writeJSON(w, map[string]any{"ok": true, "persisted": false})
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	if req.GameID == "" {
		// Insert a synthetic game row so the rest of the schema FKs still
		// have something to point at.
		err = tx.QueryRow(r.Context(),
			`INSERT INTO games (game_type, status, player_a, is_bot_game)
			 VALUES ('ludo', 'completed', $1, $2)
			 RETURNING id`,
			userID, req.IsBotGame,
		).Scan(&req.GameID)
		if err != nil {
			h.logger.Warn("ludo score: insert game failed", zap.Error(err))
			writeJSON(w, map[string]any{"ok": true, "persisted": false})
			return
		}
	}

	reason := req.Reason
	if reason == "" {
		reason = "home_win"
	}
	for _, loser := range req.LoserIDs {
		_, err = tx.Exec(r.Context(),
			`INSERT INTO game_results (game_id, winner_id, loser_id, reason)
			 VALUES ($1, $2, $3, $4)`,
			req.GameID, req.WinnerID, loser, reason,
		)
		if err != nil {
			h.logger.Warn("ludo score: insert result failed", zap.Error(err))
		}
	}

	// Light ELO bump for non-bot wins.
	if !req.IsBotGame {
		_, _ = tx.Exec(r.Context(),
			`UPDATE users SET elo = COALESCE(elo, 1200) + 12 WHERE id = $1`,
			req.WinnerID,
		)
		for _, loser := range req.LoserIDs {
			_, _ = tx.Exec(r.Context(),
				`UPDATE users SET elo = GREATEST(800, COALESCE(elo, 1200) - 8) WHERE id = $1`,
				loser,
			)
		}
	}

	if err := tx.Commit(r.Context()); err != nil {
		h.logger.Warn("ludo score: commit failed", zap.Error(err))
		writeJSON(w, map[string]any{"ok": true, "persisted": false})
		return
	}
	writeJSON(w, map[string]any{"ok": true, "persisted": true, "game_id": req.GameID})
}

// HandleLeaderboard returns the top-N Ludo players ranked by ELO + wins.
func (h *LudoScoreHandler) HandleLeaderboard(w http.ResponseWriter, r *http.Request) {
	const q = `
		SELECT u.id,
		       COALESCE(u.username, u.email, u.id::text) AS name,
		       COALESCE(u.elo, 1200)                     AS elo,
		       (SELECT COUNT(*) FROM game_results gr
		         JOIN games g ON g.id = gr.game_id
		         WHERE g.game_type = 'ludo' AND gr.winner_id = u.id) AS wins,
		       (SELECT COUNT(*) FROM games g
		         WHERE g.game_type = 'ludo'
		           AND (g.player_a = u.id OR g.player_b = u.id)) AS total
		FROM users u
		ORDER BY elo DESC, wins DESC
		LIMIT 50
	`
	rows, err := h.db.Query(r.Context(), q)
	if err != nil {
		h.logger.Warn("ludo leaderboard query failed", zap.Error(err))
		writeJSON(w, map[string]any{"entries": []any{}})
		return
	}
	defer rows.Close()

	type entry struct {
		UserID string `json:"user_id"`
		Name   string `json:"name"`
		ELO    int    `json:"elo"`
		Wins   int    `json:"wins"`
		Total  int    `json:"total"`
	}
	entries := []entry{}
	for rows.Next() {
		var e entry
		if err := rows.Scan(&e.UserID, &e.Name, &e.ELO, &e.Wins, &e.Total); err != nil {
			h.logger.Warn("ludo leaderboard scan failed", zap.Error(err))
			continue
		}
		entries = append(entries, e)
	}

	writeJSON(w, map[string]any{"entries": entries})
}

func writeJSON(w http.ResponseWriter, payload any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(payload)
}

// Compile-time check that pgxpool's context import is used (for older Go
// linters that flag unused imports across helper files).
var _ = context.Background
