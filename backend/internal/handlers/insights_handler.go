package handlers

import (
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type InsightsHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewInsightsHandler(db *pgxpool.Pool, logger *zap.Logger) *InsightsHandler {
	return &InsightsHandler{
		db:     db,
		logger: logger.Named("handler.insights"),
	}
}

func (h *InsightsHandler) GetServerInsights(w http.ResponseWriter, r *http.Request) {
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

	var isMember bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.server_members
			WHERE server_id = $1
			  AND user_id = $2
		)
	`, serverUUID, userUUID).Scan(&isMember); err != nil {
		h.logger.Error("failed checking membership for insights", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch server insights")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT
			metric_date,
			member_count,
			new_members,
			messages_sent,
			active_members,
			voice_active_members,
			retention_members,
			growth_rate,
			engagement_rate,
			retention_rate
		FROM public.server_daily_metrics
		WHERE server_id = $1
		ORDER BY metric_date DESC
		LIMIT 30
	`, serverUUID)
	if err != nil {
		h.logger.Error("failed querying server daily metrics", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch server insights")
		return
	}
	defer rows.Close()

	daily := make([]map[string]interface{}, 0)
	for rows.Next() {
		var metricDate time.Time
		var memberCount, newMembers, messagesSent, activeMembers, voiceActiveMembers, retentionMembers int
		var growthRate, engagementRate, retentionRate float64
		if err = rows.Scan(
			&metricDate,
			&memberCount,
			&newMembers,
			&messagesSent,
			&activeMembers,
			&voiceActiveMembers,
			&retentionMembers,
			&growthRate,
			&engagementRate,
			&retentionRate,
		); err != nil {
			h.logger.Error("failed scanning server daily metrics row", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to fetch server insights")
			return
		}
		daily = append(daily, map[string]interface{}{
			"date":                 metricDate.Format("2006-01-02"),
			"member_count":         memberCount,
			"new_members":          newMembers,
			"messages_sent":        messagesSent,
			"active_members":       activeMembers,
			"voice_active_members": voiceActiveMembers,
			"retention_members":    retentionMembers,
			"growth_rate":          growthRate,
			"engagement_rate":      engagementRate,
			"retention_rate":       retentionRate,
		})
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("failed iterating server daily metrics rows", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch server insights")
		return
	}

	var totalMembers int
	var newMembers30d int
	var messages30d int
	var activeMembers30d int
	var voiceActiveMembers int
	if err = h.db.QueryRow(r.Context(), `
		SELECT
			(SELECT COUNT(*) FROM public.server_members sm WHERE sm.server_id = $1) AS total_members,
			(SELECT COUNT(*) FROM public.server_members sm WHERE sm.server_id = $1 AND sm.joined_at >= NOW() - INTERVAL '30 days') AS new_members_30d,
			(
				SELECT COUNT(*)
				FROM public.messages m
				INNER JOIN public.channels c ON c.id = m.channel_id
				WHERE c.server_id = $1
				  AND m.created_at >= NOW() - INTERVAL '30 days'
			) AS messages_30d,
			(
				SELECT COUNT(DISTINCT m.author_id)
				FROM public.messages m
				INNER JOIN public.channels c ON c.id = m.channel_id
				WHERE c.server_id = $1
				  AND m.created_at >= NOW() - INTERVAL '30 days'
			) AS active_members_30d,
			(
				SELECT COUNT(*)
				FROM public.voice_states vs
				WHERE vs.server_id = $1
			) AS voice_active_members
	`, serverUUID).Scan(&totalMembers, &newMembers30d, &messages30d, &activeMembers30d, &voiceActiveMembers); err != nil {
		h.logger.Error("failed aggregating current server insights", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch server insights")
		return
	}

	engagementRate := 0.0
	retentionRate := 0.0
	growthRate := 0.0
	if totalMembers > 0 {
		engagementRate = (float64(activeMembers30d) / float64(totalMembers)) * 100
		retentionRate = (float64(voiceActiveMembers) / float64(totalMembers)) * 100
		growthRate = (float64(newMembers30d) / float64(totalMembers)) * 100
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id": serverUUID.String(),
		"summary": map[string]interface{}{
			"member_count":         totalMembers,
			"new_members_30d":      newMembers30d,
			"messages_30d":         messages30d,
			"active_members_30d":   activeMembers30d,
			"voice_active_members": voiceActiveMembers,
			"growth_rate":          growthRate,
			"engagement_rate":      engagementRate,
			"retention_rate":       retentionRate,
		},
		"daily_metrics": daily,
		"window_days":   30,
	})
}
