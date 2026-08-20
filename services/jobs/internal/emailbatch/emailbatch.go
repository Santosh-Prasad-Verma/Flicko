// Package emailbatch sends batched promotional emails.
//
// It queries the database for pending email campaigns, renders HTML
// templates, and sends via SMTP in batches with rate limiting.
package emailbatch

import (
	"context"
	"fmt"
	"net/smtp"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/jobs/internal/shared"
)

// Run executes the email batch job.
func Run(ctx context.Context, deps *shared.Deps, log *zap.Logger) error {
	log = log.Named("email-batch")
	log.Info("starting email batch job")

	// ── Fetch pending campaigns ─────────────────────────────
	rows, err := deps.DB.Query(ctx, `
		SELECT id, subject, html_body, recipient_list
		FROM promo_campaigns
		WHERE status = 'pending'
		  AND scheduled_at <= NOW()
		ORDER BY scheduled_at ASC
		LIMIT 10
	`)
	if err != nil {
		return fmt.Errorf("query campaigns: %w", err)
	}
	defer rows.Close()

	type campaign struct {
		ID         string
		Subject    string
		HTMLBody   string
		Recipients []string
	}

	var campaigns []campaign
	for rows.Next() {
		var c campaign
		var recipientList string
		if err := rows.Scan(&c.ID, &c.Subject, &c.HTMLBody, &recipientList); err != nil {
			return fmt.Errorf("scan campaign: %w", err)
		}
		c.Recipients = strings.Split(recipientList, ",")
		campaigns = append(campaigns, c)
	}

	if len(campaigns) == 0 {
		log.Info("no pending campaigns")
		return nil
	}

	log.Info("found campaigns to send", zap.Int("count", len(campaigns)))

	// ── SMTP auth ───────────────────────────────────────────
	auth := smtp.PlainAuth("", deps.SMTPUser, deps.SMTPPassword, deps.SMTPHost)
	addr := fmt.Sprintf("%s:%s", deps.SMTPHost, deps.SMTPPort)

	// ── Send each campaign ──────────────────────────────────
	for _, c := range campaigns {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		log.Info("sending campaign",
			zap.String("campaign_id", c.ID),
			zap.Int("recipients", len(c.Recipients)),
		)

		// Mark as in-progress.
		_, err := deps.DB.Exec(ctx,
			`UPDATE promo_campaigns SET status = 'sending', started_at = NOW() WHERE id = $1`,
			c.ID,
		)
		if err != nil {
			log.Error("mark sending", zap.Error(err))
		}

		var sent, failed int
		for i, to := range c.Recipients {
			to = strings.TrimSpace(to)
			if to == "" {
				continue
			}

			msg := fmt.Sprintf(
				"From: Flicko <%s>\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s",
				deps.SMTPFrom, to, c.Subject, c.HTMLBody,
			)

			if err := smtp.SendMail(addr, auth, deps.SMTPFrom, []string{to}, []byte(msg)); err != nil {
				log.Warn("send failed", zap.String("to", to), zap.Error(err))
				failed++
			} else {
				sent++
			}

			// Rate limit: 3 emails/second (Brevo limit).
			if i%3 == 2 {
				time.Sleep(1 * time.Second)
			}
		}

		// Mark as completed.
		status := "completed"
		if failed > 0 && sent == 0 {
			status = "failed"
		} else if failed > 0 {
			status = "partial"
		}

		_, err = deps.DB.Exec(ctx,
			`UPDATE promo_campaigns SET status = $1, completed_at = NOW(), sent_count = $2, failed_count = $3 WHERE id = $4`,
			status, sent, failed, c.ID,
		)
		if err != nil {
			log.Error("mark completed", zap.Error(err))
		}

		log.Info("campaign sent",
			zap.String("campaign_id", c.ID),
			zap.String("status", status),
			zap.Int("sent", sent),
			zap.Int("failed", failed),
		)
	}

	return nil
}
