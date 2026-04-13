package auth_test

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/flicko-org/flicko/services/shared/auth"
)

// ---------- helpers ----------

func generateTestKeys(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := auth.GenerateKeyPair()
	if err != nil {
		t.Fatalf("GenerateKeyPair() error = %v", err)
	}
	return pub, priv
}

func mustGenerateAccess(t *testing.T, priv ed25519.PrivateKey, claims *auth.Claims) string {
	t.Helper()
	tok, err := auth.GenerateAccessToken(priv, claims)
	if err != nil {
		t.Fatalf("GenerateAccessToken() error = %v", err)
	}
	return tok
}

// ============================================================
//  keys.go tests
// ============================================================

func TestGenerateKeyPair(t *testing.T) {
	pub, priv, err := auth.GenerateKeyPair()
	if err != nil {
		t.Fatalf("GenerateKeyPair() error = %v", err)
	}
	if len(pub) != ed25519.PublicKeySize {
		t.Errorf("public key length = %d, want %d", len(pub), ed25519.PublicKeySize)
	}
	if len(priv) != ed25519.PrivateKeySize {
		t.Errorf("private key length = %d, want %d", len(priv), ed25519.PrivateKeySize)
	}
}

func TestLoadKeysRoundTrip(t *testing.T) {
	pub, priv := generateTestKeys(t)
	dir := t.TempDir()

	// Marshal to PEM.
	privPEM, err := auth.MarshalPrivateKeyPEM(priv)
	if err != nil {
		t.Fatalf("MarshalPrivateKeyPEM() error = %v", err)
	}
	pubPEM, err := auth.MarshalPublicKeyPEM(pub)
	if err != nil {
		t.Fatalf("MarshalPublicKeyPEM() error = %v", err)
	}

	privPath := filepath.Join(dir, "private.pem")
	pubPath := filepath.Join(dir, "public.pem")
	os.WriteFile(privPath, privPEM, 0600)
	os.WriteFile(pubPath, pubPEM, 0644)

	// Load back.
	loadedPriv, err := auth.LoadPrivateKey(privPath)
	if err != nil {
		t.Fatalf("LoadPrivateKey() error = %v", err)
	}
	loadedPub, err := auth.LoadPublicKey(pubPath)
	if err != nil {
		t.Fatalf("LoadPublicKey() error = %v", err)
	}

	if !priv.Equal(loadedPriv) {
		t.Error("loaded private key does not match original")
	}
	if !pub.Equal(loadedPub) {
		t.Error("loaded public key does not match original")
	}
}

func TestLoadKeyErrors(t *testing.T) {
	// File not found.
	_, err := auth.LoadPublicKey("/nonexistent/key.pem")
	if err == nil {
		t.Error("LoadPublicKey() should error on missing file")
	}

	_, err = auth.LoadPrivateKey("/nonexistent/key.pem")
	if err == nil {
		t.Error("LoadPrivateKey() should error on missing file")
	}

	// Invalid PEM content.
	dir := t.TempDir()
	badPath := filepath.Join(dir, "bad.pem")
	os.WriteFile(badPath, []byte("not a PEM file"), 0644)

	_, err = auth.LoadPublicKey(badPath)
	if err == nil {
		t.Error("LoadPublicKey() should error on invalid PEM")
	}

	_, err = auth.LoadPrivateKey(badPath)
	if err == nil {
		t.Error("LoadPrivateKey() should error on invalid PEM")
	}
}

// ============================================================
//  jwt.go — token generation + validation tests
// ============================================================

func TestAccessTokenRoundTrip(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject: "user-123",
		},
		Roles:    []string{"member", "moderator"},
		DeviceID: "device-abc",
	}

	tok := mustGenerateAccess(t, priv, claims)

	// Validate.
	parsed, err := auth.ValidateToken(keySet, tok)
	if err != nil {
		t.Fatalf("ValidateToken() error = %v", err)
	}
	if parsed.Subject != "user-123" {
		t.Errorf("Subject = %q, want user-123", parsed.Subject)
	}
	if parsed.DeviceID != "device-abc" {
		t.Errorf("DeviceID = %q, want device-abc", parsed.DeviceID)
	}
	if len(parsed.Roles) != 2 || parsed.Roles[0] != "member" {
		t.Errorf("Roles = %v, want [member moderator]", parsed.Roles)
	}
	if parsed.Issuer != "flicko" {
		t.Errorf("Issuer = %q, want flicko", parsed.Issuer)
	}
	if parsed.ID == "" {
		t.Error("Jti (ID) should be auto-generated")
	}
}

