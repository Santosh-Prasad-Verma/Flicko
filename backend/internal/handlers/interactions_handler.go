package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

var defaultApplicationID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

type InteractionsHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type createComponentInteractionRequest struct {
	ApplicationID   string          `json:"application_id,omitempty"`
	GuildID         string          `json:"guild_id,omitempty"`
	ChannelID       string          `json:"channel_id,omitempty"`
	SourceMessageID string          `json:"source_message_id,omitempty"`
	Data            json.RawMessage `json:"data,omitempty"`
	Component       json.RawMessage `json:"component,omitempty"`
	Attachments     json.RawMessage `json:"attachments,omitempty"`
}

type createModalInteractionRequest struct {
	ApplicationID string          `json:"application_id,omitempty"`
	GuildID       string          `json:"guild_id,omitempty"`
	ChannelID     string          `json:"channel_id,omitempty"`
	Data          json.RawMessage `json:"data,omitempty"`
	Modal         json.RawMessage `json:"modal,omitempty"`
	Attachments   json.RawMessage `json:"attachments,omitempty"`
}

func NewInteractionsHandler(db *pgxpool.Pool, logger *zap.Logger) *InteractionsHandler {
	return &InteractionsHandler{
		db:     db,
		logger: logger.Named("handler.interactions"),
	}
}

func (h *InteractionsHandler) CreateComponentInteraction(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := createComponentInteractionRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	appID, guildID, channelID, sourceMessageID, ok := parseInteractionIDs(
		req.ApplicationID, req.GuildID, req.ChannelID, req.SourceMessageID, w,
	)
	if !ok {
		return
	}

	if len(req.Data) == 0 {
		req.Data = json.RawMessage(`{}`)
	}
	if len(req.Component) == 0 {
		req.Component = json.RawMessage(`{}`)
	}
	if len(req.Attachments) == 0 {
		req.Attachments = json.RawMessage(`[]`)
	}

	var interactionID uuid.UUID
	var token string
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.interactions (
			application_id, type, guild_id, channel_id, user_id, data, interaction_kind, component_payload, attachment_payload, source_message_id
		)
		VALUES ($1, 3, $2, $3, $4, $5::jsonb, 'component', $6::jsonb, $7::jsonb, $8)
		RETURNING id, token
	`, appID, guildID, channelID, userUUID, req.Data, req.Component, req.Attachments, sourceMessageID).Scan(&interactionID, &token); err != nil {
		h.logger.Error("failed to create component interaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create interaction")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":               interactionID.String(),
		"token":            token,
		"type":             3,
		"interaction_kind": "component",
		"user_id":          userUUID.String(),
		"guild_id":         uuidOrNil(guildID),
		"channel_id":       uuidOrNil(channelID),
	})
}

func (h *InteractionsHandler) CreateModalInteraction(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := createModalInteractionRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	appID, guildID, channelID, _, ok := parseInteractionIDs(
		req.ApplicationID, req.GuildID, req.ChannelID, "", w,
	)
	if !ok {
		return
	}

	if len(req.Data) == 0 {
		req.Data = json.RawMessage(`{}`)
	}
	if len(req.Modal) == 0 {
		req.Modal = json.RawMessage(`{}`)
	}
	if len(req.Attachments) == 0 {
		req.Attachments = json.RawMessage(`[]`)
	}

	var interactionID uuid.UUID
	var token string
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.interactions (
			application_id, type, guild_id, channel_id, user_id, data, interaction_kind, modal_payload, attachment_payload
		)
		VALUES ($1, 5, $2, $3, $4, $5::jsonb, 'modal', $6::jsonb, $7::jsonb)
		RETURNING id, token
	`, appID, guildID, channelID, userUUID, req.Data, req.Modal, req.Attachments).Scan(&interactionID, &token); err != nil {
		h.logger.Error("failed to create modal interaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create interaction")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":               interactionID.String(),
		"token":            token,
		"type":             5,
		"interaction_kind": "modal",
		"user_id":          userUUID.String(),
		"guild_id":         uuidOrNil(guildID),
		"channel_id":       uuidOrNil(channelID),
	})
}

func parseInteractionIDs(appID, guildID, channelID, messageID string, w http.ResponseWriter) (uuid.UUID, *uuid.UUID, *uuid.UUID, *uuid.UUID, bool) {
	applicationUUID := defaultApplicationID
	if appID != "" {
		parsedAppID, err := uuid.Parse(appID)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid application id")
			return uuid.Nil, nil, nil, nil, false
		}
		applicationUUID = parsedAppID
	}

	guildUUID, ok := parseOptionalUUID(guildID, "invalid guild id", w)
	if !ok {
		return uuid.Nil, nil, nil, nil, false
	}
	channelUUID, ok := parseOptionalUUID(channelID, "invalid channel id", w)
	if !ok {
		return uuid.Nil, nil, nil, nil, false
	}
	messageUUID, ok := parseOptionalUUID(messageID, "invalid source message id", w)
	if !ok {
		return uuid.Nil, nil, nil, nil, false
	}
	return applicationUUID, guildUUID, channelUUID, messageUUID, true
}

func parseOptionalUUID(id string, errMsg string, w http.ResponseWriter) (*uuid.UUID, bool) {
	if id == "" {
		return nil, true
	}
	parsed, err := uuid.Parse(id)
	if err != nil {
		writeError(w, http.StatusBadRequest, errMsg)
		return nil, false
	}
	return &parsed, true
}

func uuidOrNil(value *uuid.UUID) interface{} {
	if value == nil {
		return nil
	}
	return value.String()
}
