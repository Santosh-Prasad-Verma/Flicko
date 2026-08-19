package handlers_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func backendRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd failed: %v", err)
	}
	root := filepath.Clean(filepath.Join(wd, "..", ".."))
	if _, err = os.Stat(filepath.Join(root, "go.mod")); err != nil {
		t.Fatalf("backend root not found from %s: %v", wd, err)
	}
	return root
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed reading %s: %v", path, err)
	}
	return string(b)
}

func assertContainsAll(t *testing.T, content string, needles []string) {
	t.Helper()
	for _, n := range needles {
		if !strings.Contains(content, n) {
			t.Fatalf("expected content to include %q", n)
		}
	}
}

// X1: Contract checks for REST+WS compatibility surfaces used by parity tickets.
func TestParityRESTContractRoutesPresent(t *testing.T) {
	root := backendRoot(t)
	mainGo := readFile(t, filepath.Join(root, "cmd", "server", "main.go"))

	requiredRoutes := []string{
		`"/activities/launch"`,
		`"/apps/{id}/installs/{installId}/permissions"`,
		`"/interactions/components"`,
		`"/interactions/modals"`,
		`"/app-directory"`,
		`"/servers/discover/trending"`,
		`"/forum/posts/{id}/vote"`,
		`"/servers/{id}/insights"`,
	}

	assertContainsAll(t, mainGo, requiredRoutes)
}

func TestParityWSContractDomainsPresent(t *testing.T) {
	root := backendRoot(t)
	repoRoot := filepath.Clean(filepath.Join(root, ".."))

	wsDocs := readFile(t, filepath.Join(repoRoot, "docs", "api", "ws-event-schemas-v1.md"))
	requiredDomains := []string{
		"| MESSAGE  | v1      | active |",
		"| VOICE    | v1      | active |",
		"| ACTIVITY | v1      | active |",
		"| MOD      | v1      | active |",
	}
	assertContainsAll(t, wsDocs, requiredDomains)

	schemaMigration := readFile(t, filepath.Join(repoRoot, "DEL", "supabase", "migrations", "100_phase0_parity_governance.sql"))
	requiredSeeds := []string{
		"('MESSAGE', 'ws_event', 'v1', 'active', NOW())",
		"('VOICE', 'ws_event', 'v1', 'active', NOW())",
		"('ACTIVITY', 'ws_event', 'v1', 'active', NOW())",
		"('MOD', 'ws_event', 'v1', 'active', NOW())",
	}
	assertContainsAll(t, schemaMigration, requiredSeeds)
}
