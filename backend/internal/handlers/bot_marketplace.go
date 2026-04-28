package handlers

import (
"encoding/json"
"net/http"

"github.com/flicko-org/flicko-backend/internal/bots/auth"
)

type RegisterBotRequest struct {
Name        string   `json:"name"`
Description string   `json:"description"`
WebhookURL  string   `json:"webhook_url"`
Permissions int64    `json:"permissions"`
Categories  []string `json:"categories"`
}

type RegisterBotResponse struct {
BotID         string `json:"bot_id"`
WebhookSecret string `json:"webhook_secret"`
}

type GenerateBotKeyRequest struct {
Name   string   `json:"name"`
Scopes []string `json:"scopes"`
}

func HandleRegisterBot(w http.ResponseWriter, r *http.Request) {
// In reality this decodes constraints, hits Supabase/Postgres to create bot, 
// extracts newly generated bot_id & secret, and returns it.

// Mock responding ok since this is an architectural scaffold:
w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusCreated)
json.NewEncoder(w).Encode(RegisterBotResponse{
BotID:         "mock-bot-uuid",
WebhookSecret: "mock-hex-secret", // Usually random hex or secure string
})
}

func HandleRotateBotSecret(w http.ResponseWriter, r *http.Request) {
w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusOK)
json.NewEncoder(w).Encode(map[string]string{
"message":        "Secret rotated successfully",
"webhook_secret": "new-mock-hex-secret",
})
}

func HandleGenerateAPIKey(w http.ResponseWriter, r *http.Request) {
var req GenerateBotKeyRequest
if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
http.Error(w, err.Error(), http.StatusBadRequest)
return
}

if !auth.ValidateScopes(req.Scopes) {
http.Error(w, "invalid scopes requested", http.StatusBadRequest)
return
}

raw, _, _, err := auth.GenerateAPIKey()
if err != nil {
http.Error(w, "failed to generate key", http.StatusInternalServerError)
return
}

w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusCreated)
json.NewEncoder(w).Encode(map[string]string{
"api_key": raw,
})
}
