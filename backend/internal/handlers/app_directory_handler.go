package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type AppDirectoryHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewAppDirectoryHandler(db *pgxpool.Pool, logger *zap.Logger) *AppDirectoryHandler {
	return &AppDirectoryHandler{
		db:     db,
		logger: logger.Named("handler.app_directory"),
	}
}

func (h *AppDirectoryHandler) ListAppDirectory(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	search := strings.TrimSpace(query.Get("q"))
	category := strings.TrimSpace(query.Get("category"))
	verifiedOnly := strings.EqualFold(strings.TrimSpace(query.Get("verified")), "true")

	limit := 25
	if l, err := strconv.Atoi(query.Get("limit")); err == nil && l > 0 {
		if l > 100 {
			l = 100
		}
		limit = l
	}
	offset := 0
	if o, err := strconv.Atoi(query.Get("offset")); err == nil && o >= 0 {
		offset = o
	}

	args := make([]interface{}, 0, 5)
	filters := []string{"ade.is_listed = TRUE", "a.is_active = TRUE"}

	if search != "" {
		escaped := strings.ReplaceAll(search, "\\", "\\\\")
		escaped = strings.ReplaceAll(escaped, "%", "\\%")
		escaped = strings.ReplaceAll(escaped, "_", "\\_")
		args = append(args, "%"+escaped+"%")
		idx := len(args)
		filters = append(filters, "(a.name ILIKE $"+strconv.Itoa(idx)+" ESCAPE '\\' OR ade.short_description ILIKE $"+strconv.Itoa(idx)+" ESCAPE '\\')")
	}
	if category != "" {
		args = append(args, category)
		filters = append(filters, "ade.category = $"+strconv.Itoa(len(args)))
	}
	if verifiedOnly {
		filters = append(filters, "ade.verified = TRUE")
	}

	args = append(args, limit, offset)
	limitIdx := len(args) - 1
	offsetIdx := len(args)

	sql := `
		SELECT
			a.id,
			a.name,
			a.description,
			a.icon_url,
			ade.category,
			ade.short_description,
			ade.tags,
			ade.verified,
			ade.trust_score,
			COALESCE(r.avg_rating, 0) AS avg_rating,
			COALESCE(r.review_count, 0) AS review_count,
			COALESCE(i.install_count, 0) AS install_count
		FROM public.app_directory_entries ade
		INNER JOIN public.applications a ON a.id = ade.app_id
		LEFT JOIN (
			SELECT app_id, AVG(rating)::numeric(4,2) AS avg_rating, COUNT(*)::int AS review_count
			FROM public.app_reviews
			WHERE status = 'published'
			GROUP BY app_id
		) r ON r.app_id = a.id
		LEFT JOIN (
			SELECT app_id, COUNT(*)::int AS install_count
			FROM public.application_installs
			WHERE status = 'active'
			GROUP BY app_id
		) i ON i.app_id = a.id
		WHERE ` + strings.Join(filters, " AND ") + `
		ORDER BY ade.verified DESC, ade.trust_score DESC, COALESCE(i.install_count, 0) DESC, a.name ASC
		LIMIT $` + strconv.Itoa(limitIdx) + ` OFFSET $` + strconv.Itoa(offsetIdx)

	rows, err := h.db.Query(r.Context(), sql, args...)
	if err != nil {
		h.logger.Error("failed to list app directory", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list app directory")
		return
	}
	defer rows.Close()

	entries := make([]map[string]interface{}, 0)
	for rows.Next() {
		var appID string
		var name string
		var description *string
		var iconURL *string
		var entryCategory string
		var shortDescription string
		var tags []string
		var verified bool
		var trustScore float64
		var avgRating float64
		var reviewCount int
		var installCount int
		if err = rows.Scan(
			&appID,
			&name,
			&description,
			&iconURL,
			&entryCategory,
			&shortDescription,
			&tags,
			&verified,
			&trustScore,
			&avgRating,
			&reviewCount,
			&installCount,
		); err != nil {
			h.logger.Error("failed to scan app directory row", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to list app directory")
			return
		}

		entries = append(entries, map[string]interface{}{
			"app_id":             appID,
			"name":               name,
			"description":        description,
			"icon_url":           iconURL,
			"category":           entryCategory,
			"short_description":  shortDescription,
			"tags":               tags,
			"verified":           verified,
			"trust_score":        trustScore,
			"average_rating":     avgRating,
			"review_count":       reviewCount,
			"active_install_cnt": installCount,
		})
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("app directory rows iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list app directory")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"entries": entries,
		"count":   len(entries),
		"filters": map[string]interface{}{
			"q":        search,
			"category": category,
			"verified": verifiedOnly,
			"limit":    limit,
			"offset":   offset,
		},
	})
}
