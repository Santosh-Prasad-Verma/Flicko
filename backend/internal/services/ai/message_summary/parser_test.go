package message_summary

import (
	"testing"
	"time"
)

func TestParseBulletsWithCitations(t *testing.T) {
	window := []WindowMessage{
		{ID: "m1", Author: "alice", Content: "hi", CreatedAt: time.Now()},
		{ID: "m2", Author: "bob", Content: "hello", CreatedAt: time.Now()},
		{ID: "m3", Author: "carol", Content: "yo", CreatedAt: time.Now()},
	}
	raw := "" +
		"• alice greeted everyone [#001]\n" +
		"• bob and carol responded [#002 #003]\n" +
		"META: sentiment=positive\n"
	bullets := Parse(raw, window)
	if len(bullets) != 2 {
		t.Fatalf("want 2 bullets, got %d: %+v", len(bullets), bullets)
	}
	if bullets[0].Text != "alice greeted everyone" {
		t.Fatalf("bullet 0 text mismatch: %q", bullets[0].Text)
	}
	if len(bullets[0].Citations) != 1 || bullets[0].Citations[0] != "m1" {
		t.Fatalf("bullet 0 citations mismatch: %v", bullets[0].Citations)
	}
	if len(bullets[1].Citations) != 2 ||
		bullets[1].Citations[0] != "m2" || bullets[1].Citations[1] != "m3" {
		t.Fatalf("bullet 1 citations mismatch: %v", bullets[1].Citations)
	}
}

func TestParseHandlesAlternateBulletMarkers(t *testing.T) {
	window := []WindowMessage{{ID: "m1", Author: "a", Content: "x", CreatedAt: time.Now()}}
	cases := []string{
		"- one [#1]",
		"* two [#1]",
		"1. three [#1]",
	}
	for _, in := range cases {
		bs := Parse(in+"\n", window)
		if len(bs) != 1 {
			t.Fatalf("want 1 bullet for %q, got %d", in, len(bs))
		}
	}
}

func TestParseDropsCitationsOutOfRange(t *testing.T) {
	window := []WindowMessage{{ID: "m1", Author: "a", Content: "x", CreatedAt: time.Now()}}
	bs := Parse("• unrelated [#9999]\n", window)
	if len(bs) != 1 {
		t.Fatalf("want 1 bullet, got %d", len(bs))
	}
	if len(bs[0].Citations) != 0 {
		t.Fatalf("want 0 citations resolved, got %v", bs[0].Citations)
	}
}

func TestExtractSentiment(t *testing.T) {
	cases := map[string]string{
		"META: sentiment=positive\n":     "positive",
		"some\nMETA: sentiment=mixed\n":  "mixed",
		"META: sentiment=garbage\n":      "",
		"":                               "",
	}
	for raw, want := range cases {
		got := extractSentiment(raw)
		gotStr := ""
		if got != nil {
			gotStr = *got
		}
		if gotStr != want {
			t.Fatalf("extractSentiment(%q) = %q, want %q", raw, gotStr, want)
		}
	}
}
