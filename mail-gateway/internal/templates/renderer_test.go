package templates

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/flicko-org/mail-gateway/internal/models"
)

func TestRenderAllTemplates(t *testing.T) {
	renderer, err := NewRenderer(filepath.Join("..", "..", "templates"))
	if err != nil {
		t.Fatalf("NewRenderer() error = %v", err)
	}

	data := models.EmailData{
		To:          "user@example.com",
		Username:    "tarun",
		AvatarURL:   "https://example.com/avatar.png",
		Subject:     "Test Subject",
		ActionURL:   "https://example.com/action",
		AppName:     "Flicko",
		AppURL:      "https://example.com",
		ValidFor:    "24 hours",
		MemberSince: "April 2026",
		Year:        2026,
	}

	templateNames := []string{
		"confirm_email_change",
		"invite",
		"magic_link",
		"reauthentication",
		"reset",
		"verify",
		"welcome",
	}

	for _, templateName := range templateNames {
		t.Run(templateName, func(t *testing.T) {
			rendered, err := renderer.Render(templateName, data)
			if err != nil {
				t.Fatalf("Render(%q) error = %v", templateName, err)
			}

			if !strings.Contains(rendered, data.AppName) {
				t.Fatalf("rendered template %q did not contain app name", templateName)
			}
		})
	}
}
