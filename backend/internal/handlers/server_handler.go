package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

// ServerHandler handles server and channel HTTP endpoints.
type ServerHandler struct {
	serverSvc  services.ServerService
	channelSvc services.ChannelService
	logger     *zap.Logger
}

// NewServerHandler creates a new ServerHandler.
func NewServerHandler(serverSvc services.ServerService, channelSvc services.ChannelService, logger *zap.Logger) *ServerHandler {
	return &ServerHandler{
		serverSvc:  serverSvc,
		channelSvc: channelSvc,
		logger:     logger,
	}
}

// GetMyServers returns all servers that the authenticated user is a member of.
func (h *ServerHandler) GetMyServers(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	servers, err := h.serverSvc.GetUserServers(r.Context(), userID)
	if err != nil {
		h.logger.Error("failed to get user servers", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to load servers")
		return
	}

	writeJSON(w, http.StatusOK, servers)
}

// GetServer returns details for a specific server.
func (h *ServerHandler) GetServer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["id"]
	if serverID == "" {
		writeError(w, http.StatusBadRequest, "Server ID is required")
		return
	}

	server, err := h.serverSvc.GetServer(r.Context(), serverID)
	if err != nil {
		h.logger.Warn("failed to get server", zap.String("server_id", serverID), zap.Error(err))
		writeError(w, http.StatusNotFound, "Server not found")
		return
	}

	writeJSON(w, http.StatusOK, server)
}

type createServerRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
}

// CreateServer handles creating a new server.
func (h *ServerHandler) CreateServer(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req createServerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if len(req.Name) < 2 || len(req.Name) > 100 {
		writeError(w, http.StatusBadRequest, "Server name must be between 2 and 100 characters")
		return
	}

	server, err := h.serverSvc.CreateServer(r.Context(), userID, req.Name, req.Description, req.Icon)
	if err != nil {
		h.logger.Error("failed to create server", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to create server")
		return
	}

	writeJSON(w, http.StatusCreated, server)
}

// GetServerChannels returns the channels for a server if the user is a member.
func (h *ServerHandler) GetServerChannels(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	serverID := vars["id"]
	if serverID == "" {
		writeError(w, http.StatusBadRequest, "Server ID is required")
		return
	}

	isMember, err := h.serverSvc.IsMember(r.Context(), serverID, userID)
	if err != nil {
		h.logger.Error("failed to check server membership", zap.String("server_id", serverID), zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to verify access")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "Forbidden: you are not a member of this server")
		return
	}

	channels, err := h.channelSvc.GetServerChannels(r.Context(), serverID)
	if err != nil {
		h.logger.Error("failed to get server channels", zap.String("server_id", serverID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to load channels")
		return
	}

	writeJSON(w, http.StatusOK, channels)
}

// GetServerMembers returns the members for a server if the user is a member.
func (h *ServerHandler) GetServerMembers(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	serverID := vars["id"]
	if serverID == "" {
		writeError(w, http.StatusBadRequest, "Server ID is required")
		return
	}

	isMember, err := h.serverSvc.IsMember(r.Context(), serverID, userID)
	if err != nil {
		h.logger.Error("failed to check server membership", zap.String("server_id", serverID), zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to verify access")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "Forbidden: you are not a member of this server")
		return
	}

	members, err := h.serverSvc.GetServerMembers(r.Context(), serverID)
	if err != nil {
		h.logger.Error("failed to get server members", zap.String("server_id", serverID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to load members")
		return
	}

	writeJSON(w, http.StatusOK, members)
}

// JoinServer handles a user joining a server.
func (h *ServerHandler) JoinServer(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	serverID := vars["id"]
	inviteCode := r.URL.Query().Get("code")

	member, err := h.serverSvc.JoinServer(r.Context(), userID, inviteCode)
	if err != nil {
		h.logger.Warn("failed to join server", zap.String("server_id", serverID), zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, member)
}
