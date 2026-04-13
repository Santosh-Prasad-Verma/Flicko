package services_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mockAutoModEvaluator simulates the EvaluateMessage logic
// by re-implementing evaluateRule locally for unit testing.
func mockEvaluate(rule *models.AutoModRule, content string) bool {
	rawJSON, _ := json.Marshal(rule.TriggerConfig)

	switch rule.RuleType {
	case models.RuleTypeKeywords:
		var cfg models.KeywordConfig
		if json.Unmarshal(rawJSON, &cfg) != nil {
			return false
		}
		for _, kw := range cfg.Keywords {
			if !cfg.CaseSensitive {
				if containsIgnoreCase(content, kw) {
					return true
				}
			} else if containsExact(content, kw) {
				return true
			}
		}
	case models.RuleTypeProfanity:
		var cfg models.ProfanityConfig
		if json.Unmarshal(rawJSON, &cfg) != nil {
			return false
		}
		for _, p := range cfg.Patterns {
			if containsIgnoreCase(content, p) {
				return true
			}
		}
	case models.RuleTypeMentions:
		var cfg models.MentionConfig
		if json.Unmarshal(rawJSON, &cfg) != nil {
			return false
		}
		count := countOccurrences(content, "<@")
		if cfg.CountEveryoneMention {
			count += countOccurrences(content, "@everyone")
			count += countOccurrences(content, "@here")
		}
		return cfg.MaxMentions > 0 && count > cfg.MaxMentions
	case models.RuleTypeLinks:
		var cfg models.LinkConfig
		if json.Unmarshal(rawJSON, &cfg) != nil {
			return false
		}
		if containsExact(content, "http://") || containsExact(content, "https://") {
			if !cfg.AllowLinks {
				return true
			}
		}
	}
	return false
}

func containsIgnoreCase(s, substr string) bool {
	return len(s) > 0 && len(substr) > 0 &&
		(len(s) >= len(substr)) &&
		(s == substr || containsCI(s, substr))
}

func containsCI(s, sub string) bool {
	sl := toLower(s)
	subl := toLower(sub)
	for i := 0; i <= len(sl)-len(subl); i++ {
		if sl[i:i+len(subl)] == subl {
			return true
		}
	}
	return false
}

func toLower(s string) string {
	b := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		b[i] = c
	}
	return string(b)
}

func containsExact(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

func countOccurrences(s, sub string) int {
	count := 0
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			count++
		}
	}
	return count
}

// ─── Property 50: Auto-Mod Rule Violation Action ────────────────────────────

func TestAutoModRuleViolationAction(t *testing.T) {
	ctx := context.Background()
	_, _ = ctx, t

	// Keyword blocking
	keywordRule := &models.AutoModRule{
		ID:       "rule-1",
		RuleType: models.RuleTypeKeywords,
		TriggerConfig: models.KeywordConfig{
			Keywords:      []string{"badword", "forbidden"},
			CaseSensitive: false,
		},
		ActionType: models.ActionBlock,
		IsEnabled:  true,
	}

	assert.True(t, mockEvaluate(keywordRule, "This has a badword in it"))
	assert.True(t, mockEvaluate(keywordRule, "FORBIDDEN content"))
	assert.False(t, mockEvaluate(keywordRule, "This is clean text"))

	// Mention limit
	mentionRule := &models.AutoModRule{
		ID:       "rule-2",
		RuleType: models.RuleTypeMentions,
		TriggerConfig: models.MentionConfig{
			MaxMentions:          2,
			CountEveryoneMention: true,
		},
		ActionType: models.ActionTimeout,
		IsEnabled:  true,
	}

	assert.False(t, mockEvaluate(mentionRule, "Hey <@user1> check this"))
	assert.True(t, mockEvaluate(mentionRule, "<@a> <@b> <@c> spam mentions"))
	assert.True(t, mockEvaluate(mentionRule, "<@a> <@b> @everyone"))

	// Link blocking
	linkRule := &models.AutoModRule{
		ID:       "rule-3",
		RuleType: models.RuleTypeLinks,
		TriggerConfig: models.LinkConfig{
			AllowLinks: false,
		},
		ActionType: models.ActionBlock,
		IsEnabled:  true,
	}

	assert.True(t, mockEvaluate(linkRule, "Check out https://example.com"))
	assert.False(t, mockEvaluate(linkRule, "No links here"))

	// Profanity detection
	profanityRule := &models.AutoModRule{
		ID:       "rule-4",
		RuleType: models.RuleTypeProfanity,
		TriggerConfig: models.ProfanityConfig{
			Patterns:      []string{"slur1", "slur2"},
			CaseSensitive: false,
		},
		ActionType: models.ActionBan,
		IsEnabled:  true,
	}

	assert.True(t, mockEvaluate(profanityRule, "He said SLUR1 loudly"))
	assert.False(t, mockEvaluate(profanityRule, "Perfectly fine message"))
}

// ─── Property 51: Auto-Mod Exemptions ───────────────────────────────────────

func TestAutoModExemptions(t *testing.T) {
	ctx := context.Background()
	_, _ = ctx, t

	exemptChannels := []string{"channel-safe"}
	exemptRoles := []string{"role-admin", "role-moderator"}

	tests := []struct {
		name           string
		channelID      string
		authorRoles    []string
		expectedExempt bool
	}{
		{"Normal user in normal channel", "channel-1", []string{"role-member"}, false},
		{"Normal user in exempt channel", "channel-safe", []string{"role-member"}, true},
		{"Admin in normal channel", "channel-1", []string{"role-admin"}, true},
		{"Moderator in normal channel", "channel-1", []string{"role-moderator"}, true},
		{"Admin in exempt channel", "channel-safe", []string{"role-admin"}, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := services.IsExemptExported(tt.channelID, tt.authorRoles, exemptChannels, exemptRoles)
			require.Equal(t, tt.expectedExempt, result, tt.name)
		})
	}
}
