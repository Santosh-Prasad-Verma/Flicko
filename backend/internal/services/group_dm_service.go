package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GroupDMService is NOT wired into the HTTP router (cmd/server/main.go):
// group DMs are served by direct REST endpoints.
// Retained as a reference / ready-made backend-owned path.
type GroupDMService interface {
	CreateGroupDM(ctx context.Context, creatorID string, participantIDs []string) (*models.GroupDM, error)
	UpdateGroupDM(ctx context.Context, userID, groupID string, name, icon *string) (*models.GroupDM, error)
	RemoveParticipant(ctx context.Context, actingUserID, groupID, targetUserID string) error
	AddParticipant(ctx context.Context, ownerID, groupID, newUserID string) error
	GetGroupDMs(ctx context.Context, userID string) ([]*models.GroupDM, error)
}

type groupDMService struct {
	db *pgxpool.Pool
}

func NewGroupDMService(db *pgxpool.Pool) GroupDMService {
	return &groupDMService{
		db: db,
	}
}

func (s *groupDMService) CreateGroupDM(ctx context.Context, creatorID string, participantIDs []string) (*models.GroupDM, error) {
	creatorUUID, err := uuid.Parse(creatorID)
	if err != nil {
		return nil, fmt.Errorf("invalid creator uuid")
	}

	// 1. Validate participant count (2 to 10 including creator)
	uniqueParticipants := make(map[string]uuid.UUID)
	uniqueParticipants[creatorID] = creatorUUID

	for _, pID := range participantIDs {
		puuid, err := uuid.Parse(pID)
		if err != nil {
			return nil, fmt.Errorf("invalid participant uuid: %s", pID)
		}
		uniqueParticipants[pID] = puuid
	}

	participantCount := len(uniqueParticipants)
	if participantCount < 2 || participantCount > 10 {
		return nil, fmt.Errorf("group dm must have between 2 and 10 participants")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to start tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 2. Insert group_dms record
	groupID := uuid.New()
	queryMsg := `
		INSERT INTO public.group_dms (id, owner_id)
		VALUES ($1, $2)
		RETURNING id, name, icon, owner_id, is_active, created_at, updated_at
	`
	var group models.GroupDM
	err = tx.QueryRow(ctx, queryMsg, groupID, creatorUUID).
		Scan(&group.ID, &group.Name, &group.Icon, &group.OwnerID, &group.IsActive, &group.CreatedAt, &group.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create group dm: %w", err)
	}

	// 3. Batch insert group_dm_participants
	participantUUIDs := make([]uuid.UUID, 0, len(uniqueParticipants))
	for _, pUUID := range uniqueParticipants {
		participantUUIDs = append(participantUUIDs, pUUID)
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO public.group_dm_participants (group_dm_id, user_id)
		SELECT $1, unnest($2::uuid[])
	`, groupID, participantUUIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to add participants: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit tx: %w", err)
	}

	// broadcast "group_dm.created" via Realtime / WebPubSub here

	return &group, nil
}

func (s *groupDMService) UpdateGroupDM(ctx context.Context, userID, groupID string, name, icon *string) (*models.GroupDM, error) {
	userUUID, err1 := uuid.Parse(userID)
	groupUUID, err2 := uuid.Parse(groupID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	// Validate user is a participant
	var exists bool
	err := s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.group_dm_participants WHERE group_dm_id = $1 AND user_id = $2)", groupUUID, userUUID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("user is not a participant in this group dm")
	}

	query := `
		UPDATE public.group_dms
		SET 
			name = COALESCE($1, name),
			icon = COALESCE($2, icon),
			updated_at = NOW()
		WHERE id = $3
		RETURNING id, name, icon, owner_id, is_active, created_at, updated_at
	`

	var group models.GroupDM
	err = s.db.QueryRow(ctx, query, name, icon, groupUUID).
		Scan(&group.ID, &group.Name, &group.Icon, &group.OwnerID, &group.IsActive, &group.CreatedAt, &group.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to update group dm: %w", err)
	}

	return &group, nil
}

func (s *groupDMService) RemoveParticipant(ctx context.Context, actingUserID, groupID, targetUserID string) error {
	actingUUID, err1 := uuid.Parse(actingUserID)
	groupUUID, err2 := uuid.Parse(groupID)
	targetUUID, err3 := uuid.Parse(targetUserID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("failed to start tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Check permissions - acting user can remove themselves (leave), OR owner can remove anyone
	var ownerID uuid.UUID
	err = tx.QueryRow(ctx, "SELECT owner_id FROM public.group_dms WHERE id = $1", groupUUID).Scan(&ownerID)
	if err != nil {
		return fmt.Errorf("group dm not found")
	}

	isSelfRemoval := actingUUID == targetUUID
	isOwner := actingUUID == ownerID

	if !isSelfRemoval && !isOwner {
		return fmt.Errorf("only the owner can remove other participants")
	}

	res, err := tx.Exec(ctx, "DELETE FROM public.group_dm_participants WHERE group_dm_id = $1 AND user_id = $2", groupUUID, targetUUID)
	if err != nil {
		return fmt.Errorf("failed to remove participant: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("user is not a participant")
	}

	// Deactivate group if no participants left
	var currentCount int
	_ = tx.QueryRow(ctx, "SELECT COUNT(*) FROM public.group_dm_participants WHERE group_dm_id = $1", groupUUID).Scan(&currentCount)
	if currentCount < 1 {
		_, _ = tx.Exec(ctx, "UPDATE public.group_dms SET is_active = false, updated_at = NOW() WHERE id = $1", groupUUID)
	}

	return tx.Commit(ctx)
}

func (s *groupDMService) AddParticipant(ctx context.Context, actingUserID, groupID, newUserID string) error {
	actingUUID, err1 := uuid.Parse(actingUserID)
	groupUUID, err2 := uuid.Parse(groupID)
	newUUID, err3 := uuid.Parse(newUserID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("failed to start tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var ownerID uuid.UUID
	err = tx.QueryRow(ctx, "SELECT owner_id FROM public.group_dms WHERE id = $1 AND is_active = true", groupUUID).Scan(&ownerID)
	if err != nil {
		return fmt.Errorf("active group dm not found")
	}

	if actingUUID != ownerID {
		return fmt.Errorf("only the group owner can add participants")
	}

	var currentCount int
	_ = tx.QueryRow(ctx, "SELECT COUNT(*) FROM public.group_dm_participants WHERE group_dm_id = $1", groupUUID).Scan(&currentCount)
	if currentCount >= 10 {
		return fmt.Errorf("group dm already has the maximum of 10 participants")
	}

	_, err = tx.Exec(ctx, "INSERT INTO public.group_dm_participants (group_dm_id, user_id) VALUES ($1, $2)", groupUUID, newUUID)
	if err != nil {
		return fmt.Errorf("failed to add participant: %w", err)
	}

	return tx.Commit(ctx)
}

func (s *groupDMService) GetGroupDMs(ctx context.Context, userID string) ([]*models.GroupDM, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id")
	}

	query := `
		SELECT g.id, g.name, g.icon, g.owner_id, g.is_active, g.created_at, g.updated_at
		FROM public.group_dms g
		JOIN public.group_dm_participants p ON g.id = p.group_dm_id
		WHERE p.user_id = $1 AND g.is_active = true
		ORDER BY g.updated_at DESC
	`

	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to query group dms: %w", err)
	}
	defer rows.Close()

	var dms []*models.GroupDM
	for rows.Next() {
		dm := &models.GroupDM{}
		if err := rows.Scan(&dm.ID, &dm.Name, &dm.Icon, &dm.OwnerID, &dm.IsActive, &dm.CreatedAt, &dm.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		dms = append(dms, dm)
	}
	return dms, nil
}
