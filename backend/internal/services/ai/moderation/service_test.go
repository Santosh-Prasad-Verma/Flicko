package moderation

import (
	"context"
	"testing"
)

func TestParseScoresHappyPath(t *testing.T) {
	raw := `S1: 0.02
S2: 0.91
S3: 0.0
S4: 0.0
S5: 0.10`
	got, err := parseScores(raw)
	if err != nil {
		t.Fatalf("parseScores: %v", err)
	}
	want := map[string]float64{
		CategoryHate:       0.02,
		CategoryHarassment: 0.91,
		CategorySexual:     0.0,
		CategorySelfHarm:   0.0,
		CategoryViolence:   0.10,
	}
	for k, v := range want {
		if got[k] != v {
			t.Errorf("%s = %v, want %v", k, got[k], v)
		}
	}
}

func TestParseScoresClampsRange(t *testing.T) {
	raw := "S1: 1.7\nS2: -0.4\nS3: 0.0\nS4: 0.0\nS5: 0.0"
	got, err := parseScores(raw)
	if err != nil {
		t.Fatalf("parseScores: %v", err)
	}
	if got[CategoryHate] != 1.0 {
		t.Errorf("hate clamp: got %v want 1.0", got[CategoryHate])
	}
	if got[CategoryHarassment] != 0.0 {
		t.Errorf("harassment clamp: got %v want 0.0", got[CategoryHarassment])
	}
}

func TestParseScoresIgnoresPreamble(t *testing.T) {
	raw := "Sure thing, here's my analysis:\n\nS1: 0.10\nS2: 0.20\nS3: 0.05\nS4: 0.0\nS5: 0.30\n\n(end)"
	got, err := parseScores(raw)
	if err != nil {
		t.Fatalf("parseScores: %v", err)
	}
	if got[CategoryViolence] != 0.30 {
		t.Errorf("violence: got %v want 0.30", got[CategoryViolence])
	}
}

func TestParseScoresUnparseable(t *testing.T) {
	if _, err := parseScores("I'm not sure how to score that."); err == nil {
		t.Fatal("expected error for prose-only output")
	}
}

func TestDecideBlocksAboveBlock(t *testing.T) {
	thr := DefaultThresholds()
	scores := map[string]float64{
		CategoryHate: 0.0, CategoryHarassment: 0.97,
		CategorySexual: 0.0, CategorySelfHarm: 0.0, CategoryViolence: 0.0,
	}
	d, cat, score := decide(scores, thr)
	if d != DecisionBlocked || cat != CategoryHarassment {
		t.Fatalf("want blocked harassment, got %s/%s/%v", d, cat, score)
	}
}

func TestDecideReviewsMidRange(t *testing.T) {
	thr := DefaultThresholds()
	scores := map[string]float64{
		CategoryHate: 0.66, CategoryHarassment: 0.0,
		CategorySexual: 0.0, CategorySelfHarm: 0.0, CategoryViolence: 0.0,
	}
	d, cat, _ := decide(scores, thr)
	if d != DecisionReview || cat != CategoryHate {
		t.Fatalf("want review hate, got %s/%s", d, cat)
	}
}

func TestDecideClean(t *testing.T) {
	thr := DefaultThresholds()
	scores := zeroScores()
	d, _, _ := decide(scores, thr)
	if d != DecisionClean {
		t.Fatalf("want clean, got %s", d)
	}
}

func TestSetThresholdsRejectsReviewAboveBlock(t *testing.T) {
	s := &service{} // no db needed before validation hits
	t1 := Thresholds{
		Block:  map[string]float64{CategoryHate: 0.8},
		Review: map[string]float64{CategoryHate: 0.9},
	}
	if err := s.SetThresholds(context.TODO(), "srv", t1); err == nil {
		t.Fatal("expected validation error")
	}
}
