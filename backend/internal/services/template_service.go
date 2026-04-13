package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TemplateService interface {
	CreateTemplate(ctx context.Context, serverID, creatorID, name string, description *string) (*models.ServerTemplate, error)
	GetTemplate(ctx context.Context, code string) (*models.ServerTemplate, error)
	UseTemplate(ctx context.Context, code, creatorID, newServerName string) (*models.Server, error)
}

type templateService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewTemplateService(db *pgxpool.Pool, permService PermissionService) TemplateService {
	return &templateService{
		db:          db,
		permService: permService,
	}
}

type TemplateRole struct {
	OriginalID  string `json:"original_id"`
	Name        string `json:"name"`
	Color       string `json:"color"`
	Permissions int64  `json:"permissions"`
}

type TemplateChannel struct {
	OriginalID string             `json:"original_id"`
	Name       string             `json:"name"`
	Type       models.ChannelType `json:"type"`
	Topic      string             `json:"topic"`
	ParentID   *string            `json:"parent_id"` // Matches an OriginalID of a category
}

type TemplateData struct {
	Roles    []TemplateRole    `json:"roles"`
	Channels []TemplateChannel `json:"channels"`
}

func generateTemplateCode() string {
	b := make([]byte, 6)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)[:8]
}

func (s *templateService) CreateTemplate(ctx context.Context, serverID, creatorID, name string, description *string) (*models.ServerTemplate, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	creatorUUID, err2 := uuid.Parse(creatorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, creatorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD")
	}

	// 1. Fetch roles
	rolesRows, err := s.db.Query(ctx, "SELECT id, name, color, permissions FROM public.roles WHERE server_id = $1", serverUUID)
	if err != nil {
		return nil, err
	}
	defer rolesRows.Close()

	var roles []TemplateRole
	for rolesRows.Next() {
		var r TemplateRole
		var roleID uuid.UUID
		if err := rolesRows.Scan(&roleID, &r.Name, &r.Color, &r.Permissions); err != nil {
			return nil, err
		}
		r.OriginalID = roleID.String()
		roles = append(roles, r)
	}

	// 2. Fetch channels
	channelsRows, err := s.db.Query(ctx, "SELECT id, name, type, topic, parent_id FROM public.channels WHERE server_id = $1", serverUUID)
	if err != nil {
		return nil, err
	}
	defer channelsRows.Close()

	var channels []TemplateChannel
	for channelsRows.Next() {
		var c TemplateChannel
		var chanID uuid.UUID
		var parentID *uuid.UUID
		if err := channelsRows.Scan(&chanID, &c.Name, &c.Type, &c.Topic, &parentID); err != nil {
			return nil, err
		}
		c.OriginalID = chanID.String()
		if parentID != nil {
			p := parentID.String()
			c.ParentID = &p
		}
		channels = append(channels, c)
	}

	data := TemplateData{Roles: roles, Channels: channels}
	dataJSON, err := json.Marshal(data)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize template data: %w", err)
	}

	code := generateTemplateCode()
	query := `
		INSERT INTO public.server_templates (code, source_server_id, creator_id, name, description, template_data)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING code, source_server_id, creator_id, name, description, usage_count, template_data, created_at, updated_at
	`

	var t models.ServerTemplate
	err = s.db.QueryRow(ctx, query, code, serverUUID, creatorUUID, name, description, dataJSON).
		Scan(&t.Code, &t.SourceServerID, &t.CreatorID, &t.Name, &t.Description, &t.UsageCount, &t.TemplateData, &t.CreatedAt, &t.UpdatedAt)

	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (s *templateService) GetTemplate(ctx context.Context, code string) (*models.ServerTemplate, error) {
	query := `
		SELECT code, source_server_id, creator_id, name, description, usage_count, template_data, created_at, updated_at
		FROM public.server_templates WHERE code = $1
	`
	var t models.ServerTemplate
	err := s.db.QueryRow(ctx, query, code).
		Scan(&t.Code, &t.SourceServerID, &t.CreatorID, &t.Name, &t.Description, &t.UsageCount, &t.TemplateData, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("template not found")
		}
		return nil, err
	}
	return &t, nil
}

func (s *templateService) UseTemplate(ctx context.Context, code, creatorID, newServerName string) (*models.Server, error) {
	creatorUUID, err := uuid.Parse(creatorID)
	if err != nil {
		return nil, fmt.Errorf("invalid creator uuid")
	}

	t, err := s.GetTemplate(ctx, code)
	if err != nil {
		return nil, err
	}

	// Read data
	var data TemplateData
	// t.TemplateData is unmarshalled as map[string]interface{} generically by pgx if JSONB,
	// or as string/[]byte depending on driver. Let's re-marshal to parse cleanly.
	rawBytes, _ := json.Marshal(t.TemplateData)
	if err := json.Unmarshal(rawBytes, &data); err != nil {
		return nil, fmt.Errorf("corrupt template data: %w", err)
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	newServerID := uuid.New()

	// Create Server
	_, err = tx.Exec(ctx, "INSERT INTO public.servers (id, name, owner_id) VALUES ($1, $2, $3)", newServerID, newServerName, creatorUUID)
	if err != nil {
		return nil, err
	}

	// Create Member
	_, err = tx.Exec(ctx, "INSERT INTO public.server_members (server_id, user_id) VALUES ($1, $2)", newServerID, creatorUUID)
	if err != nil {
		return nil, err
	}

	// Recreate Roles
	roleIDMap := make(map[string]uuid.UUID)
	for i, r := range data.Roles {
		newRoleID := uuid.New()
		roleIDMap[r.OriginalID] = newRoleID

		// If it's the default @everyone role (usually the lowest position with same name as server but let's assume standard sync)
		// We'll just insert as mapped
		_, err = tx.Exec(ctx, "INSERT INTO public.roles (id, server_id, name, color, position, permissions) VALUES ($1, $2, $3, $4, $5, $6)",
			newRoleID, newServerID, r.Name, r.Color, i, r.Permissions)
		if err != nil {
			return nil, err
		}
	}

	// Recreate Channels
	chanIDMap := make(map[string]uuid.UUID)
	// We do 2 passes to handle categories first
	for i, c := range data.Channels {
		if c.Type == models.ChannelTypeCategory {
			newChanID := uuid.New()
			chanIDMap[c.OriginalID] = newChanID
			_, err = tx.Exec(ctx, "INSERT INTO public.channels (id, server_id, name, type, topic, position) VALUES ($1, $2, $3, $4, $5, $6)",
				newChanID, newServerID, c.Name, c.Type, c.Topic, i)
			if err != nil {
				return nil, err
			}
		}
	}
	for i, c := range data.Channels {
		if c.Type != models.ChannelTypeCategory {
			newChanID := uuid.New()
			chanIDMap[c.OriginalID] = newChanID
			var parentID *uuid.UUID
			if c.ParentID != nil {
				if mapped, ok := chanIDMap[*c.ParentID]; ok {
					parentID = &mapped
				}
			}
			_, err = tx.Exec(ctx, "INSERT INTO public.channels (id, server_id, name, type, topic, position, parent_id) VALUES ($1, $2, $3, $4, $5, $6, $7)",
				newChanID, newServerID, c.Name, c.Type, c.Topic, i, parentID)
			if err != nil {
				return nil, err
			}
		}
	}

	// Update Template Usage
	_, err = tx.Exec(ctx, "UPDATE public.server_templates SET usage_count = usage_count + 1 WHERE code = $1", code)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	// Return limited Server model
	return &models.Server{
		ID:      newServerID.String(),
		Name:    newServerName,
		OwnerID: creatorID,
	}, nil
}
