package handlers

import (
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ParityHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type ParityStatusEntry struct {
	FeatureKey  string    `json:"feature_key"`
	Status      string    `json:"status"`
	Owner       string    `json:"owner"`
	TargetPhase string    `json:"target_phase"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func NewParityHandler(db *pgxpool.Pool, logger *zap.Logger) *ParityHandler {
	return &ParityHandler{
		db:     db,
		logger: logger.Named("handler.parity"),
	}
}

// GetParityStatus handles GET /api/v1/parity/status
func (h *ParityHandler) GetParityStatus(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(), `
		SELECT feature_key, status, owner, target_phase, updated_at
		FROM feature_parity_status
		ORDER BY feature_key ASC
	`)
	if err != nil {
		h.logger.Error("failed to query feature parity status", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch parity status")
		return
	}
	defer rows.Close()

	items := make([]ParityStatusEntry, 0, 32)
	for rows.Next() {
		var item ParityStatusEntry
		if scanErr := rows.Scan(
			&item.FeatureKey,
			&item.Status,
			&item.Owner,
			&item.TargetPhase,
			&item.UpdatedAt,
		); scanErr != nil {
			h.logger.Error("failed to scan parity status row", zap.Error(scanErr))
			writeError(w, http.StatusInternalServerError, "failed to parse parity status")
			return
		}
		items = append(items, item)
	}

	if rows.Err() != nil {
		h.logger.Error("parity status row iteration failed", zap.Error(rows.Err()))
		writeError(w, http.StatusInternalServerError, "failed to fetch parity status")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"items": items,
		"count": len(items),
	})
}
