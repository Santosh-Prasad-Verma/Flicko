package message_summary

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/flicko-org/flicko-backend/internal/database"
)

// WindowMessage is a slim view of a message used to build the LLM prompt.
type WindowMessage struct {
	ID        string
	AuthorID  string
	Author    string // display name or username for prompt rendering
	Content   string
	CreatedAt time.Time
}

// Window is a contiguous slice of channel messages bounded by time and count.
type Window struct {
	ChannelID    string
	ServerID     string
	Start        time.Time
	End          time.Time
	Messages     []WindowMessage
	Truncated    bool // true if the channel had more messages than the cap
	AnchorMsgID  *string
	LatestMsgID  *string
	Participants []string // unique authors, sorted
}

// WindowOptions controls how a window is built.
type WindowOptions struct {
	// Hard cap on number of messages we feed the model. Discord-style channels
	// can be long; the spec calls 500 a comfortable upper bound for an 8k
	// context after compression.
	MaxMessages int
	// Smallest window we are willing to summarise. Below this we refuse.
	MinMessages int
}

// DefaultWindowOptions used when callers don't override.
func DefaultWindowOptions() WindowOptions {
	return WindowOptions{MaxMessages: 500, MinMessages: 5}
}

// FetchWindow loads a contiguous slice of messages from a channel between
// (sinceTS, now] up to opts.MaxMessages. Messages are returned in chronological
// order so the prompt reads like a transcript.
//
// We intentionally read the slim profile shape directly (no JOIN explosion)
// to keep latency low. Authors are joined by username and display_name when
// available; missing rows fall back to "user-<id-prefix>".
func FetchWindow(
	ctx context.Context,
	db database.DatabaseClient,
	channelID, serverID string,
	since time.Time,
	now time.Time,
	opts WindowOptions,
) (*Window, error) {
	if opts.MaxMessages == 0 {
		opts = DefaultWindowOptions()
	}

	// Pull max+1 to detect truncation cheaply.
	const q = `
		SELECT m.id, m.author_id::text,
		       COALESCE(NULLIF(u.display_name, ''), NULLIF(u.username, ''), substr(m.author_id::text, 1, 8)) AS author_label,
		       COALESCE(m.content, ''),
		       m.created_at
		  FROM public.messages m
		  LEFT JOIN public.users u ON u.id = m.author_id
		 WHERE m.channel_id = $1
		   AND m.created_at >  $2
		   AND m.created_at <= $3
		   AND m.deleted_at IS NULL
		   AND COALESCE(m.content, '') <> ''
		 ORDER BY m.created_at ASC
		 LIMIT $4
	`
	rows, err := db.Query(ctx, q, channelID, since, now, opts.MaxMessages+1)
	if err != nil {
		return nil, fmt.Errorf("fetch window: %w", err)
	}
	defer rows.Close()

	w := &Window{
		ChannelID: channelID,
		ServerID:  serverID,
		Start:     since,
		End:       now,
	}

	authors := make(map[string]struct{})

	for rows.Next() {
		var m WindowMessage
		if err := rows.Scan(&m.ID, &m.AuthorID, &m.Author, &m.Content, &m.CreatedAt); err != nil {
			if err == pgx.ErrNoRows {
				break
			}
			return nil, fmt.Errorf("scan window row: %w", err)
		}
		w.Messages = append(w.Messages, m)
		authors[m.Author] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate window: %w", err)
	}

	if len(w.Messages) > opts.MaxMessages {
		w.Messages = w.Messages[:opts.MaxMessages]
		w.Truncated = true
	}

	if len(w.Messages) > 0 {
		latest := w.Messages[len(w.Messages)-1].ID
		w.LatestMsgID = &latest
		w.End = w.Messages[len(w.Messages)-1].CreatedAt
		w.Start = w.Messages[0].CreatedAt
	}

	w.Participants = make([]string, 0, len(authors))
	for a := range authors {
		w.Participants = append(w.Participants, a)
	}
	sort.Strings(w.Participants)

	return w, nil
}

// CacheKey produces a stable Redis cache key for a (channel, anchor, latest, model)
// tuple. anchor is the user's last-read message id at request time; latest is
// the last message in the window. Same window + same model = same cache hit.
func CacheKey(channelID string, anchor, latest *string, model string) string {
	a, l := "_", "_"
	if anchor != nil {
		a = *anchor
	}
	if latest != nil {
		l = *latest
	}
	raw := channelID + "|" + a + "|" + l + "|" + model
	sum := sha256.Sum256([]byte(raw))
	return "summary:answer:" + hex.EncodeToString(sum[:])
}
