package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Boost Service Interface ────────────────────────────────────────────────

type BoostService interface {
	CreateBoost(ctx context.Context, serverID, userID string, durationDays int) (*models.ServerBoost, *models.ServerBoostStatus, error)
	GetActiveBoosts(ctx context.Context, serverID string) ([]*models.ServerBoost, error)
	CancelBoost(ctx context.Context, serverID, boostID, userID string) error
	GetBoostStatus(ctx context.Context, serverID string) (*models.ServerBoostStatus, error)
	RecalculateBoostLevel(ctx context.Context, serverID string) (*models.ServerBoostStatus, error)
}

type boostService struct {
	db       *pgxpool.Pool
	auditSvc AuditLogService
}

func NewBoostService(db *pgxpool.Pool, auditSvc AuditLogService) BoostService {
	return &boostService{db: db, auditSvc: auditSvc}
}

func (s *boostService) CreateBoost(ctx context.Context, serverID, userID string, durationDays int) (*models.ServerBoost, *models.ServerBoostStatus, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return nil, nil, fmt.Errorf("invalid uuid")
	}

	if durationDays <= 0 {
		durationDays = 30
	}

	expiresAt := time.Now().Add(time.Duration(durationDays) * 24 * time.Hour)

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, nil, err
	}
	defer tx.Rollback(ctx)

	// Insert boost record
	var boost models.ServerBoost
	err = tx.QueryRow(ctx,
		`INSERT INTO public.server_boosts (server_id, user_id, expires_at) 
		 VALUES ($1, $2, $3) 
		 RETURNING id, server_id, user_id, started_at, expires_at, is_active`,
		serverUUID, userUUID, expiresAt,
	).Scan(&boost.ID, &boost.ServerID, &boost.UserID, &boost.StartedAt, &boost.ExpiresAt, &boost.IsActive)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create boost: %w", err)
	}

	// Recalculate boost level within transaction
	var activeCount int
	err = tx.QueryRow(ctx,
		"SELECT COUNT(*) FROM public.server_boosts WHERE server_id = $1 AND is_active = true AND expires_at > NOW()",
		serverUUID,
	).Scan(&activeCount)
	if err != nil {
		return nil, nil, err
	}

	newLevel := models.CalculateBoostLevel(activeCount)
	perks := models.LevelPerks[newLevel]
	perksJSON, _ := json.Marshal(perks)

	var status models.ServerBoostStatus
	err = tx.QueryRow(ctx,
		`INSERT INTO public.server_boost_status (server_id, boost_count, boost_level, perks, updated_at)
		 VALUES ($1, $2, $3, $4, NOW())
		 ON CONFLICT (server_id) DO UPDATE SET boost_count = $2, boost_level = $3, perks = $4, updated_at = NOW()
		 RETURNING server_id, boost_count, boost_level, perks, updated_at`,
		serverUUID, activeCount, newLevel, perksJSON,
	).Scan(&status.ServerID, &status.BoostCount, &status.BoostLevel, &status.Perks, &status.UpdatedAt)
	if err != nil {
		return nil, nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, err
	}

	return &boost, &status, nil
}

func (s *boostService) GetActiveBoosts(ctx context.Context, serverID string) ([]*models.ServerBoost, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	rows, err := s.db.Query(ctx,
		"SELECT id, server_id, user_id, started_at, expires_at, is_active FROM public.server_boosts WHERE server_id = $1 AND is_active = true AND expires_at > NOW() ORDER BY started_at DESC",
		serverUUID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var boosts []*models.ServerBoost
	for rows.Next() {
		b := &models.ServerBoost{}
		if err := rows.Scan(&b.ID, &b.ServerID, &b.UserID, &b.StartedAt, &b.ExpiresAt, &b.IsActive); err != nil {
			return nil, err
		}
		boosts = append(boosts, b)
	}
	return boosts, nil
}

func (s *boostService) CancelBoost(ctx context.Context, serverID, boostID, userID string) error {
	serverUUID, err1 := uuid.Parse(serverID)
	boostUUID, err2 := uuid.Parse(boostID)
	userUUID, err3 := uuid.Parse(userID)
	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid")
	}

	// Only the boost owner can cancel
	res, err := s.db.Exec(ctx,
		"UPDATE public.server_boosts SET is_active = false WHERE id = $1 AND server_id = $2 AND user_id = $3",
		boostUUID, serverUUID, userUUID,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("boost not found or unauthorized")
	}

	// Recalculate
	_, err = s.RecalculateBoostLevel(ctx, serverID)
	return err
}

func (s *boostService) GetBoostStatus(ctx context.Context, serverID string) (*models.ServerBoostStatus, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	var status models.ServerBoostStatus
	err = s.db.QueryRow(ctx,
		"SELECT server_id, boost_count, boost_level, perks, updated_at FROM public.server_boost_status WHERE server_id = $1",
		serverUUID,
	).Scan(&status.ServerID, &status.BoostCount, &status.BoostLevel, &status.Perks, &status.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &models.ServerBoostStatus{ServerID: serverID, BoostLevel: 0, BoostCount: 0}, nil
		}
		return nil, err
	}
	return &status, nil
}

func (s *boostService) RecalculateBoostLevel(ctx context.Context, serverID string) (*models.ServerBoostStatus, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	var activeCount int
	err = s.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM public.server_boosts WHERE server_id = $1 AND is_active = true AND expires_at > NOW()",
		serverUUID,
	).Scan(&activeCount)
	if err != nil {
		return nil, err
	}

	newLevel := models.CalculateBoostLevel(activeCount)
	perks := models.LevelPerks[newLevel]
	perksJSON, _ := json.Marshal(perks)

	var status models.ServerBoostStatus
	err = s.db.QueryRow(ctx,
		`INSERT INTO public.server_boost_status (server_id, boost_count, boost_level, perks, updated_at)
		 VALUES ($1, $2, $3, $4, NOW())
		 ON CONFLICT (server_id) DO UPDATE SET boost_count = $2, boost_level = $3, perks = $4, updated_at = NOW()
		 RETURNING server_id, boost_count, boost_level, perks, updated_at`,
		serverUUID, activeCount, newLevel, perksJSON,
	).Scan(&status.ServerID, &status.BoostCount, &status.BoostLevel, &status.Perks, &status.UpdatedAt)
	if err != nil {
		return nil, err
	}

	return &status, nil
}
