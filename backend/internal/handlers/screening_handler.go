package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ScreeningHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type screeningRuleResponse struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description,omitempty"`
	IsRequired  bool      `json:"is_required"`
	Position    int       `json:"position"`
	IsEnabled   bool      `json:"is_enabled"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type screeningAcceptRequest struct {
	AcceptedRuleIDs []string `json:"accepted_rule_ids"`
}

func NewScreeningHandler(db *pgxpool.Pool, logger *zap.Logger) *ScreeningHandler {
	return &ScreeningHandler{
		db:     db,
		logger: logger.Named("handler.screening"),
	}
}

func (h *ScreeningHandler) GetScreening(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	serverUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}

	isMember, err := h.isServerMember(r, serverUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to verify screening membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch screening")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, title, COALESCE(description, ''), is_required, position, is_enabled, created_at, updated_at
		FROM public.screening_rules
		WHERE server_id = $1
		  AND is_enabled = TRUE
		ORDER BY position ASC, created_at ASC
	`, serverUUID)
	if err != nil {
		h.logger.Error("failed to query screening rules", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch screening")
		return
	}
	defer rows.Close()

	rules := make([]screeningRuleResponse, 0)
	for rows.Next() {
		var item screeningRuleResponse
		if err = rows.Scan(
			&item.ID, &item.Title, &item.Description, &item.IsRequired, &item.Position,
			&item.IsEnabled, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			h.logger.Error("failed to scan screening rule", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to fetch screening")
			return
		}
		rules = append(rules, item)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("screening rules row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch screening")
		return
	}

	status := "pending"
	var acceptedAt *time.Time
	var lastPromptedAt *time.Time
	acceptedRules := make([]string, 0)
	var acceptedRulesRaw []byte
	err = h.db.QueryRow(r.Context(), `
		SELECT status, accepted_at, last_prompted_at, accepted_rules
		FROM public.member_screening_status
		WHERE server_id = $1
		  AND user_id = $2
	`, serverUUID, userUUID).Scan(&status, &acceptedAt, &lastPromptedAt, &acceptedRulesRaw)
	if err != nil && err != pgx.ErrNoRows {
		h.logger.Error("failed to query member screening status", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch screening")
		return
	}
	if len(acceptedRulesRaw) > 0 {
		if err = json.Unmarshal(acceptedRulesRaw, &acceptedRules); err != nil {
			h.logger.Error("failed to decode accepted screening rules", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to fetch screening")
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":           serverUUID.String(),
		"status":              status,
		"accepted_at":         acceptedAt,
		"last_prompted_at":    lastPromptedAt,
		"accepted_rule_ids":   acceptedRules,
		"requires_acceptance": status != "accepted" && len(rules) > 0,
		"active_rule_count":   len(rules),
		"screening_rules":     rules,
	})
}

func (h *ScreeningHandler) AcceptScreening(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	serverUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}

	isMember, err := h.isServerMember(r, serverUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to verify screening membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to accept screening")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	req := screeningAcceptRequest{}
	if r.Body != nil {
		decErr := json.NewDecoder(r.Body).Decode(&req)
		if decErr != nil && decErr != io.EOF {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
	}

	requiredRuleIDs := make([]string, 0)
	rows, err := h.db.Query(r.Context(), `
		SELECT id
		FROM public.screening_rules
		WHERE server_id = $1
		  AND is_enabled = TRUE
		  AND is_required = TRUE
	`, serverUUID)
	if err != nil {
		h.logger.Error("failed to query required screening rules", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to accept screening")
		return
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			h.logger.Error("failed to scan required screening rule", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to accept screening")
			return
		}
		requiredRuleIDs = append(requiredRuleIDs, id)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("required screening rules row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to accept screening")
		return
	}

	acceptedSet := map[string]struct{}{}
	if len(req.AcceptedRuleIDs) == 0 {
		req.AcceptedRuleIDs = append(req.AcceptedRuleIDs, requiredRuleIDs...)
	}
	for _, id := range req.AcceptedRuleIDs {
		if _, parseErr := uuid.Parse(id); parseErr != nil {
			writeError(w, http.StatusBadRequest, "invalid accepted rule id")
			return
		}
		acceptedSet[id] = struct{}{}
	}
	for _, requiredID := range requiredRuleIDs {
		if _, ok := acceptedSet[requiredID]; !ok {
			writeError(w, http.StatusBadRequest, "all required screening rules must be accepted")
			return
		}
	}

	acceptedRulesRaw, err := json.Marshal(req.AcceptedRuleIDs)
	if err != nil {
		h.logger.Error("failed to encode accepted screening rules", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to accept screening")
		return
	}

	var acceptedAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.member_screening_status (
			server_id, user_id, status, accepted_at, last_prompted_at, accepted_rules
		)
		VALUES ($1, $2, 'accepted', NOW(), NOW(), $3::jsonb)
		ON CONFLICT (server_id, user_id)
		DO UPDATE SET
			status = 'accepted',
			accepted_at = NOW(),
			last_prompted_at = NOW(),
			accepted_rules = EXCLUDED.accepted_rules
		RETURNING accepted_at
	`, serverUUID, userUUID, acceptedRulesRaw).Scan(&acceptedAt); err != nil {
		h.logger.Error("failed to upsert member screening status", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to accept screening")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":           serverUUID.String(),
		"status":              "accepted",
		"accepted_at":         acceptedAt,
		"accepted_rule_ids":   req.AcceptedRuleIDs,
		"required_rule_count": len(requiredRuleIDs),
	})
}

func (h *ScreeningHandler) isServerMember(r *http.Request, serverID, userID uuid.UUID) (bool, error) {
	var isMember bool
	err := h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.server_members
			WHERE server_id = $1
			  AND user_id = $2
		)
	`, serverID, userID).Scan(&isMember)
	return isMember, err
}
