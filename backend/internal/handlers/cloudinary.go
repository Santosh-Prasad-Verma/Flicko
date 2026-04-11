package handlers

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"go.uber.org/zap"
)

// CloudinaryHandler generates signed upload parameters so the mobile client
// can upload directly to Cloudinary without exposing the API secret.
type CloudinaryHandler struct {
	cloudName string
	apiKey    string
	apiSecret string
	preset    string
	logger    *zap.Logger
}

// Allowed upload folders — prevents arbitrary folder access
var allowedFolders = map[string]bool{
	"flicko":                      true,
	"avatars":                     true,
	"attachments":                 true,
	"server-icons":                true,
	"banners":                     true,
	"emojis":                      true,
	"stickers":                    true,
	"flickochat":                  true,
	"flickochat/avatars":          true,
	"flickochat/banners":          true,
	"flickochat/server-icons":     true,
	"flickochat/server-banners":   true,
	"flickochat/chat":             true,
	"flickochat/stickers":         true,
}

// NewCloudinaryHandler creates a CloudinaryHandler with the given credentials.
func NewCloudinaryHandler(cloudName, apiKey, apiSecret, preset string, logger *zap.Logger) *CloudinaryHandler {
	return &CloudinaryHandler{
		cloudName: cloudName,
		apiKey:    apiKey,
		apiSecret: apiSecret,
		preset:    preset,
		logger:    logger,
	}
}

// Sign handles GET /api/v1/cloudinary/sign
//
// Query params (all optional):
//   - folder        – Cloudinary folder (default: "flicko")
//   - public_id     – deterministic public ID for overwrite
//   - resource_type – "image", "video", "raw" (default: "auto")
//   - colors        – "true" to request Cloudinary color analysis
//
// Returns JSON with: timestamp, signature, apiKey, cloudName, folder, publicId, colors
func (h *CloudinaryHandler) Sign(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	folder := r.URL.Query().Get("folder")
	if folder == "" {
		folder = "flickochat"
	}

	// Security: Validate folder against allowlist to prevent arbitrary folder access
	if !allowedFolders[folder] {
		h.logger.Warn("invalid folder requested",
			zap.String("user_id", userID),
			zap.String("folder", folder),
		)
		writeError(w, http.StatusBadRequest, "invalid folder: must be an allowed Cloudinary folder path")
		return
	}

	publicID := r.URL.Query().Get("public_id")
	colors := r.URL.Query().Get("colors") == "true"

	timestamp := time.Now().Unix()

	// Build the parameter string to sign (sorted alphabetically by key).
	// IMPORTANT: Every parameter the client sends in the upload form
	// (except file, api_key, signature, resource_type, cloud_name)
	// MUST be included here, otherwise Cloudinary rejects the signature.
	params := map[string]string{
		"folder":        folder,
		"timestamp":     strconv.FormatInt(timestamp, 10),
		"upload_preset": h.preset,
		"invalidate":    "true",
		"overwrite":     "true",
	}
	if publicID != "" {
		params["public_id"] = publicID
	}
	if colors {
		params["colors"] = "true"
	}

	signature := h.generateSignature(params)

	resp := map[string]interface{}{
		"timestamp":    timestamp,
		"signature":    signature,
		"apiKey":       h.apiKey,
		"cloudName":    h.cloudName,
		"uploadPreset": h.preset,
		"folder":       folder,
	}
	if publicID != "" {
		resp["publicId"] = publicID
	}
	if colors {
		resp["colors"] = true
	}

	h.logger.Debug("cloudinary sign request",
		zap.String("user_id", userID),
		zap.String("folder", folder),
		zap.String("public_id", publicID),
		zap.Bool("colors", colors),
	)

	writeJSON(w, http.StatusOK, resp)
}

// generateSignature creates the Cloudinary upload signature.
// Cloudinary expects: SHA-1 of "key1=val1&key2=val2&...{api_secret}" (sorted by key).
func (h *CloudinaryHandler) generateSignature(params map[string]string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	pairs := make([]string, 0, len(keys))
	for _, k := range keys {
		pairs = append(pairs, fmt.Sprintf("%s=%s", k, params[k]))
	}

	toSign := strings.Join(pairs, "&") + h.apiSecret
	hash := sha1.Sum([]byte(toSign))
	return hex.EncodeToString(hash[:])
}
