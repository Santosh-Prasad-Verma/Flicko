package handlers

import (
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	InteractionTypePing               = 1
	InteractionTypeApplicationCommand = 2
	InteractionTypeMessageComponent   = 3

	ResponseTypePong                    = 1
	ResponseTypeChannelMessageWithSource = 4
	ResponseTypeDeferredChannelMessage  = 5

	MessageFlagEphemeral = 64 // 1 << 6
)

type Interaction struct {
	ID        string          `json:"id"`
	AppID     string          `json:"application_id"`
	Type      int             `json:"type"`
	Data      json.RawMessage `json:"data,omitempty"`
	GuildID   *string         `json:"guild_id,omitempty"`
	ChannelID *string         `json:"channel_id,omitempty"`
	Member    *InteractionUser `json:"member,omitempty"`
	Token     string          `json:"token"`
}

type InteractionUser struct {
	User BotUser `json:"user"`
}

type BotUser struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Bot      bool   `json:"bot"`
}

type InteractionResponse struct {
	Type int                     `json:"type"`
	Data *InteractionResponseData `json:"data,omitempty"`
}

type InteractionResponseData struct {
	TTS     bool    `json:"tts,omitempty"`
	Content string  `json:"content,omitempty"`
	Flags   int     `json:"flags,omitempty"`
}

type InteractionHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewInteractionHandler(db *pgxpool.Pool, logger *zap.Logger) *InteractionHandler {
	return &InteractionHandler{
		db:     db,
		logger: logger.Named("handler.interaction"),
	}
}

func VerifyEd25519Signature(publicKeyHex, signatureHex, timestamp string, body []byte) bool {
	pubBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil || len(pubBytes) != ed25519.PublicKeySize {
		return false
	}

	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil || len(sigBytes) != ed25519.SignatureSize {
		return false
	}

	ts, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return false
	}

	// 5-minute timestamp freshness window for replay protection
	if time.Since(time.Unix(ts, 0)).Abs() > 5*time.Minute {
		return false
	}

	msg := append([]byte(timestamp), body...)
	return ed25519.Verify(ed25519.PublicKey(pubBytes), msg, sigBytes)
}

func (h *InteractionHandler) HandleInteraction(w http.ResponseWriter, r *http.Request) {
	signature := r.Header.Get("X-Signature-Ed25519")
	timestamp := r.Header.Get("X-Signature-Timestamp")

	if signature == "" || timestamp == "" {
		http.Error(w, "missing signature headers", http.StatusUnauthorized)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	var interaction Interaction
	if err := json.Unmarshal(body, &interaction); err != nil {
		http.Error(w, "invalid interaction JSON", http.StatusBadRequest)
		return
	}

	// Fetch Application Public Key for signature verification
	var publicKeyHex string
	if h.db != nil {
		_ = h.db.QueryRow(r.Context(), "SELECT public_key FROM public.applications WHERE id = $1", interaction.AppID).Scan(&publicKeyHex)
	}

	if publicKeyHex != "" && !VerifyEd25519Signature(publicKeyHex, signature, timestamp, body) {
		http.Error(w, "invalid signature", http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// PING -> PONG
	if interaction.Type == InteractionTypePing {
		_ = json.NewEncoder(w).Encode(InteractionResponse{
			Type: ResponseTypePong,
		})
		return
	}

	// Handle Deferred or Ephemeral responses
	resp := InteractionResponse{
		Type: ResponseTypeChannelMessageWithSource,
		Data: &InteractionResponseData{
			Content: fmt.Sprintf("Interaction %s executed successfully!", interaction.ID),
		},
	}

	_ = json.NewEncoder(w).Encode(resp)
}
