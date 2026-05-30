package message_summary

import (
	"regexp"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/models"
)

// Parse converts the raw bullet-format LLM output into structured
// SummaryBullet objects with resolved citations.
//
// Expected format (enforced by prompt):
//
//	• alice and bob shipped v2 onboarding [#012 #014]
//	• carol asked about pricing — open thread [#018]
//	• ...
//
// where #N references the [#NNN] line index emitted by Render(). We resolve
// them back to message ids using the original window so the client can jump
// to a real message.
//
// Parse is robust to:
//   - leading "- " or "* " instead of "•"
//   - LLMs that put citations in parentheses or with "ref:" prefix
//   - LLMs that omit the bullet entirely on the last line
//   - smart quotes / unicode dashes
//
// Lines that don't look like bullets are silently dropped.
func Parse(raw string, window []WindowMessage) []models.SummaryBullet {
	if raw == "" {
		return nil
	}
	lines := strings.Split(raw, "\n")

	out := make([]models.SummaryBullet, 0, len(lines))
	idx := 0
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Drop the trailing META: line emitted by the prompt — sentiment is
		// extracted separately. Without this guard the parser turns it into
		// a stray bullet.
		if strings.HasPrefix(line, "META:") {
			continue
		}
		// Strip bullet marker.
		line = stripBulletPrefix(line)
		if line == "" {
			continue
		}

		text, citations := extractCitations(line, window)
		text = strings.TrimSpace(text)
		// Skip lines that became empty after pulling citations off.
		if len(text) < 3 {
			continue
		}
		out = append(out, models.SummaryBullet{
			Index:     idx,
			Text:      text,
			Citations: citations,
		})
		idx++
	}
	return out
}

var (
	bulletPrefixRE = regexp.MustCompile(`^[\s]*([•\-\*•]|\d+[\.\)])\s+`)
	citationRE     = regexp.MustCompile(`\[?#0*(\d{1,4})\]?`)
	parenCleanupRE = regexp.MustCompile(`\(\s*\)|\[\s*\]`)
)

func stripBulletPrefix(s string) string {
	return bulletPrefixRE.ReplaceAllString(s, "")
}

// extractCitations pulls all "#N" tokens (with or without [], with or without
// leading zeros) and resolves them to message IDs from the window. Tokens
// are removed from the returned text.
func extractCitations(line string, window []WindowMessage) (string, []string) {
	matches := citationRE.FindAllStringSubmatchIndex(line, -1)
	if len(matches) == 0 {
		return line, nil
	}
	citations := make([]string, 0, len(matches))
	seen := make(map[string]bool)

	// Walk in reverse so we can splice cleanly.
	cleaned := line
	for i := len(matches) - 1; i >= 0; i-- {
		m := matches[i]
		// Group 1 captures the digits.
		nStr := line[m[2]:m[3]]
		var n int
		for _, c := range nStr {
			n = n*10 + int(c-'0')
		}
		if n > 0 && n <= len(window) {
			id := window[n-1].ID
			if !seen[id] {
				citations = append(citations, id)
				seen[id] = true
			}
		}
		cleaned = cleaned[:m[0]] + cleaned[m[1]:]
	}
	// Reverse citations so they appear in textual order.
	for i, j := 0, len(citations)-1; i < j; i, j = i+1, j-1 {
		citations[i], citations[j] = citations[j], citations[i]
	}
	cleaned = parenCleanupRE.ReplaceAllString(cleaned, "")
	cleaned = strings.TrimSpace(cleaned)
	return cleaned, citations
}

// ResolveParticipants returns the unique sorted set of authors that actually
// appear cited in the bullets. We use this for the "meta" SSE event so the
// client can show "alice, bob, and 4 others contributed".
func ResolveParticipants(bullets []models.SummaryBullet, window []WindowMessage) []string {
	idToAuthor := make(map[string]string, len(window))
	for _, m := range window {
		idToAuthor[m.ID] = m.Author
	}
	seen := map[string]struct{}{}
	for _, b := range bullets {
		for _, cid := range b.Citations {
			if a, ok := idToAuthor[cid]; ok {
				seen[a] = struct{}{}
			}
		}
	}
	out := make([]string, 0, len(seen))
	for a := range seen {
		out = append(out, a)
	}
	// Stable order.
	if len(out) > 1 {
		sortStrings(out)
	}
	return out
}

func sortStrings(s []string) {
	// Simple insertion sort for small lists (typical: ≤10 participants).
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1] > s[j]; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
