package services

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSanitizeUploadFilename(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		// Ordinary names pass through untouched.
		{"plain name", "photo.png", "photo.png"},
		{"name with dashes", "my-sound-01.mp3", "my-sound-01.mp3"},
		{"name with underscores", "clip_02.wav", "clip_02.wav"},

		// Traversal: directory components are stripped.
		{"unix traversal", "../../etc/passwd", "passwd"},
		{"traversal into sibling prefix", "../../other-user/avatar.png", "avatar.png"},
		{"absolute path", "/etc/shadow", "shadow"},
		{"nested path", "a/b/c.txt", "c.txt"},

		// filepath.Base does not treat "\" as a separator on Linux, so the
		// regex must neutralise Windows-style traversal itself.
		{"windows traversal", `..\..\etc\passwd`, "_.._etc_passwd"},

		// Names that carry no usable content are rejected.
		{"empty", "", ""},
		{"whitespace only", "   ", ""},
		{"single dot", ".", ""},
		{"double dot", "..", ""},
		{"many dots", "....", ""},
		{"separator only", "/", ""},

		// Unsafe characters are replaced rather than dropped.
		{"spaces", "  spaced name.mp3  ", "spaced_name.mp3"},
		{"shell metacharacters", "a;rm -rf b.png", "a_rm_-rf_b.png"},
		{"null-ish and quotes", `a"b'c.png`, "a_b_c.png"},

		// A leading dot would create a hidden object.
		{"hidden file", ".hidden", "hidden"},
		{"leading dots retained content", "..config.json", "config.json"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.want, SanitizeUploadFilename(tc.input))
		})
	}
}

// The whole point of the helper is that its output is a single path segment, so
// assert that invariant directly rather than only on the cases enumerated above.
func TestSanitizeUploadFilename_NeverContainsSeparator(t *testing.T) {
	inputs := []string{
		"../../etc/passwd",
		`..\..\..\windows\system32`,
		"/absolute/path/file.png",
		"nested/../../escape.png",
		"..%2f..%2fetc%2fpasswd",
		strings.Repeat("../", 40) + "deep.png",
	}

	for _, in := range inputs {
		got := SanitizeUploadFilename(in)
		assert.NotContains(t, got, "/", "input %q leaked a forward slash", in)
		assert.NotContains(t, got, `\`, "input %q leaked a backslash", in)
		assert.NotEqual(t, "..", got, "input %q resolved to a parent reference", in)
		assert.False(t, strings.HasPrefix(got, "."), "input %q produced a hidden name", in)
	}
}

func TestSanitizeUploadFilename_TruncatesLongNames(t *testing.T) {
	got := SanitizeUploadFilename(strings.Repeat("a", 300) + ".png")

	require.LessOrEqual(t, len(got), maxUploadFilenameLen)
	assert.True(t, strings.HasSuffix(got, ".png"), "extension should survive truncation, got %q", got)
}

func TestSanitizeUploadFilename_NonASCII(t *testing.T) {
	// Non-ASCII runes are replaced, but a name that still has content must not
	// be rejected outright.
	got := SanitizeUploadFilename("файл.png")

	assert.NotEmpty(t, got)
	assert.True(t, strings.HasSuffix(got, ".png"))
	assert.NotContains(t, got, "/")
}
