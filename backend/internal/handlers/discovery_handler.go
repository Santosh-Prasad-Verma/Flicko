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

type TrendingServerPayload struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Icon           *string  `json:"icon"`
	Banner         *string  `json:"banner"`
	Description    *string  `json:"description"`
	Category       *string  `json:"category"`
	Tags           []string `json:"tags"`
	CompositeScore float64  `json:"composite_score"`
	GrowthScore    float64  `json:"growth_score"`
	Engagement     float64  `json:"engagement_score"`
	Retention      float64  `json:"retention_score"`
	TrustScore     float64  `json:"trust_score"`
	Reasons        []string `json:"reasons"`
}

func (h *DiscoveryHandler) GetTrendingServers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	limit := 25
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 {
		if v > 100 {
			v = 100
		}
		limit = v
	}

	offset := 0
	if v, err := strconv.Atoi(r.URL.Query().Get("offset")); err == nil && v >= 0 {
		offset = v
	}

	category := strings.TrimSpace(r.URL.Query().Get("category"))
	queryArgs := []interface{}{limit, offset}
	categoryFilter := ""
	if category != "" {
		queryArgs = append(queryArgs, category)
		categoryFilter = " AND sc.slug = $3 "
	}

	rows, err := h.db.Query(ctx, `
		WITH latest_scores AS (
			SELECT DISTINCT ON (sds.server_id)
				sds.server_id,
				sds.category_id,
				sds.composite_score,
				sds.growth_score,
				sds.engagement_score,
				sds.retention_score,
				sds.trust_score,
				sds.reasons,
				sds.score_date
			FROM public.server_discovery_scores sds
			ORDER BY sds.server_id, sds.score_date DESC, sds.composite_score DESC
		)
		SELECT
			s.id,
			s.name,
			s.icon,
			s.banner,
			s.description,
			sc.name AS category_name,
			COALESCE(tags.tags, '{}'::text[]) AS tags,
			ls.composite_score,
			ls.growth_score,
			ls.engagement_score,
			ls.retention_score,
			ls.trust_score,
			COALESCE(
			  ARRAY(
			    SELECT value
			    FROM jsonb_array_elements_text(COALESCE(ls.reasons, '[]'::jsonb)) AS value
			  ),
			  '{}'::text[]
			) AS reasons
		FROM latest_scores ls
		INNER JOIN public.servers s ON s.id = ls.server_id
		LEFT JOIN public.server_categories sc ON sc.id = ls.category_id
		LEFT JOIN LATERAL (
			SELECT array_agg(st.tag ORDER BY st.tag) AS tags
			FROM public.server_tags st
			WHERE st.server_id = s.id
		) tags ON true
		WHERE s.is_public = true
		`+categoryFilter+`
		ORDER BY ls.composite_score DESC, ls.trust_score DESC, ls.growth_score DESC
		LIMIT $1 OFFSET $2
	`, queryArgs...)
	if err != nil {
		h.logger.Error("failed to query trending servers", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	results := make([]TrendingServerPayload, 0)
	for rows.Next() {
		var item TrendingServerPayload
		if err = rows.Scan(
			&item.ID,
			&item.Name,
			&item.Icon,
			&item.Banner,
			&item.Description,
			&item.Category,
			&item.Tags,
			&item.CompositeScore,
			&item.GrowthScore,
			&item.Engagement,
			&item.Retention,
			&item.TrustScore,
			&item.Reasons,
		); err != nil {
			h.logger.Error("failed to scan trending server row", zap.Error(err))
			http.Error(w, "internal server error", http.StatusInternalServerError)
			return
		}
		if len(item.Reasons) == 0 {
			item.Reasons = deriveTrendingReasons(item.GrowthScore, item.Engagement, item.Retention, item.TrustScore)
		}
		results = append(results, item)
	}

	if err = rows.Err(); err != nil {
		h.logger.Error("failed iterating trending server rows", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"servers": results,
		"count":   len(results),
		"filters": map[string]interface{}{
			"category": category,
			"limit":    limit,
			"offset":   offset,
		},
	})
}

func deriveTrendingReasons(growth, engagement, retention, trust float64) []string {
	reasons := make([]string, 0, 4)
	if growth >= 60 {
		reasons = append(reasons, "fast_growth")
	}
	if engagement >= 60 {
		reasons = append(reasons, "high_engagement")
	}
	if retention >= 60 {
		reasons = append(reasons, "strong_retention")
	}
	if trust >= 60 {
		reasons = append(reasons, "high_trust")
	}
	if len(reasons) == 0 {
		reasons = append(reasons, "trending_now")
	}
	return reasons
}
