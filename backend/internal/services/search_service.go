package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Search Service Interface ───────────────────────────────────────────────

type SearchResult struct {
	MessageID   string  `json:"message_id"`
	ChannelID   string  `json:"channel_id"`
	ChannelName string  `json:"channel_name"`
	AuthorID    string  `json:"author_id"`
	Content     string  `json:"content"`
	Rank        float64 `json:"rank"`
	CreatedAt   string  `json:"created_at"`
}

type SearchService interface {
	SearchMessages(ctx context.Context, userID, query string, channelFilter, authorFilter *string, hasLink, hasEmbed *bool, limit int) ([]*SearchResult, error)
	SearchCommunities(ctx context.Context, query string, category *string, tags []string, limit int) ([]*CommunitySearchResult, error)
}

type CommunitySearchResult struct {
	ServerID      string  `json:"server_id"`
	ServerName    string  `json:"server_name"`
	Description   *string `json:"description,omitempty"`
	MemberCount   int     `json:"member_count"`
	ActivityScore float64 `json:"activity_score"`
	Category      *string `json:"category,omitempty"`
	Rank          float64 `json:"rank"`
}

type searchService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewSearchService(db *pgxpool.Pool, permService PermissionService) SearchService {
	return &searchService{db: db, permService: permService}
}

func (s *searchService) SearchMessages(ctx context.Context, userID, query string, channelFilter, authorFilter *string, hasLink, hasEmbed *bool, limit int) ([]*SearchResult, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	if limit <= 0 || limit > 50 {
		limit = 50
	}

	if strings.TrimSpace(query) == "" {
		return nil, fmt.Errorf("search query cannot be empty")
	}

	// Build dynamic query using the search_messages SQL function or direct tsquery
	whereClauses := []string{
		"m.search_vector @@ websearch_to_tsquery('english', $1)",
	}
	args := []interface{}{query, userUUID, limit}
	argID := 4

	if channelFilter != nil {
		chanUUID, err := uuid.Parse(*channelFilter)
		if err != nil {
			return nil, fmt.Errorf("invalid channel filter uuid")
		}
		whereClauses = append(whereClauses, fmt.Sprintf("m.channel_id = $%d", argID))
		args = append(args, chanUUID)
		argID++
	}

	if authorFilter != nil {
		authUUID, err := uuid.Parse(*authorFilter)
		if err != nil {
			return nil, fmt.Errorf("invalid author filter uuid")
		}
		whereClauses = append(whereClauses, fmt.Sprintf("m.author_id = $%d", argID))
		args = append(args, authUUID)
		argID++
	}

	if hasLink != nil && *hasLink {
		whereClauses = append(whereClauses, "m.content ~ 'https?://'")
	}

	sqlQuery := fmt.Sprintf(`
		SELECT m.id, m.channel_id, c.name, m.author_id, m.content,
			   ts_rank(m.search_vector, websearch_to_tsquery('english', $1)) AS rank,
			   m.created_at::text
		FROM public.messages m
		JOIN public.channels c ON m.channel_id = c.id
		WHERE %s
		  AND public.has_permission($2, m.channel_id, 'VIEW_CHANNEL')
		ORDER BY rank DESC, m.created_at DESC
		LIMIT $3
	`, strings.Join(whereClauses, " AND "))

	rows, err := s.db.Query(ctx, sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("search query failed: %w", err)
	}
	defer rows.Close()

	var results []*SearchResult
	for rows.Next() {
		r := &SearchResult{}
		if err := rows.Scan(&r.MessageID, &r.ChannelID, &r.ChannelName, &r.AuthorID, &r.Content, &r.Rank, &r.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, r)
	}

	// Suppress unused variable warning
	_ = userUUID

	return results, nil
}

func (s *searchService) SearchCommunities(ctx context.Context, query string, category *string, tags []string, limit int) ([]*CommunitySearchResult, error) {
	if limit <= 0 || limit > 50 {
		limit = 50
	}

	whereClauses := []string{
		"c.is_discoverable = true",
	}
	args := []interface{}{limit}
	argID := 2

	if strings.TrimSpace(query) != "" {
		whereClauses = append(whereClauses, fmt.Sprintf(
			"to_tsvector('english', s.name || ' ' || COALESCE(s.description, '')) @@ websearch_to_tsquery('english', $%d)", argID,
		))
		args = append(args, query)
		argID++
	}

	if category != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("c.category = $%d", argID))
		args = append(args, *category)
		argID++
	}

	if len(tags) > 0 {
		whereClauses = append(whereClauses, fmt.Sprintf("c.tags && $%d", argID))
		args = append(args, tags)
		argID++
	}

	rankExpr := "1.0"
	if strings.TrimSpace(query) != "" {
		rankExpr = fmt.Sprintf("ts_rank(to_tsvector('english', s.name || ' ' || COALESCE(s.description, '')), websearch_to_tsquery('english', $%d))", argID)
		args = append(args, query)
		argID++
	}

	sqlQuery := fmt.Sprintf(`
		SELECT c.server_id, s.name, s.description, c.member_count, c.activity_score, c.category, %s AS rank
		FROM public.communities c
		JOIN public.servers s ON c.server_id = s.id
		WHERE %s
		ORDER BY rank DESC, c.activity_score DESC
		LIMIT $1
	`, rankExpr, strings.Join(whereClauses, " AND "))

	rows, err := s.db.Query(ctx, sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("community search failed: %w", err)
	}
	defer rows.Close()

	var results []*CommunitySearchResult
	for rows.Next() {
		r := &CommunitySearchResult{}
		if err := rows.Scan(&r.ServerID, &r.ServerName, &r.Description, &r.MemberCount, &r.ActivityScore, &r.Category, &r.Rank); err != nil {
			return nil, err
		}
		results = append(results, r)
	}

	return results, nil
}
