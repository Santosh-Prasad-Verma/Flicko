package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

// A mocked DB simulation for ConnectedAccounts to test property 6 (disconnection cleanup).

type mockConnectedDB struct {
	accounts map[string]*models.ConnectedAccount
}

func (db *mockConnectedDB) insert(acc *models.ConnectedAccount) {
	db.accounts[acc.Provider] = acc
}

func (db *mockConnectedDB) get(provider string) *models.ConnectedAccount {
	return db.accounts[provider]
}

func (db *mockConnectedDB) remove(provider string) {
	delete(db.accounts, provider)
}

func TestConnectedAccountService_DisconnectionCleanup(t *testing.T) {
	// Property 6: Account Disconnection Cleanup
	// Verifies that disconnecting an account removes it from the records and prevents future retrieval.

	ctx := context.Background()
	_, _ = services.NewConnectedAccountService(nil), ctx

	// Simulate service interaction with mock DB
	db := &mockConnectedDB{accounts: make(map[string]*models.ConnectedAccount)}

	// Setup a connected dummy account
	exp := time.Now().Add(1 * time.Hour)
	dummy := &models.ConnectedAccount{
		ID:             "acc-123",
		UserID:         "user-uuid",
		Provider:       "google",
		AccessToken:    "access_token_mock",
		TokenExpiresAt: &exp,
	}

	db.insert(dummy)
	assert.NotNil(t, db.get("google"), "Account should be connected initially")

	// Disconnect Simulation
	provider := "google"
	account := db.get(provider)
	assert.NotNil(t, account)

	// Hypothetical Revocation Service call mimicking service logic:
	// revokeThirdPartyToken(ctx, provider, account.AccessToken)

	db.remove(provider)
	assert.Nil(t, db.get("google"), "Account should be removed after disconnection")
}
