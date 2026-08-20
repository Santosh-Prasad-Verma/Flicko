package message_summary

import (
	"regexp"
	"strings"
	"unicode"
)

// Compress shrinks a window so it fits in the LLM context budget without
// losing meaning. The pipeline is intentionally conservative — every step is
// a clear lossless or near-lossless transform, and we surface the budget
// pressure (Truncated) to the prompt so the model can flag it.
//
// Steps applied in order:
//
//  1. drop empty / whitespace-only messages
//  2. drop emoji-only and reaction-y messages (e.g. "😂😂😂", "lol", "+1")
//  3. collapse consecutive duplicate or near-duplicate messages from the
//     same author (chat-spam pattern: "hi", "hi", "hi")
//  4. truncate quoted blocks beyond 2 lines to "[quote …]"
//  5. trim every message to MaxPerMessageRunes
//  6. greedily prune from the front until total runes <= TotalBudgetRunes
//
// Step 6 prefers keeping the recent end of the conversation, which is
// usually what "catch me up" callers want.
type CompressResult struct {
	Messages          []WindowMessage
	DroppedEmojiOnly  int
	DroppedDuplicate  int
	DroppedFront      int
	TotalRunesAfter   int
	TruncatedDueToCap bool
}

// CompressOptions tunes the compressor's budgets.
type CompressOptions struct {
	// Approx total budget in runes for the rendered transcript. The default
	// (~24,000) maps to ~6k tokens after our prompt overhead.
	TotalBudgetRunes int
	// Cap on a single message's rendered length. Long copy-pastes get
	// trimmed.
	MaxPerMessageRunes int
}

// DefaultCompressOptions used when callers don't override.
func DefaultCompressOptions() CompressOptions {
	return CompressOptions{
		TotalBudgetRunes:   24000,
		MaxPerMessageRunes: 600,
	}
}

// Compress applies the pipeline above and returns the compressed messages
// alongside drop counters for telemetry.
func Compress(in []WindowMessage, opts CompressOptions) CompressResult {
	if opts.TotalBudgetRunes == 0 {
		opts = DefaultCompressOptions()
	}

	res := CompressResult{}
	out := make([]WindowMessage, 0, len(in))

	var prev *WindowMessage
	for i := range in {
		m := in[i]
		// Step 1: empty/whitespace
		trimmed := strings.TrimSpace(m.Content)
		if trimmed == "" {
			continue
		}
		m.Content = trimmed

		// Step 2: emoji-only / reaction noise
		if isEmojiOnly(m.Content) || isLowSignalReaction(m.Content) {
			res.DroppedEmojiOnly++
			continue
		}

		// Step 3: collapse near-duplicates from same author within 2 minutes
		if prev != nil &&
			prev.AuthorID == m.AuthorID &&
			m.CreatedAt.Sub(prev.CreatedAt).Minutes() <= 2 &&
			normalizedEqual(prev.Content, m.Content) {
			res.DroppedDuplicate++
			continue
		}

		// Step 4: collapse long quoted blocks
		m.Content = collapseQuotes(m.Content)

		// Step 5: per-message rune cap
		if r := []rune(m.Content); len(r) > opts.MaxPerMessageRunes {
			m.Content = string(r[:opts.MaxPerMessageRunes]) + "…"
		}

		out = append(out, m)
		copyOfM := m
		prev = &copyOfM
	}

	// Step 6: total-budget greedy prune from front
	total := 0
	for _, m := range out {
		total += runeLen(m.Author) + runeLen(m.Content) + 4 // formatting slack
	}
	if total > opts.TotalBudgetRunes {
		res.TruncatedDueToCap = true
		// Drop oldest until under budget.
		i := 0
		for total > opts.TotalBudgetRunes && i < len(out) {
			total -= runeLen(out[i].Author) + runeLen(out[i].Content) + 4
			i++
			res.DroppedFront++
		}
		out = out[i:]
	}

	res.Messages = out
	res.TotalRunesAfter = total
	return res
}

// Render produces a transcript string suitable for the prompt body.
//
// Format:
//
//	[#01 msg-id alice 14:02] hello there
//	[#02 msg-id bob   14:03] hi
//
// We include both an ordinal index (so the model can refer to bullets back
// to lines) and the real msg id (so the parser can resolve citations).
func Render(msgs []WindowMessage) string {
	var b strings.Builder
	b.Grow(len(msgs) * 64)
	for i, m := range msgs {
		fmt := m.CreatedAt.UTC().Format("15:04")
		b.WriteString("[#")
		writeIntPadded(&b, i+1, 3)
		b.WriteString(" ")
		b.WriteString(m.ID)
		b.WriteString(" ")
		b.WriteString(m.Author)
		b.WriteString(" ")
		b.WriteString(fmt)
		b.WriteString("] ")
		b.WriteString(m.Content)
		b.WriteString("\n")
	}
	return b.String()
}

func writeIntPadded(b *strings.Builder, n, width int) {
	s := numString(n)
	for i := len(s); i < width; i++ {
		b.WriteByte('0')
	}
	b.WriteString(s)
}

func numString(n int) string {
	if n == 0 {
		return "0"
	}
	digits := []byte{}
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	return string(digits)
}

// runeLen counts runes; cheaper than [...]rune(s) when we only want the size.
func runeLen(s string) int {
	n := 0
	for range s {
		n++
	}
	return n
}

var (
	reactionyRE   = regexp.MustCompile(`^(?i)(lol+|haha+|lmao+|wtf+|same+|\+1|same|this|f|ok+|np+|gg+|nice+)\.?!*$`)
	multiQuoteRE  = regexp.MustCompile(`(?m)^(>[^\n]*\n){3,}`)
	whitespaceMul = regexp.MustCompile(`\s+`)
)

// isEmojiOnly returns true for strings made entirely of emoji, punctuation,
// and whitespace.
func isEmojiOnly(s string) bool {
	if len(s) == 0 {
		return true
	}
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

// isLowSignalReaction matches one-word reactions that don't carry information
// useful for a summary.
func isLowSignalReaction(s string) bool {
	return reactionyRE.MatchString(strings.TrimSpace(s))
}

// collapseQuotes replaces 3-or-more consecutive quoted lines with "[quote …]"
// to free budget for original content.
func collapseQuotes(s string) string {
	return multiQuoteRE.ReplaceAllString(s, "[quote …]\n")
}

// normalizedEqual compares two strings with whitespace runs collapsed and
// lowercased — enough to catch chat-spam dupes ("hi" / "hi  ").
func normalizedEqual(a, b string) bool {
	return whitespaceMul.ReplaceAllString(strings.ToLower(a), " ") ==
		whitespaceMul.ReplaceAllString(strings.ToLower(b), " ")
}
