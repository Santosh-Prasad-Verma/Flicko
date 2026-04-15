// CRIT-003: Authorization Middleware
// This middleware enforces permission checks for protected resources.
// It validates that the authenticated user has the required permission
// to perform actions on the specified resource.
package middleware

import (
	"os"

	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

const (
	// DefaultQueryTimeout is the timeout for permission check queries
	DefaultQueryTimeout = 30 * time.Second
)

// PermissionType represents an action a user can perform on a resource
type PermissionType string

const (
	// Channel permissions
	PermViewChannel   PermissionType = "VIEW_CHANNEL"
	PermManageChannel PermissionType = "MANAGE_CHANNEL"
	PermDeleteChannel PermissionType = "DELETE_CHANNEL"

	// Server permissions
	PermViewServer    PermissionType = "VIEW_SERVER"
	PermManageServer  PermissionType = "MANAGE_SERVER"
	PermDeleteServer  PermissionType = "DELETE_SERVER"
	PermManageMembers PermissionType = "MANAGE_MEMBERS"
	PermManageRoles   PermissionType = "MANAGE_ROLES"

	// Message permissions
	PermViewMessages   PermissionType = "VIEW_MESSAGES"
	PermPostMessages   PermissionType = "POST_MESSAGES"
	PermDeleteMessages PermissionType = "DELETE_MESSAGES"
	PermEditMessages   PermissionType = "EDIT_MESSAGES"

	// Moderation permissions
	PermBanMembers  PermissionType = "BAN_MEMBERS"
	PermMuteMembers PermissionType = "MUTE_MEMBERS"
	PermModerate    PermissionType = "MODERATE"

	// Bot/Command permissions
	PermExecuteCommands PermissionType = "EXECUTE_COMMANDS"
	PermManageBots      PermissionType = "MANAGE_BOTS"

	// Stream/Video permissions
	PermStreamVideo PermissionType = "STREAM_VIDEO"
	PermViewStreams PermissionType = "VIEW_STREAMS"
)

// PermissionService defines the interface for checking permissions
type PermissionService interface {
	HasPermission(ctx context.Context, userID uuid.UUID, resourceID uuid.UUID, permission PermissionType) (bool, error)
	HasServerPermission(ctx context.Context, userID uuid.UUID, serverID uuid.UUID, permission PermissionType) (bool, error)
	HasChannelPermission(ctx context.Context, userID uuid.UUID, channelID uuid.UUID, permission PermissionType) (bool, error)
	IsServerOwner(ctx context.Context, userID uuid.UUID, serverID uuid.UUID) (bool, error)
	IsChannelOwner(ctx context.Context, userID uuid.UUID, channelID uuid.UUID) (bool, error)
}

// RequirePermission creates middleware that enforces a permission check
// resourceIDKey: the URL query parameter or path variable containing the resource ID
// permission: the required permission for this action
func RequirePermission(
	permService PermissionService,
	permission PermissionType,
	resourceIDKey string,
	logger *zap.Logger,
) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// 1. Get authenticated user
			userIDStr := GetUserIDFromContext(r)
			if userIDStr == "" {
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
				return
			}

			userID, err := uuid.Parse(userIDStr)
			if err != nil {
				logger.Warn("invalid user id in context",
					zap.String("user_id", userIDStr),
					zap.Error(err),
				)
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid user ID")
				return
			}

			// 2. Get resource ID from request
			resourceID := r.URL.Query().Get(resourceIDKey)
			if resourceID == "" {
				// Try path variable if query param not found
				resourceID = r.Header.Get(fmt.Sprintf("X-Resource-ID-%s", resourceIDKey))
			}

			if resourceID == "" {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", fmt.Sprintf("Missing %s parameter", resourceIDKey))
				return
			}

			resourceUUID, err := uuid.Parse(resourceID)
			if err != nil {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid resource ID format")
				return
			}

			// 3. Check permission
			ctx, cancel := context.WithTimeout(r.Context(), DefaultQueryTimeout)
			defer cancel()

			hasPermission, err := permService.HasPermission(ctx, userID, resourceUUID, permission)
			if err != nil {
				logger.Error("permission check failed",
					zap.String("user_id", userID.String()),
					zap.String("resource_id", resourceID),
					zap.String("permission", string(permission)),
					zap.Error(err),
				)
				writeJSONError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Permission check failed")
				return
			}

			if !hasPermission {
				logger.Warn("permission denied",
					zap.String("user_id", userID.String()),
					zap.String("resource_id", resourceID),
					zap.String("permission", string(permission)),
				)
				writeJSONError(w, http.StatusForbidden, "FORBIDDEN", "Insufficient permissions for this action")
				return
			}

			// 4. Allow request
			next.ServeHTTP(w, r)
		})
	}
}

