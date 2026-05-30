package message_summary

import (
	"strings"
	"testing"
	"time"
)

func mkMsg(id, author, content string, t time.Time) WindowMessage {
	return WindowMessage{ID: id, AuthorID: author, Author: author, Content: content, CreatedAt: t}
}

func TestCompressDropsEmojiOnlyAndDuplicates(t *testing.T) {
	now := time.Now()
	in := []WindowMessage{
		mkMsg("m1", "alice", "hey can we move standup", now),
		mkMsg("m2", "alice", "hey can we move standup", now.Add(30*time.Second)), // dup
		mkMsg("m3", "bob", "😂😂😂", now.Add(time.Minute)),                         // emoji-only
		mkMsg("m4", "bob", "lol", now.Add(2*time.Minute)),                        // low-signal
		mkMsg("m5", "carol", "yes works", now.Add(3*time.Minute)),
	}
	res := Compress(in, DefaultCompressOptions())
	if len(res.Messages) != 2 {
		t.Fatalf("want 2 surviving messages, got %d (%+v)", len(res.Messages), res.Messages)
	}
	if res.DroppedDuplicate < 1 {
		t.Errorf("expected duplicate drop, got %d", res.DroppedDuplicate)
	}
	if res.DroppedEmojiOnly < 2 {
		t.Errorf("expected emoji+reaction drops, got %d", res.DroppedEmojiOnly)
	}
}

func TestCompressTruncatesPerMessage(t *testing.T) {
	long := strings.Repeat("a", 1000)
	res := Compress([]WindowMessage{mkMsg("m1", "a", long, time.Now())},
		CompressOptions{TotalBudgetRunes: 100000, MaxPerMessageRunes: 50})
	if got := res.Messages[0].Content; len(got) > 60 {
		t.Fatalf("expected per-message truncation, got len %d", len(got))
	}
	if !strings.HasSuffix(res.Messages[0].Content, "…") {
		t.Fatalf("expected ellipsis suffix on truncated content")
	}
}

func TestCompressGreedyPrunesFromFront(t *testing.T) {
	now := time.Now()
	in := []WindowMessage{
		mkMsg("m1", "a", strings.Repeat("x", 500), now),
		mkMsg("m2", "a", strings.Repeat("x", 500), now.Add(time.Hour)),
		mkMsg("m3", "a", strings.Repeat("x", 500), now.Add(2*time.Hour)),
	}
	res := Compress(in, CompressOptions{TotalBudgetRunes: 800, MaxPerMessageRunes: 1000})
	if !res.TruncatedDueToCap {
		t.Fatalf("expected truncation flag")
	}
	if res.DroppedFront < 1 {
		t.Fatalf("expected front-pruning, got %d", res.DroppedFront)
	}
	// The newest message must always survive when possible.
	if res.Messages[len(res.Messages)-1].ID != "m3" {
		t.Fatalf("expected newest message preserved, got %v", res.Messages)
	}
}

func TestRenderProducesIndexedFormat(t *testing.T) {
	now := time.Date(2026, 5, 29, 14, 2, 0, 0, time.UTC)
	rendered := Render([]WindowMessage{mkMsg("abcd", "alice", "hello", now)})
	if !strings.HasPrefix(rendered, "[#001 abcd alice 14:02] hello") {
		t.Fatalf("unexpected render output: %q", rendered)
	}
}
