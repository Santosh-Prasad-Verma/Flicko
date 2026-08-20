package services

import (
	"context"
	"log"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type AttachmentCleanupService struct {
	db     *pgxpool.Pool
	ticker *time.Ticker
	quit   chan struct{}
}

func NewAttachmentCleanupService(db *pgxpool.Pool) *AttachmentCleanupService {
	return &AttachmentCleanupService{
		db:   db,
		quit: make(chan struct{}),
	}
}

func (s *AttachmentCleanupService) Start() {
	s.ticker = time.NewTicker(1 * time.Hour)
	go func() {
		for {
			select {
			case <-s.ticker.C:
				s.cleanupOrphanedAttachments(context.Background())
			case <-s.quit:
				s.ticker.Stop()
				return
			}
		}
	}()
}

func (s *AttachmentCleanupService) Stop() {
	close(s.quit)
}

func (s *AttachmentCleanupService) cleanupOrphanedAttachments(ctx context.Context) {
	query := `
		SELECT a.id, a.url 
		FROM public.attachments a
		JOIN public.messages m ON a.message_id = m.id
		WHERE m.deleted_at < NOW() - INTERVAL '24 hours'
		LIMIT 100
	`

	rows, err := s.db.Query(ctx, query)
	if err != nil {
		log.Printf("[Cleanup] Failed to query orphaned attachments: %v", err)
		return
	}
	defer rows.Close()

	type Orphaned struct {
		ID  string
		URL string
	}

	var orphans []Orphaned
	for rows.Next() {
		var o Orphaned
		if err := rows.Scan(&o.ID, &o.URL); err != nil {
			log.Printf("[Cleanup] Failed to scan orphaned attachment: %v", err)
			continue
		}
		orphans = append(orphans, o)
	}

	for _, orphan := range orphans {
		_, err = s.db.Exec(ctx, "DELETE FROM public.attachments WHERE id = $1", orphan.ID)
		if err != nil {
			log.Printf("[Cleanup] Failed to delete attachment record %s: %v", orphan.ID, err)
		}
	}
}

func ExtractFilePathFromURL(url string) string {
	prefix := "/attachments/"
	idx := strings.Index(url, prefix)
	if idx == -1 {
		return ""
	}
	return url[idx+len(prefix):]
}
