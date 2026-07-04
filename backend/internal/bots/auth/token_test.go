package auth

import (
	"crypto/rand"
	"testing"
)

func TestTokenLifecycle(t *testing.T) {
	secret1 := []byte("super-secret-key-1-very-secure-must-be-long-enough")
	secret2 := []byte("super-secret-key-2-rotated-key-replacement-value-xyz")
	secrets := map[string][]byte{
		"v1": secret1,
		"v2": secret2,
	}

	botID := "bot-user-uuid-123456"

	// 1. Generate token
	token, err := GenerateToken(botID, "v1", secret1)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	// 2. Verify token
	verifiedID, err := VerifyToken(token, secrets)
	if err != nil {
		t.Fatalf("failed to verify token: %v", err)
	}

	if verifiedID != botID {
		t.Errorf("expected bot ID %q, got %q", botID, verifiedID)
	}

	// 3. Test verification with key rotation (generating with v2, verifying with secrets map)
	token2, err := GenerateToken(botID, "v2", secret2)
	if err != nil {
		t.Fatalf("failed to generate token on v2: %v", err)
	}

	verifiedID2, err := VerifyToken(token2, secrets)
	if err != nil {
		t.Fatalf("failed to verify token on v2: %v", err)
	}

	if verifiedID2 != botID {
		t.Errorf("expected bot ID %q, got %q", botID, verifiedID2)
	}

	// 4. Verification fails with wrong key version secret
	wrongSecrets := map[string][]byte{
		"v1": secret2, // mismatched secret
	}
	_, err = VerifyToken(token, wrongSecrets)
	if err == nil {
		t.Error("expected signature verification to fail, but it succeeded")
	}

	// 5. Verification fails with invalid format
	_, err = VerifyToken("v1.invalidformat", secrets)
	if err == nil {
		t.Error("expected verification of malformed token to fail")
	}
}

func BenchmarkTokenVerification(b *testing.B) {
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		b.Fatal(err)
	}
	secrets := map[string][]byte{"v1": secret}
	token, err := GenerateToken("bot-id-12345", "v1", secret)
	if err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = VerifyToken(token, secrets)
	}
}