// RequireServerPermission creates middleware for server-level permissions
func RequireServerPermission(
	permService PermissionService,
	permission PermissionType,
	serverIDKey string,
	logger *zap.Logger,
) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Get user ID
			userIDStr := GetUserIDFromContext(r)
			if userIDStr == "" {
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
				return
			}

			userID, err := uuid.Parse(userIDStr)
			if err != nil {
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid user ID")
				return
			}

			// Get server ID
			serverID := r.URL.Query().Get(serverIDKey)
			if serverID == "" {
				serverID = r.Header.Get(fmt.Sprintf("X-Server-ID-%s", serverIDKey))
			}
			if serverID == "" {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", fmt.Sprintf("Missing %s parameter", serverIDKey))
				return
			}

			serverUUID, err := uuid.Parse(serverID)
			if err != nil {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid server ID format")
				return
			}

			// Check permission
			ctx, cancel := context.WithTimeout(r.Context(), DefaultQueryTimeout)
			defer cancel()

			hasPermission, err := permService.HasServerPermission(ctx, userID, serverUUID, permission)
			if err != nil {
				logger.Error("server permission check failed", zap.Error(err))
				writeJSONError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Permission check failed")
				return
			}

			if !hasPermission {
				logger.Warn("server permission denied",
					zap.String("user_id", userID.String()),
					zap.String("server_id", serverID),
					zap.String("permission", string(permission)),
				)
				writeJSONError(w, http.StatusForbidden, "FORBIDDEN", "Insufficient permissions for this action")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// RequireChannelPermission creates middleware for channel-level permissions
func RequireChannelPermission(
	permService PermissionService,
	permission PermissionType,
	channelIDKey string,
	logger *zap.Logger,
) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Get user ID
			userIDStr := GetUserIDFromContext(r)
			if userIDStr == "" {
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
				return
			}

			userID, err := uuid.Parse(userIDStr)
			if err != nil {
				writeJSONError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid user ID")
				return
			}

			// Get channel ID
			channelID := r.URL.Query().Get(channelIDKey)
			if channelID == "" {
				channelID = r.Header.Get(fmt.Sprintf("X-Channel-ID-%s", channelIDKey))
			}
			if channelID == "" {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", fmt.Sprintf("Missing %s parameter", channelIDKey))
				return
			}

			channelUUID, err := uuid.Parse(channelID)
			if err != nil {
				writeJSONError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid channel ID format")
				return
			}

			// Check permission
			ctx, cancel := context.WithTimeout(r.Context(), DefaultQueryTimeout)
			defer cancel()

			hasPermission, err := permService.HasChannelPermission(ctx, userID, channelUUID, permission)
			if err != nil {
				logger.Error("channel permission check failed", zap.Error(err))
				writeJSONError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Permission check failed")
				return
			}

			if !hasPermission {
				logger.Warn("channel permission denied",
					zap.String("user_id", userID.String()),
					zap.String("channel_id", channelID),
					zap.String("permission", string(permission)),
				)
				writeJSONError(w, http.StatusForbidden, "FORBIDDEN", "Insufficient permissions for this action")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// GetUserIDFromContext extracts the authenticated user ID from request context
func GetUserIDFromContext(r *http.Request) string {
	if userID, ok := r.Context().Value(GetUserIDKey()).(string); ok {
		return userID
	}
	return ""
}

// InternalAuth protects internal delivery and monitoring routes.
// It requires an X-Internal-Token header that matches the INTERNAL_API_KEY env.
func InternalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Internal-Token")
		expected := os.Getenv("INTERNAL_API_KEY")
		if expected == "" {
			// Fail securely if no internal token is configured
			http.Error(w, `{"error": "Internal API access not configured"}`, http.StatusForbidden)
			return
		}
		if token != expected {
			http.Error(w, `{"error": "Unauthorized internal access"}`, http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
