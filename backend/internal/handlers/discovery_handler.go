package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type DiscoveryHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewDiscoveryHandler(db *pgxpool.Pool, logger *zap.Logger) *DiscoveryHandler {
	return &DiscoveryHandler{
		db:     db,
		logger: logger.Named("handler.discovery"),
	}
}

type DiscoverableServerPayload struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Icon        *string `json:"icon"`
	Banner      *string `json:"banner"`
	Description *string `json:"description"`
	MemberCount int     `json:"member_count"`
	OnlineCount int     `json:"online_count"`
	IsMember    bool    `json:"is_member"`
	CreatedAt   string  `json:"created_at"`
}

func (h *DiscoveryHandler) DiscoverServers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := ctx.Value("userID").(string) // from Auth middleware

	search := r.URL.Query().Get("q")

	// Pagination (BUG-022)
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")

	limit := 100
	if limitOpt, err := strconv.Atoi(limitStr); err == nil && limitOpt > 0 {
		if limitOpt > 100 {
			limitOpt = 100
		}
		limit = limitOpt
	}

	offset := 0
	if offsetOpt, err := strconv.Atoi(offsetStr); err == nil && offsetOpt > 0 {
		offset = offsetOpt
	}

	queryArgs := []interface{}{userID}
	searchFilter := ""

	if search != "" {
		// Escape SQL LIKE wildcards
		search = strings.ReplaceAll(search, "\\", "\\\\")
		search = strings.ReplaceAll(search, "%", "\\%")
		search = strings.ReplaceAll(search, "_", "\\_")
		searchFilter = " AND (s.name ILIKE $2 ESCAPE '\\' OR s.description ILIKE $2 ESCAPE '\\') "
		queryArgs = append(queryArgs, "%"+search+"%")
	}

	// Performance improvement (BUG-023): optimized correlated subqueries using LEFT JOIN and GROUP BY
	query := `
		SELECT 
			s.id, 
			s.name, 
			s.icon, 
			s.banner, 
			s.description, 
			s.created_at,
			COALESCE(sm_counts.member_count, 0) as member_count,
			COALESCE(sm_counts.online_count, 0) as online_count,
			COALESCE(sm_counts.is_member, false) as is_member
		FROM servers s
		LEFT JOIN LATERAL (
			SELECT 
				COUNT(*) as member_count,
				COUNT(*) FILTER (WHERE p.status != 'offline') as online_count,
				bool_or(sm.user_id = $1) as is_member
			FROM server_members sm
			LEFT JOIN presence p ON p.user_id = sm.user_id
			WHERE sm.server_id = s.id
		) sm_counts ON true
		WHERE s.is_public = true ` + searchFilter + `
		ORDER BY s.created_at DESC
		LIMIT $` + strconv.Itoa(len(queryArgs)+1) + ` OFFSET $` + strconv.Itoa(len(queryArgs)+2)

	queryArgs = append(queryArgs, limit, offset)

	rows, err := h.db.Query(ctx, query, queryArgs...)
	if err != nil {
		h.logger.Error("failed to list discoverable servers", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var servers []DiscoverableServerPayload
	for rows.Next() {
		var srv DiscoverableServerPayload
		var t time.Time
		if err := rows.Scan(&srv.ID, &srv.Name, &srv.Icon, &srv.Banner, &srv.Description, &t, &srv.MemberCount, &srv.OnlineCount, &srv.IsMember); err != nil {
			h.logger.Error("failed to scan server row", zap.Error(err))
			continue
		}
		servers = append(servers, srv)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"servers": servers,
	})
}
