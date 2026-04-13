package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CommunityService interface {
	EnableCommunity(ctx context.Context, serverID, executorID, rulesChannelID string, category *string, tags []string) (*models.Community, error)
	UpdateCommunity(ctx context.Context, serverID, executorID string, category *string, tags []string, isDiscoverable *bool) (*models.Community, error)
	DiscoverCommunities(ctx context.Context, category *string, minMembers int, limit int) ([]*models.DiscoverableCommunity, error)
}

type communityService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewCommunityService(db *pgxpool.Pool, permService PermissionService) CommunityService {
	return &communityService{
		db:          db,
		permService: permService,
	}
}

func (s *communityService) EnableCommunity(ctx context.Context, serverID, executorID, rulesChannelID string, category *string, tags []string) (*models.Community, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	rulesChanUUID, err3 := uuid.Parse(rulesChannelID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD")
	}

	query := `
		INSERT INTO public.communities (server_id, is_verified, category, tags, rules_channel_id, is_discoverable)
		VALUES ($1, false, $2, $3, $4, true)
		RETURNING server_id, is_verified, category, tags, rules_channel_id, member_count, activity_score, growth_rate, is_discoverable, created_at, updated_at
	`
	var c models.Community
	err = s.db.QueryRow(ctx, query, serverUUID, category, tags, rulesChanUUID).
		Scan(&c.ServerID, &c.IsVerified, &c.Category, &c.Tags, &c.RulesChannelID, &c.MemberCount, &c.ActivityScore, &c.GrowthRate, &c.IsDiscoverable, &c.CreatedAt, &c.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to enable community: %w", err)
	}

	return &c, nil
}

func (s *communityService) UpdateCommunity(ctx context.Context, serverID, executorID string, category *string, tags []string, isDiscoverable *bool) (*models.Community, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD")
	}

	// Construct dynamic update
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{serverUUID}
	argID := 2

	if category != nil {
		setClauses = append(setClauses, fmt.Sprintf("category = $%d", argID))
		args = append(args, *category)
		argID++
	}
	if tags != nil {
		setClauses = append(setClauses, fmt.Sprintf("tags = $%d", argID))
		args = append(args, tags)
		argID++
	}
	if isDiscoverable != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_discoverable = $%d", argID))
		args = append(args, *isDiscoverable)
		argID++
	}

	query := fmt.Sprintf(`
		UPDATE public.communities
		SET %s
		WHERE server_id = $1
		RETURNING server_id, is_verified, category, tags, rules_channel_id, member_count, activity_score, growth_rate, is_discoverable, created_at, updated_at
	`, strings.Join(setClauses, ", "))

	var c models.Community
	err = s.db.QueryRow(ctx, query, args...).
		Scan(&c.ServerID, &c.IsVerified, &c.Category, &c.Tags, &c.RulesChannelID, &c.MemberCount, &c.ActivityScore, &c.GrowthRate, &c.IsDiscoverable, &c.CreatedAt, &c.UpdatedAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("community not found")
		}
		return nil, fmt.Errorf("failed to update community: %w", err)
	}

	return &c, nil
}

func (s *communityService) DiscoverCommunities(ctx context.Context, category *string, minMembers int, limit int) ([]*models.DiscoverableCommunity, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	whereClauses := []string{"c.is_discoverable = true", "c.member_count >= $1"}
	args := []interface{}{minMembers, limit}

	if category != nil {
		whereClauses = append(whereClauses, "c.category = $3")
		args = append(args, *category)
	}

	query := fmt.Sprintf(`
		SELECT 
			c.server_id, c.is_verified, c.category, c.tags, c.rules_channel_id, c.member_count, c.activity_score, c.growth_rate, c.is_discoverable, c.created_at, c.updated_at,
			s.name, s.description, s.icon_url
		FROM public.communities c
		JOIN public.servers s ON c.server_id = s.id
		WHERE %s
		ORDER BY c.activity_score DESC, c.member_count DESC
		LIMIT $2
	`, strings.Join(whereClauses, " AND "))

	rows, err := s.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch discovery list: %w", err)
	}
	defer rows.Close()

	var results []*models.DiscoverableCommunity
	for rows.Next() {
		var dc models.DiscoverableCommunity
		err := rows.Scan(
			&dc.ServerID, &dc.IsVerified, &dc.Category, &dc.Tags, &dc.RulesChannelID, &dc.MemberCount, &dc.ActivityScore, &dc.GrowthRate, &dc.IsDiscoverable, &dc.CreatedAt, &dc.UpdatedAt,
			&dc.ServerName, &dc.ServerDescription, &dc.ServerIconURL,
		)
		if err != nil {
			return nil, err
		}
		results = append(results, &dc)
	}

	return results, nil
}