func TestRefreshTokenRoundTrip(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	tok, err := auth.GenerateRefreshToken(priv, "user-456", "device-xyz")
	if err != nil {
		t.Fatalf("GenerateRefreshToken() error = %v", err)
	}

	parsed, err := auth.ValidateToken(keySet, tok)
	if err != nil {
		t.Fatalf("ValidateToken() error = %v", err)
	}
	if parsed.Subject != "user-456" {
		t.Errorf("Subject = %q, want user-456", parsed.Subject)
	}
	if parsed.DeviceID != "device-xyz" {
		t.Errorf("DeviceID = %q, want device-xyz", parsed.DeviceID)
	}
}

func TestExpiredTokenRejected(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	// Create a token that already expired.
	now := time.Now().UTC()
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "user-789",
			ID:        "jti-expired",
			IssuedAt:  jwt.NewNumericDate(now.Add(-2 * time.Hour)),
			ExpiresAt: jwt.NewNumericDate(now.Add(-1 * time.Hour)),
			Issuer:    "flicko",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	token.Header["kid"] = auth.KeyIDFromPublic(pub)
	signed, err := token.SignedString(priv)
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}

	_, err = auth.ValidateToken(keySet, signed)
	if err == nil {
		t.Fatal("ValidateToken() should reject expired token")
	}
	if err != auth.ErrExpiredToken {
		t.Errorf("error = %v, want ErrExpiredToken", err)
	}
}

func TestInvalidSignatureRejected(t *testing.T) {
	pub, _ := generateTestKeys(t)
	_, otherPriv := generateTestKeys(t) // different key pair
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject: "user-bad-sig",
		},
	}

	// Sign with otherPriv but validate against pub (wrong key).
	tok := mustGenerateAccess(t, otherPriv, claims)
	_, err := auth.ValidateToken(keySet, tok)
	if err == nil {
		t.Fatal("ValidateToken() should reject invalid signature")
	}
}

func TestMalformedToken(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	_, err := auth.ValidateToken(keySet, "not.a.jwt")
	if err == nil {
		t.Fatal("ValidateToken() should reject malformed token")
	}
}

func TestEmptyToken(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	_, err := auth.ValidateToken(keySet, "")
	if err == nil {
		t.Fatal("ValidateToken() should reject empty token")
	}
}

// ============================================================
//  Key rotation tests
// ============================================================

func TestKeyRotationOldKeyStillValid(t *testing.T) {
	// Simulate key rotation: old key signs token, then new key is added.
	oldPub, oldPriv := generateTestKeys(t)
	newPub, _ := generateTestKeys(t)

	// KeySet with both keys (rotation in progress).
	keySet := auth.NewKeySet(oldPub, newPub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "user-rotated"},
	}
	tok := mustGenerateAccess(t, oldPriv, claims)

	// Token signed with old key should still validate.
	parsed, err := auth.ValidateToken(keySet, tok)
	if err != nil {
		t.Fatalf("ValidateToken() old key during rotation: %v", err)
	}
	if parsed.Subject != "user-rotated" {
		t.Errorf("Subject = %q, want user-rotated", parsed.Subject)
	}
}

func TestKeyRotationNewKeyWorks(t *testing.T) {
	oldPub, _ := generateTestKeys(t)
	newPub, newPriv := generateTestKeys(t)

	keySet := auth.NewKeySet(oldPub, newPub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "user-new-key"},
	}
	tok := mustGenerateAccess(t, newPriv, claims)

	parsed, err := auth.ValidateToken(keySet, tok)
	if err != nil {
		t.Fatalf("ValidateToken() new key: %v", err)
	}
	if parsed.Subject != "user-new-key" {
		t.Errorf("Subject = %q, want user-new-key", parsed.Subject)
	}
}

func TestKeyRotationRemovedKeyRejected(t *testing.T) {
	oldPub, oldPriv := generateTestKeys(t)
	newPub, _ := generateTestKeys(t)

	keySet := auth.NewKeySet(oldPub, newPub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "user-removed"},
	}
	tok := mustGenerateAccess(t, oldPriv, claims)

	// Remove old key (rotation complete).
	oldKID := auth.KeyIDFromPublic(oldPub)
	keySet.Remove(oldKID)

	_, err := auth.ValidateToken(keySet, tok)
	if err == nil {
		t.Fatal("ValidateToken() should reject token after old key is removed")
	}
}

func TestKeySetAddAndLen(t *testing.T) {
	pub1, _ := generateTestKeys(t)
	pub2, _ := generateTestKeys(t)

	ks := auth.NewKeySet(pub1)
	if ks.Len() != 1 {
		t.Fatalf("Len() = %d, want 1", ks.Len())
	}

	ks.Add(pub2)
	if ks.Len() != 2 {
		t.Fatalf("Len() = %d, want 2", ks.Len())
	}
}

