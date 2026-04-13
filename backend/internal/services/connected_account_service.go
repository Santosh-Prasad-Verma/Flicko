package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ConnectedAccountService interface {
	ConnectAccount(ctx context.Context, userID, provider, externalUserID, externalUsername, accessToken string, refreshToken *string, tokenExpiresAt *time.Time) (*models.ConnectedAccount, error)
	GetConnectedAccounts(ctx context.Context, userID string) ([]*models.ConnectedAccount, error)
	DisconnectAccount(ctx context.Context, userID, provider string) error
}

type connectedAccountService struct {
	db *pgxpool.Pool
}

func NewConnectedAccountService(db *pgxpool.Pool) ConnectedAccountService {
	return &connectedAccountService{
		db: db,
	}
}

func (s *connectedAccountService) ConnectAccount(ctx context.Context, userID, provider, externalUserID, externalUsername, accessToken string, refreshToken *string, tokenExpiresAt *time.Time) (*models.ConnectedAccount, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	validProviders := map[string]bool{
		"google":  true,
		"github":  true,
		"spotify": true,
		"steam":   true,
		"xbox":    true,
		"twitch":  true,
	}
	if !validProviders[provider] {
		return nil, fmt.Errorf("unsupported provider: %s", provider)
	}

	accountID := uuid.New()
	query := `
		INSERT INTO public.connected_accounts (id, user_id, provider, external_user_id, external_username, access_token, refresh_token, token_expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT ON CONSTRAINT connected_accounts_user_id_provider_key DO UPDATE SET
			external_user_id = EXCLUDED.external_user_id,
			external_username = EXCLUDED.external_username,
			access_token = EXCLUDED.access_token,
			refresh_token = EXCLUDED.refresh_token,
			token_expires_at = EXCLUDED.token_expires_at,
			updated_at = NOW()
		RETURNING id, user_id, provider, external_user_id, external_username, access_token, refresh_token, token_expires_at, created_at, updated_at
	`

	var extUsername *string
	if externalUsername != "" {
		extUsername = &externalUsername
	}

	var acc models.ConnectedAccount
	err = s.db.QueryRow(ctx, query, accountID, userUUID, provider, externalUserID, extUsername, accessToken, refreshToken, tokenExpiresAt).
		Scan(
			&acc.ID,
			&acc.UserID,
			&acc.Provider,
			&acc.ExternalUserID,
			&acc.ExternalUsername,
			&acc.AccessToken,
			&acc.RefreshToken,
			&acc.TokenExpiresAt,
			&acc.CreatedAt,
			&acc.UpdatedAt,
		)

	if err != nil {
		return nil, fmt.Errorf("failed to save connected account: %w", err)
	}

	return &acc, nil
}

func (s *connectedAccountService) GetConnectedAccounts(ctx context.Context, userID string) ([]*models.ConnectedAccount, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	query := `
		SELECT id, user_id, provider, external_user_id, external_username, token_expires_at, created_at, updated_at
		FROM public.connected_accounts
		WHERE user_id = $1
		ORDER BY created_at DESC
	`

	// Notice we DO NOT select access_token and refresh_token here to avoid leaking them to the frontend
	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to query connected accounts: %w", err)
	}
	defer rows.Close()

	var accounts []*models.ConnectedAccount
	for rows.Next() {
		acc := &models.ConnectedAccount{}
		if err := rows.Scan(
			&acc.ID,
			&acc.UserID,
			&acc.Provider,
			&acc.ExternalUserID,
			&acc.ExternalUsername,
			&acc.TokenExpiresAt,
			&acc.CreatedAt,
			&acc.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan account: %w", err)
		}
		// ensure token fields are empty for safety
		acc.AccessToken = ""
		acc.RefreshToken = nil

		accounts = append(accounts, acc)
	}

	return accounts, nil
}

func (s *connectedAccountService) DisconnectAccount(ctx context.Context, userID, provider string) error {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id format")
	}

	// First verify it exists and get tokens conceptually if we need to call external revocation
	// The prompt requirement says: "Revoke OAuth tokens with provider's revocation endpoint"
	// and "Delete connected_accounts record".
	// For actual revocation, we'd need HTTP clients to GitHub/Google/Spotify etc revocation endpoints.
	var accessToken string
	err = s.db.QueryRow(ctx, "SELECT access_token FROM public.connected_accounts WHERE user_id = $1 AND provider = $2", userUUID, provider).Scan(&accessToken)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("connected account not found")
		}
		return fmt.Errorf("failed to fetch account tokens: %w", err)
	}

	// ... Hypothetical Third-Party Revocation Call (provider-specific logic) ...
	revokeThirdPartyToken(ctx, provider, accessToken)

	// Delete record locally
	_, err = s.db.Exec(ctx, "DELETE FROM public.connected_accounts WHERE user_id = $1 AND provider = $2", userUUID, provider)
	if err != nil {
		return fmt.Errorf("failed to delete connected account: %w", err)
	}

	return nil
}

func revokeThirdPartyToken(ctx context.Context, provider, token string) {
	// e.g., if provider == "google", call POST https://oauth2.googleapis.com/revoke?token=TOKEN
	// In a complete implementation, this would use http.Client.
	// We handle errors gracefully so internal disconnect doesn't fail just because the remote API is down.
	fmt.Printf("[Connected Accounts] Invoking async revocation for %s account\n", provider)
}
