package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type AppInstallHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type appInstallCallbackRequest struct {
	ServerID string   `json:"server_id"`
	Scopes   []string `json:"scopes"`
	State    string   `json:"state,omitempty"`
}

type updateInstallPermissionsRequest struct {
	Scopes []string `json:"scopes"`
}

func NewAppInstallHandler(db *pgxpool.Pool, logger *zap.Logger) *AppInstallHandler {
	return &AppInstallHandler{
		db:     db,
		logger: logger.Named("handler.app_install"),
	}
}

func (h *AppInstallHandler) AuthorizeApp(w http.ResponseWriter, r *http.Request) {
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

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid app id")
		return
	}

	var name string
	var description *string
	var iconURL *string
	var isPublic bool
	var ownerID uuid.UUID
	err = h.db.QueryRow(r.Context(), `
		SELECT name, description, icon_url, is_public, owner_id
		FROM public.applications
		WHERE id = $1
		  AND is_active = TRUE
	`, appUUID).Scan(&name, &description, &iconURL, &isPublic, &ownerID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to query application for authorization", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to authorize application")
		return
	}
	if !isPublic && ownerID != userUUID {
		writeError(w, http.StatusForbidden, "application is not publicly installable")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT scope, COALESCE(description, ''), is_required
		FROM public.application_scopes
		WHERE app_id = $1
		ORDER BY is_required DESC, scope ASC
	`, appUUID)
	if err != nil {
		h.logger.Error("failed to list application scopes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to authorize application")
		return
	}
	defer rows.Close()

	scopes := make([]map[string]interface{}, 0)
	for rows.Next() {
		var scope, scopeDescription string
		var isRequired bool
		if err = rows.Scan(&scope, &scopeDescription, &isRequired); err != nil {
			h.logger.Error("failed to scan application scope", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to authorize application")
			return
		}
		scopes = append(scopes, map[string]interface{}{
			"scope":       scope,
			"description": scopeDescription,
			"is_required": isRequired,
		})
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("application scope iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to authorize application")
		return
	}

	state := uuid.NewString()
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"app_id":       appUUID.String(),
		"name":         name,
		"description":  description,
		"icon_url":     iconURL,
		"oauth_state":  state,
		"requested_by": userUUID.String(),
		"scopes":       scopes,
	})
}

func (h *AppInstallHandler) InstallCallback(w http.ResponseWriter, r *http.Request) {
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

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid app id")
		return
	}

	req := appInstallCallbackRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	serverUUID, err := uuid.Parse(req.ServerID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}
	for i := range req.Scopes {
		req.Scopes[i] = strings.TrimSpace(req.Scopes[i])
	}

	var isPublic bool
	var ownerID uuid.UUID
	err = h.db.QueryRow(r.Context(), `
		SELECT is_public, owner_id
		FROM public.applications
		WHERE id = $1
		  AND is_active = TRUE
	`, appUUID).Scan(&isPublic, &ownerID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to query application for install", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to install application")
		return
	}
	if !isPublic && ownerID != userUUID {
		writeError(w, http.StatusForbidden, "application is not publicly installable")
		return
	}

	var isServerMember bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.server_members
			WHERE server_id = $1
			  AND user_id = $2
		)
	`, serverUUID, userUUID).Scan(&isServerMember); err != nil {
		h.logger.Error("failed to verify server membership for app install", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to install application")
		return
	}
	if !isServerMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	allowedScopes := map[string]struct{}{}
	rows, err := h.db.Query(r.Context(), `
		SELECT scope
		FROM public.application_scopes
		WHERE app_id = $1
	`, appUUID)
	if err != nil {
		h.logger.Error("failed to load allowed application scopes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to install application")
		return
	}
	for rows.Next() {
		var scope string
		if err = rows.Scan(&scope); err != nil {
			rows.Close()
			h.logger.Error("failed to scan allowed scope", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to install application")
			return
		}
		allowedScopes[scope] = struct{}{}
	}
	rows.Close()
	for _, scope := range req.Scopes {
		if _, ok := allowedScopes[scope]; !ok {
			writeError(w, http.StatusBadRequest, "invalid requested scope")
			return
		}
	}

	var installID uuid.UUID
	var installedAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.application_installs (
			app_id, server_id, installed_by, status, granted_scopes, installed_at
		)
		VALUES ($1, $2, $3, 'active', $4, NOW())
		ON CONFLICT (app_id, server_id)
		DO UPDATE SET
			installed_by = EXCLUDED.installed_by,
			status = 'active',
			granted_scopes = EXCLUDED.granted_scopes,
			updated_at = NOW()
		RETURNING id, installed_at
	`, appUUID, serverUUID, userUUID, req.Scopes).Scan(&installID, &installedAt); err != nil {
		h.logger.Error("failed to upsert application install", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to install application")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"install_id":      installID.String(),
		"app_id":          appUUID.String(),
		"server_id":       serverUUID.String(),
		"installed_by":    userUUID.String(),
		"granted_scopes":  req.Scopes,
		"installed_at":    installedAt,
		"installation_ok": true,
	})
}

func (h *AppInstallHandler) UpdateInstallPermissions(w http.ResponseWriter, r *http.Request) {
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

	vars := mux.Vars(r)
	appUUID, err := uuid.Parse(vars["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid app id")
		return
	}
	installUUID, err := uuid.Parse(vars["installId"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid install id")
		return
	}

	req := updateInstallPermissionsRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	for i := range req.Scopes {
		req.Scopes[i] = strings.TrimSpace(req.Scopes[i])
	}

	var serverID uuid.UUID
	var installedBy uuid.UUID
	err = h.db.QueryRow(r.Context(), `
		SELECT server_id, installed_by
		FROM public.application_installs
		WHERE id = $1
		  AND app_id = $2
		  AND status = 'active'
	`, installUUID, appUUID).Scan(&serverID, &installedBy)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application install not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to load application install", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}
	if installedBy != userUUID {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}

	allowedScopes := map[string]struct{}{}
	rows, err := h.db.Query(r.Context(), `
		SELECT scope
		FROM public.application_scopes
		WHERE app_id = $1
	`, appUUID)
	if err != nil {
		h.logger.Error("failed to load allowed application scopes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}
	for rows.Next() {
		var scope string
		if err = rows.Scan(&scope); err != nil {
			rows.Close()
			h.logger.Error("failed to scan allowed scope", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to update install permissions")
			return
		}
		allowedScopes[scope] = struct{}{}
	}
	rows.Close()
	for _, scope := range req.Scopes {
		if _, ok := allowedScopes[scope]; !ok {
			writeError(w, http.StatusBadRequest, "invalid requested scope")
			return
		}
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin update permissions transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var updatedAt time.Time
	if err = tx.QueryRow(r.Context(), `
		UPDATE public.application_installs
		SET granted_scopes = $2,
		    updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at
	`, installUUID, req.Scopes).Scan(&updatedAt); err != nil {
		h.logger.Error("failed to update application install scopes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		DELETE FROM public.application_permissions
		WHERE install_id = $1
	`, installUUID); err != nil {
		h.logger.Error("failed to clear application permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}

	for _, scope := range req.Scopes {
		if _, err = tx.Exec(r.Context(), `
			INSERT INTO public.application_permissions (
				install_id, app_id, server_id, scope, allowed, created_by
			)
			VALUES ($1, $2, $3, $4, TRUE, $5)
		`, installUUID, appUUID, serverID, scope, userUUID); err != nil {
			h.logger.Error("failed to persist application permission scope", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to update install permissions")
			return
		}
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit update permissions transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update install permissions")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"install_id":      installUUID.String(),
		"app_id":          appUUID.String(),
		"server_id":       serverID.String(),
		"granted_scopes":  req.Scopes,
		"updated_at":      updatedAt,
		"permissions_set": len(req.Scopes),
	})
}
