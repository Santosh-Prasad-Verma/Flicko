package e2ee

import (
	"strings"
	"testing"
)

// Property: all v2 HKDF info strings are non-empty, project-prefixed,
// and pairwise distinct (R1.4).
func TestAllInfosAreUniqueAndNamespaced(t *testing.T) {
	if len(AllInfos) == 0 {
		t.Fatal("AllInfos must not be empty")
	}

	seen := make(map[string]struct{}, len(AllInfos))
	for _, info := range AllInfos {
		if info == "" {
			t.Errorf("empty info string in AllInfos")
		}
		if !strings.HasPrefix(info, "flicko-") {
			t.Errorf("info %q must start with the project prefix", info)
		}
		if _, dup := seen[info]; dup {
			t.Errorf("duplicate info string %q breaks R1.4 domain separation", info)
		}
		seen[info] = struct{}{}
	}
}

// Property: every named info constant appears in AllInfos (no orphans).
func TestAllInfosCoversNamedConstants(t *testing.T) {
	expected := []string{
		InfoX3DH,
		InfoRatchetRoot,
		InfoRatchetRecv,
		InfoRatchetSend,
		InfoRatchetMsg,
		InfoSealedSender,
		InfoBackup,
	}

	set := make(map[string]struct{}, len(AllInfos))
	for _, info := range AllInfos {
		set[info] = struct{}{}
	}

	for _, want := range expected {
		if _, ok := set[want]; !ok {
			t.Errorf("AllInfos missing %q", want)
		}
	}
}
