package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/handlers"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestOAuth2Handler_GetAuthorizeInfo_MissingClientID(t *testing.T) {
	logger := zap.NewNop()
	oauthHandler := handlers.NewOAuth2Handler(nil, logger)

	req := httptest.NewRequest("GET", "/oauth2/authorize", nil)
	rr := httptest.NewRecorder()

	oauthHandler.GetAuthorizeInfo(rr, req)

	assert.Equal(t, http.StatusBadRequest, rr.Code)
}

func TestOAuth2Handler_AuthorizeBot_Unauthenticated(t *testing.T) {
	logger := zap.NewNop()
	oauthHandler := handlers.NewOAuth2Handler(nil, logger)

	bodyBytes, _ := json.Marshal(map[string]string{
		"client_id": "00000000-0000-0000-0000-000000000001",
		"guild_id":  "00000000-0000-0000-0000-000000000002",
	})

	req := httptest.NewRequest("POST", "/oauth2/authorize", bytes.NewBuffer(bodyBytes))
	rr := httptest.NewRecorder()

	oauthHandler.AuthorizeBot(rr, req)

	assert.Equal(t, http.StatusUnauthorized, rr.Code)
}
