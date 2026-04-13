// Package auth provides Ed25519 (EdDSA) JWT authentication for all Flicko
// microservices. It supports key rotation via Key ID (kid) headers and
// provides both HTTP middleware (msg-service) and WebSocket validation
// (ws-gateway) integrations.
package auth

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
)

// LoadPublicKey reads a PEM-encoded Ed25519 public key from disk.
//
// Expected PEM block type: "PUBLIC KEY" (PKIX/SubjectPublicKeyInfo format).
// Use: openssl pkey -in private.pem -pubout -out public.pem
func LoadPublicKey(path string) (ed25519.PublicKey, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("auth: read public key %s: %w", path, err)
	}

	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("auth: no PEM block found in %s", path)
	}
	if block.Type != "PUBLIC KEY" {
		return nil, fmt.Errorf("auth: unexpected PEM type %q in %s (want PUBLIC KEY)", block.Type, path)
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("auth: parse public key %s: %w", path, err)
	}

	edPub, ok := pub.(ed25519.PublicKey)
	if !ok {
		return nil, fmt.Errorf("auth: key in %s is not Ed25519 (got %T)", path, pub)
	}
	return edPub, nil
}

// LoadPrivateKey reads a PEM-encoded Ed25519 private key from disk.
//
// Expected PEM block type: "PRIVATE KEY" (PKCS8 format).
// Use: openssl genpkey -algorithm Ed25519 -out private.pem
func LoadPrivateKey(path string) (ed25519.PrivateKey, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("auth: read private key %s: %w", path, err)
	}

	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("auth: no PEM block found in %s", path)
	}
	if block.Type != "PRIVATE KEY" {
		return nil, fmt.Errorf("auth: unexpected PEM type %q in %s (want PRIVATE KEY)", block.Type, path)
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("auth: parse private key %s: %w", path, err)
	}

	edKey, ok := key.(ed25519.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("auth: key in %s is not Ed25519 (got %T)", path, key)
	}
	return edKey, nil
}

// GenerateKeyPair creates a new Ed25519 key pair.
//
// WARNING: For setup scripts and testing only. In production, keys should
// be generated offline and stored securely (e.g. via scripts/generate-jwt-keys.sh).
func GenerateKeyPair() (ed25519.PublicKey, ed25519.PrivateKey, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, fmt.Errorf("auth: generate key pair: %w", err)
	}
	return pub, priv, nil
}

// MarshalPrivateKeyPEM encodes an Ed25519 private key to PEM (PKCS8).
func MarshalPrivateKeyPEM(key ed25519.PrivateKey) ([]byte, error) {
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, fmt.Errorf("auth: marshal private key: %w", err)
	}
	return pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: der,
	}), nil
}

// MarshalPublicKeyPEM encodes an Ed25519 public key to PEM (PKIX).
func MarshalPublicKeyPEM(key ed25519.PublicKey) ([]byte, error) {
	der, err := x509.MarshalPKIXPublicKey(key)
	if err != nil {
		return nil, fmt.Errorf("auth: marshal public key: %w", err)
	}
	return pem.EncodeToMemory(&pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: der,
	}), nil
}