func TestKeyIDDeterministic(t *testing.T) {
	pub, _ := generateTestKeys(t)

	kid1 := auth.KeyIDFromPublic(pub)
	kid2 := auth.KeyIDFromPublic(pub)
	if kid1 != kid2 {
		t.Errorf("KeyIDFromPublic() not deterministic: %s != %s", kid1, kid2)
	}
	if len(kid1) != 16 {
		t.Errorf("kid length = %d, want 16 hex chars", len(kid1))
	}
}

// ============================================================
//  context.go tests
// ============================================================

func TestContextRoundTrip(t *testing.T) {
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "ctx-user"},
		DeviceID:         "ctx-device",
		Roles:            []string{"admin"},
	}

	ctx := auth.ContextWithClaims(context.Background(), claims)

	got, err := auth.ClaimsFromContext(ctx)
	if err != nil {
		t.Fatalf("ClaimsFromContext() error = %v", err)
	}
	if got.Subject != "ctx-user" {
		t.Errorf("Subject = %q, want ctx-user", got.Subject)
	}
}

func TestClaimsFromContextMissing(t *testing.T) {
	_, err := auth.ClaimsFromContext(context.Background())
	if err == nil {
		t.Fatal("ClaimsFromContext() should error on empty context")
	}
}

func TestUserIDFromContext(t *testing.T) {
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "uid-123"},
	}
	ctx := auth.ContextWithClaims(context.Background(), claims)

	if uid := auth.UserIDFromContext(ctx); uid != "uid-123" {
		t.Errorf("UserIDFromContext() = %q, want uid-123", uid)
	}

	if uid := auth.UserIDFromContext(context.Background()); uid != "" {
		t.Errorf("UserIDFromContext() without claims = %q, want empty", uid)
	}
}

func TestHasRole(t *testing.T) {
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "role-user"},
		Roles:            []string{"member", "moderator"},
	}
	ctx := auth.ContextWithClaims(context.Background(), claims)

	if !auth.HasRole(ctx, "moderator") {
		t.Error("HasRole(moderator) should be true")
	}
	if auth.HasRole(ctx, "admin") {
		t.Error("HasRole(admin) should be false")
	}
	if auth.HasRole(context.Background(), "member") {
		t.Error("HasRole() without claims should be false")
	}
}

// ============================================================
//  middleware_http.go tests
// ============================================================

func TestHTTPMiddlewareSuccess(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "http-user"},
		Roles:            []string{"member"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	// Protected handler that reads claims from context.
	handler := auth.AuthMiddleware(keySet)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := auth.UserIDFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(uid))
	}))

	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if rec.Body.String() != "http-user" {
		t.Errorf("body = %q, want http-user", rec.Body.String())
	}
}

func TestHTTPMiddlewareMissingHeader(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	handler := auth.AuthMiddleware(keySet)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not be called")
	}))

	req := httptest.NewRequest("GET", "/api/test", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}

	var body map[string]string
	json.NewDecoder(rec.Body).Decode(&body)
	if body["code"] != "UNAUTHORIZED" {
		t.Errorf("code = %q, want UNAUTHORIZED", body["code"])
	}
}

func TestHTTPMiddlewareMalformedBearer(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	handler := auth.AuthMiddleware(keySet)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not be called")
	}))

	tests := []struct {
		name   string
		header string
	}{
		{"no Bearer prefix", "Token abc123"},
		{"empty Bearer", "Bearer "},
		{"Bearer only", "Bearer"},
		{"Basic auth", "Basic dXNlcjpwYXNz"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/api/test", nil)
			req.Header.Set("Authorization", tt.header)
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("status = %d, want 401", rec.Code)
			}
		})
	}
}

func TestHTTPMiddlewareInvalidToken(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	handler := auth.AuthMiddleware(keySet)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not be called")
	}))

	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.invalid.sig")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestHTTPMiddlewareExpiredToken(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	// Manually create an expired token.
	now := time.Now().UTC()
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "expired-user",
			ID:        "jti-exp",
			IssuedAt:  jwt.NewNumericDate(now.Add(-2 * time.Hour)),
			ExpiresAt: jwt.NewNumericDate(now.Add(-1 * time.Hour)),
			Issuer:    "flicko",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	token.Header["kid"] = auth.KeyIDFromPublic(pub)
	tok, _ := token.SignedString(priv)

	handler := auth.AuthMiddleware(keySet)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not be called")
	}))

	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestRequireRoleAllowed(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "admin-user"},
		Roles:            []string{"admin", "member"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	handler := auth.AuthMiddleware(keySet)(
		auth.RequireRole("admin")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})),
	)

	req := httptest.NewRequest("GET", "/admin", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestRequireRoleDenied(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "basic-user"},
		Roles:            []string{"member"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	handler := auth.AuthMiddleware(keySet)(
		auth.RequireRole("admin")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			t.Fatal("handler should not be called")
		})),
	)

	req := httptest.NewRequest("GET", "/admin", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403", rec.Code)
	}
}

