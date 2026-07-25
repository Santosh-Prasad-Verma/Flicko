package repo

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/flicko-org/flicko-backend/internal/models"
)

type ChannelDocumentRepo interface {
	CreateDocument(ctx context.Context, doc *models.ChannelDocument) error
	GetDocumentByID(ctx context.Context, id string) (*models.ChannelDocument, error)
	GetChannelDocuments(ctx context.Context, channelID string) ([]*models.ChannelDocument, error)
	UpdateDocumentState(ctx context.Context, id string, ydocBinary []byte, stateVector []byte) error
	DeleteDocument(ctx context.Context, id string) error
}

type pgChannelDocumentRepo struct {
	pool *pgxpool.Pool
}

func NewChannelDocumentRepo(pool *pgxpool.Pool) ChannelDocumentRepo {
	return &pgChannelDocumentRepo{pool: pool}
}

func (r *pgChannelDocumentRepo) CreateDocument(ctx context.Context, doc *models.ChannelDocument) error {
	query := `
		INSERT INTO public.channel_documents (channel_id, title, ydoc_binary, created_by)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query, doc.ChannelID, doc.Title, doc.YDocBinary, doc.CreatedBy).
		Scan(&doc.ID, &doc.CreatedAt, &doc.UpdatedAt)
}

func (r *pgChannelDocumentRepo) GetDocumentByID(ctx context.Context, id string) (*models.ChannelDocument, error) {
	query := `
		SELECT id, channel_id, title, state_vector, ydoc_binary, created_by, created_at, updated_at
		FROM public.channel_documents
		WHERE id = $1
	`
	doc := &models.ChannelDocument{}
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&doc.ID, &doc.ChannelID, &doc.Title, &doc.StateVector, &doc.YDocBinary,
		&doc.CreatedBy, &doc.CreatedAt, &doc.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get document error: %w", err)
	}
	return doc, nil
}

func (r *pgChannelDocumentRepo) GetChannelDocuments(ctx context.Context, channelID string) ([]*models.ChannelDocument, error) {
	query := `
		SELECT id, channel_id, title, created_by, created_at, updated_at
		FROM public.channel_documents
		WHERE channel_id = $1
		ORDER BY updated_at DESC
	`
	rows, err := r.pool.Query(ctx, query, channelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var docs []*models.ChannelDocument
	for rows.Next() {
		doc := &models.ChannelDocument{}
		if err := rows.Scan(&doc.ID, &doc.ChannelID, &doc.Title, &doc.CreatedBy, &doc.CreatedAt, &doc.UpdatedAt); err != nil {
			return nil, err
		}
		docs = append(docs, doc)
	}
	return docs, nil
}

func (r *pgChannelDocumentRepo) UpdateDocumentState(ctx context.Context, id string, ydocBinary []byte, stateVector []byte) error {
	query := `
		UPDATE public.channel_documents
		SET ydoc_binary = $2, state_vector = $3, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.pool.Exec(ctx, query, id, ydocBinary, stateVector)
	return err
}

func (r *pgChannelDocumentRepo) DeleteDocument(ctx context.Context, id string) error {
	query := `DELETE FROM public.channel_documents WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}
