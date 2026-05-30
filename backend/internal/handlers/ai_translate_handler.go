package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/ai/translate"
)

// AITranslateHandler exposes the inline translation endpoints.
//
//	POST /api/v1/ai/translate
//	GET  /api/v1/ai/translate/settings
//	PATCH /api/v1/ai/translate/settings
type AITranslateHandler struct {
	svc    translate.Service
	logger *zap.Logger
}

// NewAITranslateHandler wires the handler.
func NewAITranslateHandler(svc translate.Service, logger *zap.Logger) *AITranslateHandler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &AITranslateHandler{svc: svc, logger: logger.Named("handler.ai_translate")}
}

// RegisterRoutes hooks the handler into a (presumably authenticated) router.
func (h *AITranslateHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/ai/translate", h.Translate).Methods(http.MethodPost)
	r.HandleFunc("/ai/translate/settings", h.GetSettings).Methods(http.MethodGet)
	r.HandleFunc("/ai/translate/settings", h.UpdateSettings).Methods(http.MethodPatch)
}

type translateBody struct {
	Text      string `json:"text"`
	Target    string `json:"target_lang"`
	Hint      string `json:"src_lang,omitempty"`
	ServerID  string `json:"server_id,omitempty"`
	ChannelID string `json:"channel_id,omitempty"`
	MessageID string `json:"message_id,omitempty"`
}

// Translate handles per-message inline translation.
func (h *AITranslateHandler) Translate(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var b translateBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if b.Text == "" || b.Target == "" {
		writeError(w, http.StatusBadRequest, "text and target_lang are required")
		return
	}
	if len(b.Text) > 8000 {
		writeError(w, http.StatusBadRequest, "text too long (max 8000 chars)")
		return
	}

	res, err := h.svc.Translate(r.Context(), translate.TranslateInput{
		UserID:    userID,
		ServerID:  b.ServerID,
		ChannelID: b.ChannelID,
		MessageID: b.MessageID,
		Text:      b.Text,
		Target:    b.Target,
		Hint:      b.Hint,
	})
	if err != nil {
		h.logger.Warn("translate failed", zap.Error(err))
		writeError(w, http.StatusBadGateway, "translate_unavailable")
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// GetSettings returns the caller's translate preferences. Defaults are
// synthesised inline if no row exists yet so the client can always render.
func (h *AITranslateHandler) GetSettings(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	s, err := h.svc.GetUserSettings(r.Context(), userID)
	if err != nil {
		h.logger.Error("get translate settings", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	writeJSON(w, http.StatusOK, s)
}

type updateSettingsBody struct {
	TargetLang       *string  `json:"target_lang,omitempty"`
	FluentLangs      []string `json:"fluent_langs,omitempty"`
	Behavior         *string  `json:"behavior,omitempty"`
	ShowProviderChip *bool    `json:"show_provider_chip,omitempty"`
}

// UpdateSettings patches the caller's preferences. All fields are optional —
// omitted fields keep their current value.
func (h *AITranslateHandler) UpdateSettings(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var b updateSettingsBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if b.Behavior != nil {
		switch *b.Behavior {
		case "always", "ask", "never":
		default:
			writeError(w, http.StatusBadRequest, "behavior must be always|ask|never")
			return
		}
	}
	s, err := h.svc.UpdateUserSettings(r.Context(), userID, translate.UserSettingsPatch{
		TargetLang:       b.TargetLang,
		FluentLangs:      b.FluentLangs,
		Behavior:         b.Behavior,
		ShowProviderChip: b.ShowProviderChip,
	})
	if err != nil {
		h.logger.Error("update translate settings", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	writeJSON(w, http.StatusOK, s)
}