// ============================================================
//  middleware_ws.go tests
// ============================================================

func TestValidateIdentifySuccess(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "ws-user"},
		DeviceID:         "ws-device",
	}
	tok := mustGenerateAccess(t, priv, claims)

	parsed, err := auth.ValidateIdentify(keySet, auth.IdentifyPayload{
		Token:    tok,
		DeviceID: "ws-device",
	})
	if err != nil {
		t.Fatalf("ValidateIdentify() error = %v", err)
	}
	if parsed.Subject != "ws-user" {
		t.Errorf("Subject = %q, want ws-user", parsed.Subject)
	}
	if parsed.DeviceID != "ws-device" {
		t.Errorf("DeviceID = %q, want ws-device", parsed.DeviceID)
	}
}

func TestValidateIdentifyEmptyToken(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	_, err := auth.ValidateIdentify(keySet, auth.IdentifyPayload{Token: ""})
	if err == nil {
		t.Fatal("ValidateIdentify() should reject empty token")
	}
}

func TestValidateIdentifyDeviceMismatch(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "ws-user"},
		DeviceID:         "device-A",
	}
	tok := mustGenerateAccess(t, priv, claims)

	_, err := auth.ValidateIdentify(keySet, auth.IdentifyPayload{
		Token:    tok,
		DeviceID: "device-B", // Mismatch!
	})
	if err == nil {
		t.Fatal("ValidateIdentify() should reject device ID mismatch")
	}
}

func TestValidateIdentifyAdoptsDeviceID(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	// Token without DeviceID, payload provides it.
	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "ws-user"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	parsed, err := auth.ValidateIdentify(keySet, auth.IdentifyPayload{
		Token:    tok,
		DeviceID: "adopted-device",
	})
	if err != nil {
		t.Fatalf("ValidateIdentify() error = %v", err)
	}
	if parsed.DeviceID != "adopted-device" {
		t.Errorf("DeviceID = %q, want adopted-device", parsed.DeviceID)
	}
}

func TestIdentifyWithTimeoutSuccess(t *testing.T) {
	pub, priv := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "timeout-user"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	ctx, cancel := context.WithTimeout(context.Background(), auth.IdentifyTimeout)
	defer cancel()

	parsed, err := auth.IdentifyWithTimeout(ctx, keySet, auth.IdentifyPayload{Token: tok})
	if err != nil {
		t.Fatalf("IdentifyWithTimeout() error = %v", err)
	}
	if parsed.Subject != "timeout-user" {
		t.Errorf("Subject = %q, want timeout-user", parsed.Subject)
	}
}

func TestIdentifyWithTimeoutExpired(t *testing.T) {
	pub, _ := generateTestKeys(t)
	keySet := auth.NewKeySet(pub)

	// Already-cancelled context.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := auth.IdentifyWithTimeout(ctx, keySet, auth.IdentifyPayload{Token: "anything"})
	if err == nil {
		t.Fatal("IdentifyWithTimeout() should fail with expired context")
	}
}

// ============================================================
//  TTL constants
// ============================================================

func TestTokenTTLConstants(t *testing.T) {
	if auth.AccessTokenTTL != 15*time.Minute {
		t.Errorf("AccessTokenTTL = %v, want 15m", auth.AccessTokenTTL)
	}
	if auth.RefreshTokenTTL != 30*24*time.Hour {
		t.Errorf("RefreshTokenTTL = %v, want 30d", auth.RefreshTokenTTL)
	}
	if auth.IdentifyTimeout != 5*time.Second {
		t.Errorf("IdentifyTimeout = %v, want 5s", auth.IdentifyTimeout)
	}
}

// ============================================================
//  ValidateTokenSingleKey convenience
// ============================================================

func TestValidateTokenSingleKey(t *testing.T) {
	pub, priv := generateTestKeys(t)

	claims := &auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{Subject: "single-key-user"},
	}
	tok := mustGenerateAccess(t, priv, claims)

	parsed, err := auth.ValidateTokenSingleKey(pub, tok)
	if err != nil {
		t.Fatalf("ValidateTokenSingleKey() error = %v", err)
	}
	if parsed.Subject != "single-key-user" {
		t.Errorf("Subject = %q, want single-key-user", parsed.Subject)
	}
}
