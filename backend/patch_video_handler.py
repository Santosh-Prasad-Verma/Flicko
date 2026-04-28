import re

with open("backend/internal/handlers/video_handler.go", "r") as f:
    content = f.read()

content = content.replace("streamSvc services.StreamService\n\tvoiceSvc  services.VoiceService\n\tpermSvc   services.PermissionService\n\tlogger    *zap.Logger", "streamSvc   services.StreamService\n\tvoiceSvc    services.VoiceService\n\tpermSvc     services.PermissionService\n\tliveKitSvc  services.LiveKitService\n\tlogger      *zap.Logger")

content = content.replace("streamSvc services.StreamService\n        voiceSvc  services.VoiceService\n        permSvc   services.PermissionService\n        logger    *zap.Logger", "streamSvc   services.StreamService\n\tvoiceSvc    services.VoiceService\n\tpermSvc     services.PermissionService\n\tliveKitSvc  services.LiveKitService\n\tlogger      *zap.Logger")

content = content.replace(
    "func NewVideoHandler(streamSvc services.StreamService, voiceSvc services.VoiceService, permSvc services.PermissionService, logger *\nzap.Logger) *VideoHandler {",
    "func NewVideoHandler(streamSvc services.StreamService, voiceSvc services.VoiceService, permSvc services.PermissionService, liveKitSvc services.LiveKitService, logger *zap.Logger) *VideoHandler {"
)

content = content.replace(
    "func NewVideoHandler(streamSvc services.StreamService, voiceSvc services.VoiceService, permSvc services.PermissionService, logger *zap.Logger) *VideoHandler {",
    "func NewVideoHandler(streamSvc services.StreamService, voiceSvc services.VoiceService, permSvc services.PermissionService, liveKitSvc services.LiveKitService, logger *zap.Logger) *VideoHandler {"
)

content = content.replace(
    "streamSvc: streamSvc,\n\t\tvoiceSvc:  voiceSvc,\n\t\tpermSvc:   permSvc,\n\t\tlogger:    logger,",
    "streamSvc: streamSvc,\n\t\tvoiceSvc:  voiceSvc,\n\t\tpermSvc:   permSvc,\n\t\tliveKitSvc: liveKitSvc,\n\t\tlogger:    logger,"
)
content = content.replace(
    "streamSvc: streamSvc,\n                voiceSvc:  voiceSvc,\n                permSvc:   permSvc,\n                logger:    logger,",
    "streamSvc: streamSvc,\n\t\tvoiceSvc:  voiceSvc,\n\t\tpermSvc:   permSvc,\n\t\tliveKitSvc: liveKitSvc,\n\t\tlogger:    logger,"
)


content = content.replace(
    "func (h *VideoHandler) RegisterRoutes(r *mux.Router) {\n\t// Stream (Go Live) endpoints",
    "func (h *VideoHandler) RegisterRoutes(r *mux.Router) {\n\tr.HandleFunc(\"/api/v1/voice/token\", h.GenerateLiveKitToken).Methods(\"GET\")\n\n\t// Stream (Go Live) endpoints"
)

content = content.replace(
    "func (h *VideoHandler) RegisterRoutes(r *mux.Router) {\n        // Stream (Go Live) endpoints",
    "func (h *VideoHandler) RegisterRoutes(r *mux.Router) {\n\tr.HandleFunc(\"/api/v1/voice/token\", h.GenerateLiveKitToken).Methods(\"GET\")\n\n\t// Stream (Go Live) endpoints"
)


content += """
// ── LiveKit JWT Token ──

func (h *VideoHandler) GenerateLiveKitToken(w http.ResponseWriter, r *http.Request) {
userID := getVideoUserID(r)
if userID == "" {
writeError(w, http.StatusUnauthorized, "unauthorized")
return
}

channelID := r.URL.Query().Get("channel_id")
if channelID == "" {
writeError(w, http.StatusBadRequest, "channel_id is required")
return
}

// Default flags
canPublish := true
canPublishData := true

// In a real scenario, you could verify user permissions to establish whether they can speak/publish video
// For example:
// hasPerm, _ := h.permSvc.HasPermission(r.Context(), userID, channelID, "SPEAK")
// canPublish = hasPerm

token, err := h.liveKitSvc.GenerateToken(channelID, userID, userID, canPublish, canPublishData)
if err != nil {
h.logger.Error("failed to generate livekit token", zap.Error(err))
writeError(w, http.StatusInternalServerError, "failed to generate vc token")
return
}

w.Header().Set("Content-Type", "application/json")
json.NewEncoder(w).Encode(map[string]string{
"token": token,
})
}
"""

with open("backend/internal/handlers/video_handler.go", "w") as f:
    f.write(content)
