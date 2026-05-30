// Package e2ee — replay-window hash invariants.
//
// The envelope dedup window's correctness depends on two invariants:
//   1. Determinism — the same (header, ciphertext) MUST hash to the same
//      bytes, otherwise legitimate replays can never be detected.
//   2. Collision resistance for distinct inputs — changing EITHER the
//      header (DR position) or the ciphertext bytes MUST change the digest.
//      A regression here would let an attacker craft "different but same
//      hash" envelopes and bypass the window.
//
// We don't unit-test the database INSERT path (no pgxmock or testcontainer
// in the dep tree); instead we pin the hash function. The full Push +
// rollback flow is exercised manually against the dev DB and via the CI
// build job that ensures the migration applies cleanly.
package e2ee

import (
	"bytes"
	"testing"
)

func TestEnvelopeHashIsDeterministic(t *testing.T) {
	header := []byte{0x01, 0x02, 0x03, 0x04}
	ciphertext := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}

	a := EnvelopeHash(header, ciphertext)
	b := EnvelopeHash(header, ciphertext)
	if !bytes.Equal(a, b) {
		t.Fatalf("EnvelopeHash is not deterministic: %x vs %x", a, b)
	}
	if len(a) != 32 {
		t.Fatalf("EnvelopeHash output is not 32 bytes (got %d)", len(a))
	}
}

func TestEnvelopeHashChangesWhenHeaderChanges(t *testing.T) {
	ciphertext := []byte{0xAA, 0xBB, 0xCC, 0xDD}

	original := EnvelopeHash([]byte{0x01, 0x02}, ciphertext)
	flipped := EnvelopeHash([]byte{0x01, 0x03}, ciphertext)

	if bytes.Equal(original, flipped) {
		t.Fatalf("changing the header MUST change the hash")
	}
}

func TestEnvelopeHashChangesWhenCiphertextChanges(t *testing.T) {
	header := []byte{0x01, 0x02, 0x03}

	original := EnvelopeHash(header, []byte{0xAA, 0xBB, 0xCC})
	flipped := EnvelopeHash(header, []byte{0xAA, 0xBB, 0xCD})

	if bytes.Equal(original, flipped) {
		t.Fatalf("changing the ciphertext MUST change the hash")
	}
}

// Note: we deliberately don't assert "boundary sensitivity" between
// header and ciphertext. The wire format pins the header at exactly 40
// bytes (DR header = dhPub(32) || pn(4) || n(4)); the split is implicit
// in parsing, so a "shifted boundary" attack cannot reach this function
// with a different header length.
