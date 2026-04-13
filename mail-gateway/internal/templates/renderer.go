// Package templates handles loading and rendering HTML email templates.
// Uses html/template from the standard library for XSS-safe output.
package templates

import (
	"bytes"
	"fmt"
	"html/template"
	"log/slog"
	"os"
	"path/filepath"

	"github.com/flicko-org/mail-gateway/internal/models"
)

// Renderer loads HTML templates from disk and renders them with email data.
// Templates are parsed once at startup and reused for every email.
type Renderer struct {
	templates *template.Template
	dir       string // directory containing template files
}

// NewRenderer creates a Renderer by loading all *.html files from the given directory.
// Returns an error if the directory doesn't exist or templates fail to parse.
func NewRenderer(templateDir string) (*Renderer, error) {
	// Verify the template directory exists
	info, err := os.Stat(templateDir)
	if err != nil {
		return nil, fmt.Errorf("templates: directory %q not found: %w", templateDir, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("templates: %q is not a directory", templateDir)
	}

	// Parse all HTML templates in the directory
	pattern := filepath.Join(templateDir, "*.html")
	tmpl, err := template.ParseGlob(pattern)
	if err != nil {
		return nil, fmt.Errorf("templates: failed to parse templates in %q: %w", templateDir, err)
	}

	// Log which templates were loaded
	for _, t := range tmpl.Templates() {
		slog.Info("template loaded", "name", t.Name())
	}

	return &Renderer{
		templates: tmpl,
		dir:       templateDir,
	}, nil
}

// Render executes the named template with the given data and returns
// the resulting HTML string. The templateName should match the filename
// without extension (e.g. "verify" for "verify.html").
func (r *Renderer) Render(templateName string, data models.EmailData) (string, error) {
	// Templates are stored by filename, so add .html extension
	fullName := templateName + ".html"

	// Check if the template exists
	t := r.templates.Lookup(fullName)
	if t == nil {
		return "", fmt.Errorf("templates: template %q not found (looked up %q)", templateName, fullName)
	}

	// Render template to buffer
	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("templates: failed to render %q: %w", templateName, err)
	}

	return buf.String(), nil
}

// TemplateNames returns the names of all loaded templates (for health checks).
func (r *Renderer) TemplateNames() []string {
	names := make([]string, 0)
	for _, t := range r.templates.Templates() {
		names = append(names, t.Name())
	}
	return names
}
