package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
	"github.com/flicko-org/flicko/services/shared/errors"
)

// UploadHandler handles media upload presigned URL generation.
type UploadHandler struct {
	svc *service.MediaService
	log *zap.Logger
}

// NewUploadHandler creates an UploadHandler.
func NewUploadHandler(svc *service.MediaService, log *zap.Logger) *UploadHandler {
	return &UploadHandler{svc: svc, log: log}
}

// presignRequest is the JSON body for POST /v1/channels/{channelID}/upload/presign.
type presignRequest struct {
	FileName    string `json:"file_name"`
	ContentType string `json:"content_type"`
	FileSize    int64  `json:"file_size"`
}

// Presign handles POST /v1/channels/{channelID}/upload/presign.
func (h *UploadHandler) Presign(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())

	var body presignRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	if h.svc == nil {
		Error(w, h.log, errors.ErrInternal(nil)) // Or however it wraps an error
		return
	}

	resp, err := h.svc.GeneratePresignedURL(r.Context(), service.PresignRequest{
		ChannelID:   channelID,
		UserID:      userID,
		FileName:    body.FileName,
		ContentType: body.ContentType,
		FileSize:    body.FileSize,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusOK, resp)
}
