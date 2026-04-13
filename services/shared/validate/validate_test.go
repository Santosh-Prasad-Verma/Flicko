package validate

import (
	"strings"
	"testing"

	flickoerrors "github.com/flicko-org/flicko/services/shared/errors"
)

func TestUsername(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
	}{
		{"john_doe", false},
		{"ab", false}, // minimum 2 chars
		{"a", true},   // too short
		{"JohnDoe123", false},
		{strings.Repeat("a", 32), false}, // max 32
		{strings.Repeat("a", 33), true},  // too long
		{"has spaces", true},
		{"has-hyphen", true},
		{"has.dot", true},
		{"", true},
		{"@mention", true},
		{"_underscore_ok", false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			err := Username(tt.input)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}

func TestEmail(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
	}{
		{"user@example.com", false},
		{"name+tag@domain.co.uk", false},
		{"invalid", true},
		{"@nodomain", true},
		{"no@", true},
		{"", true},
		{strings.Repeat("a", 250) + "@b.com", true}, // too long
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			err := Email(tt.input)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}

func TestPassword(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
	}{
		{"Secure1x", false},               // meets all requirements
		{"ALLUPPER1", true},               // no lowercase
		{"alllower1", true},               // no uppercase
		{"NoDigitsHere", true},            // no digit
		{"Sh0rt", true},                   // too short
		{strings.Repeat("Aa1", 50), true}, // too long (150 chars)
		{"ValidP@ss1", false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			err := Password(tt.input)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}

func TestMessageContent(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		maxLen    int
		wantErr   bool
		wantClean string
	}{
		{"normal", "Hello, world!", 2000, false, "Hello, world!"},
		{"trimmed", "  spaces  ", 2000, false, "spaces"},
		{"empty after trim", "   ", 2000, true, ""},
		{"too long", strings.Repeat("a", 2001), 2000, true, ""},
		{"null bytes removed", "hello\x00world", 2000, false, "helloworld"},
		{"crlf normalized", "line1\r\nline2", 2000, false, "line1\nline2"},
		{"excessive newlines", "a\n\n\n\n\nb", 2000, false, "a\n\nb"},
		{"emoji counted by rune", "👍👍👍", 3, false, "👍👍👍"},
		{"emoji too long", "👍👍👍👍", 3, true, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			clean, err := MessageContent(tt.input, tt.maxLen)
			if tt.wantErr {
				if err == nil {
					t.Error("expected error")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if clean != tt.wantClean {
				t.Errorf("got %q, want %q", clean, tt.wantClean)
			}
		})
	}
}

func TestChannelName(t *testing.T) {
	tests := []struct {
		input   string
		want    string
		wantErr bool
	}{
		{"general", "general", false},
		{"General Chat", "general-chat", false},
		{"LOUD", "loud", false},
		{"has--double", "has-double", false},
		{"has  spaces", "has-spaces", false},
		{strings.Repeat("a", 101), "", true},
		{"", "", true},
		{"-starts-hyphen", "", true},
		{"valid_underscore", "valid_underscore", false},
		{"123numeric", "123numeric", false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := ChannelName(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Error("expected error")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

func TestGuildName(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
	}{
		{"My Server", false},
		{"ab", false},
		{"a", true},                       // too short
		{strings.Repeat("a", 100), false}, // max
		{strings.Repeat("a", 101), true},  // too long
		{"🎮 Gaming Guild", false},         // emoji ok
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			err := GuildName(tt.input)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}

func TestContentType(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
	}{
		{"image/jpeg", false},
		{"image/png", false},
		{"video/mp4", false},
		{"application/pdf", false},
		{"application/javascript", true},
		{"text/html", true},
		{"", true},
		{"IMAGE/JPEG", false}, // case insensitive
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			err := ContentType(tt.input)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}

func TestFileSize(t *testing.T) {
	maxSize := int64(25 * 1024 * 1024) // 25MB

	tests := []struct {
		size    int64
		wantErr bool
		errCode flickoerrors.Code
	}{
		{1024, false, ""},
		{maxSize, false, ""},
		{maxSize + 1, true, flickoerrors.CodeFileTooLarge},
		{0, true, flickoerrors.CodeValidation},
		{-1, true, flickoerrors.CodeValidation},
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			err := FileSize(tt.size, maxSize)
			if tt.wantErr {
				if err == nil {
					t.Error("expected error")
				}
				if tt.errCode != "" && flickoerrors.GetCode(err) != tt.errCode {
					t.Errorf("expected code %s, got %s", tt.errCode, flickoerrors.GetCode(err))
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
		})
	}
}

func TestLimit(t *testing.T) {
	tests := []struct {
		requested, def, max, want int
	}{
		{50, 50, 100, 50},
		{0, 50, 100, 50},    // use default
		{-1, 50, 100, 50},   // use default
		{200, 50, 100, 100}, // clamped to max
		{1, 50, 100, 1},
	}

	for _, tt := range tests {
		got := Limit(tt.requested, tt.def, tt.max)
		if got != tt.want {
			t.Errorf("Limit(%d, %d, %d) = %d, want %d",
				tt.requested, tt.def, tt.max, got, tt.want)
		}
	}
}
