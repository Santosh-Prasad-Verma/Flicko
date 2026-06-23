package game

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type StatsHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewStatsHandler(db *pgxpool.Pool, logger *zap.Logger) *StatsHandler {
	return &StatsHandler{
		db:     db,
		logger: logger,
	}
}

type topGame struct {
	Name  string `json:"name"`
	Hours string `json:"hours"`
	Color string `json:"color"`
}

type recentCampaign struct {
	Name     string `json:"name"`
	Progress int    `json:"progress"`
	Cover    string `json:"cover"`
}

type statsResponse struct {
	TotalHours      string           `json:"total_hours"`
	Trend           string           `json:"trend"`
	TopGames        []topGame        `json:"top_games"`
	RecentCampaigns []recentCampaign `json:"recent_campaigns"`
	ActivityHeatmap []int            `json:"activity_heatmap"`
}

func (h *StatsHandler) HandleGetStats(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value("userID").(string)

	var count int
	err := h.db.QueryRow(r.Context(),
		"SELECT COUNT(*) FROM games WHERE player_a = $1 OR player_b = $1", userID,
	).Scan(&count)
	if err != nil {
		h.logger.Warn("failed to query game count, defaulting to 0",
			zap.String("user_id", userID), zap.Error(err))
		count = 0
	}

	ludoCount := h.countByType(r.Context(), userID, "ludo")
	otherCount := count - ludoCount
	if otherCount < 0 {
		otherCount = 0
	}

	totalHours := 12340 + float64(count)*2.5

	resp := statsResponse{
		TotalHours: formatWithCommas(int(totalHours)) + "h",
		Trend:      "+18%",
		TopGames: []topGame{
			{Name: "Ludo", Hours: scaledHours(4200, ludoCount), Color: "#40916C"},
			{Name: "Cyber Arena", Hours: scaledHours(2100, otherCount), Color: "#52B788"},
		},
		RecentCampaigns: []recentCampaign{
			{Name: "Cyber Ninja", Progress: 72, Cover: "/gaming/cyber_ninja.png"},
			{Name: "Dragon Quest", Progress: 45, Cover: "/gaming/dragon_quest.png"},
			{Name: "Space Odyssey", Progress: 91, Cover: "/gaming/space_odyssey.png"},
		},
		ActivityHeatmap: buildHeatmap(count),
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

// countByType returns the number of games of a given game_type the user has played.
func (h *StatsHandler) countByType(ctx context.Context, userID, gameType string) int {
	var n int
	err := h.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM games WHERE (player_a = $1 OR player_b = $1) AND game_type = $2",
		userID, gameType,
	).Scan(&n)
	if err != nil {
		h.logger.Warn("failed to query game count by type",
			zap.String("user_id", userID),
			zap.String("game_type", gameType),
			zap.Error(err))
		return 0
	}
	return n
}

// scaledHours produces a "X,XXXh" string scaled by real game count on top of a base.
func scaledHours(base, count int) string {
	return formatWithCommas(base+count*3) + "h"
}

// buildHeatmap returns 60 cells (10 cols × 6 rows) of intensity 0..3,
// seeded so that more games → denser activity.
func buildHeatmap(gameCount int) []int {
	cells := make([]int, 60)
	// base pattern, then layer in extra "hot" cells proportional to gameCount.
	pattern := []int{
		1, 0, 2, 3, 1, 0, 0, 2, 3, 1,
		2, 1, 0, 3, 2, 1, 1, 0, 2, 3,
		0, 1, 2, 1, 3, 2, 0, 1, 1, 2,
		3, 2, 1, 0, 1, 2, 3, 1, 0, 2,
		1, 3, 2, 0, 1, 1, 2, 3, 0, 1,
		2, 1, 3, 2, 0, 1, 1, 2, 3, 0,
	}
	copy(cells, pattern)
	bumps := gameCount / 10
	for i := 0; i < bumps && i < len(cells); i++ {
		idx := (i * 7) % len(cells)
		if cells[idx] < 3 {
			cells[idx]++
		}
	}
	return cells
}

// formatWithCommas renders an integer with thousand-separator commas (e.g. 12345 → "12,345").
func formatWithCommas(n int) string {
	s := fmt.Sprintf("%d", n)
	if len(s) <= 3 {
		return s
	}
	var b strings.Builder
	offset := len(s) % 3
	if offset > 0 {
		b.WriteString(s[:offset])
	}
	for i := offset; i < len(s); i += 3 {
		if b.Len() > 0 {
			b.WriteByte(',')
		}
		b.WriteString(s[i : i+3])
	}
	return b.String()
}
