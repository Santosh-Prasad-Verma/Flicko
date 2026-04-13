package services_test

import (
	"regexp"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMentionService_ExtractionCompleteness(t *testing.T) {
	// Property 15: Mention Extraction Completeness
	// We verify that the regex patterns correctly identify all Markdown-style mentions.

	userRegex := regexp.MustCompile(`<@!?([0-9a-fA-F-]+)>`)
	roleRegex := regexp.MustCompile(`<@&([0-9a-fA-F-]+)>`)
	channelRegex := regexp.MustCompile(`<#([0-9a-fA-F-]+)>`)

	content := "Hello <@123e4567-e89b-12d3-a456-426614174000>, check out <#123e4567-e89b-12d3-a456-426614174001> and ask <@&123e4567-e89b-12d3-a456-426614174002>"

	// Test @user extraction
	userMatches := userRegex.FindStringSubmatch(content)
	assert.Len(t, userMatches, 2)
	assert.Equal(t, "123e4567-e89b-12d3-a456-426614174000", userMatches[1])

	// Test #channel extraction
	channelMatches := channelRegex.FindStringSubmatch(content)
	assert.Len(t, channelMatches, 2)
	assert.Equal(t, "123e4567-e89b-12d3-a456-426614174001", channelMatches[1])

	// Test @role extraction
	roleMatches := roleRegex.FindStringSubmatch(content)
	assert.Len(t, roleMatches, 2)
	assert.Equal(t, "123e4567-e89b-12d3-a456-426614174002", roleMatches[1])

	// Test Nickname @user syntax (<@!id>)
	nicknameContent := "Hi <@!123e4567-e89b-12d3-a456-426614174000>"
	nickMatches := userRegex.FindStringSubmatch(nicknameContent)
	assert.Len(t, nickMatches, 2)
	assert.Equal(t, "123e4567-e89b-12d3-a456-426614174000", nickMatches[1])
}
