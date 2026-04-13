package services

import (
	"context"
	"log"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	storage_go "github.com/supabase-community/storage-go"
)

type AttachmentCleanupService struct {
	db      *pgxpool.Pool
	storage *storage_go.Client
	ticker  *time.Ticker
	quit    chan struct{}
}

func NewAttachmentCleanupService(db *pgxpool.Pool, storage *storage_go.Client) *AttachmentCleanupService {
	return &AttachmentCleanupService{
		db:      db,
		storage: storage,
		quit:    make(chan struct{}),
	}
}

func (s *AttachmentCleanupService) Start() {
	// Run cleanup every hour
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
	// Identify orphaned attachments: messages deleted > 24 hours ago
	// We'll delete them in batches
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

	if len(orphans) > 0 {
		log.Printf("[Cleanup] Found %d orphaned attachments to process", len(orphans))
	}

	for _, orphan := range orphans {
		// Check reference count for this exact URL
		var count int
		err := s.db.QueryRow(ctx, "SELECT count(*) FROM public.attachments WHERE url = $1", orphan.URL).Scan(&count)
		if err != nil {
			log.Printf("[Cleanup] Failed to check reference count for %s: %v", orphan.URL, err)
			continue
		}

		// If this is the only reference, delete from storage
		if count <= 1 {
			// Extract filepath from public URL
			// The URL format is: .../object/public/attachments/[filepath]
			// We need just the filepath to pass to RemoveFile
			// Typical: https://xyz.supabase.co/storage/v1/object/public/attachments/user_id/hash_filename.ext
			// We can leverage string parsing or stored file paths if we added it to schema.
			// Ideally, we store filepath, but since we only have URL, let's extract it.
			filepath := extractFilePathFromURL(orphan.URL)
			if filepath != "" {
				_, err := s.storage.RemoveFile("attachments", []string{filepath})
				if err != nil {
					log.Printf("[Cleanup] Failed to remove file from storage %s: %v", filepath, err)
					// If it fails, we shouldn't delete the attachment record so we can retry later.
					continue
				}
				log.Printf("[Cleanup] Removed file from storage: %s", filepath)
			}
		}

		// Delete attachment record (this clears it regardless of whether other references exist)
		_, err = s.db.Exec(ctx, "DELETE FROM public.attachments WHERE id = $1", orphan.ID)
		if err != nil {
			log.Printf("[Cleanup] Failed to delete attachment record %s: %v", orphan.ID, err)
		} else {
			log.Printf("[Audit] Deleted orphaned attachment record %s", orphan.ID)
		}
	}
}

// extractFilePathFromURL is a helper to get the relative path from the full public URL
func extractFilePathFromURL(url string) string {
	// example: https://domain/storage/v1/object/public/attachments/user1/123_abc.png
	// prefix to look for: "/object/public/attachments/"
	prefix := "/object/public/attachments/"
	idx := strings.Index(url, prefix)
	if idx == -1 {
		log.Printf("[Cleanup] Warning: Could not find attachments prefix in URL: %s", url)
		return ""
	}
	pathStart := idx + len(prefix)
	if pathStart >= len(url) {
		return ""
	}
	return url[pathStart:]
}
