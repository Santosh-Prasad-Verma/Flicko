// Package music provides Sonic Drip music integration services.
package music

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"errors"
	"io"
)

// EncryptionService encrypts/decrypts Spotify session cookies using AES-256-GCM.
// We store ONLY session cookies — never passwords.
type EncryptionService struct {
	key []byte // 32-byte AES-256 key
}

// NewEncryptionService creates an EncryptionService with the given 32-byte key.
func NewEncryptionService(key []byte) (*EncryptionService, error) {
	if len(key) != 32 {
		return nil, errors.New("encryption key must be exactly 32 bytes")
	}
	return &EncryptionService{key: key}, nil
}

// Encrypt serialises v to JSON then encrypts with AES-256-GCM.
// Returns ciphertext with a prepended 12-byte nonce.
func (e *EncryptionService) Encrypt(v any) ([]byte, error) {
	plaintext, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(e.key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	// nonce || ciphertext
	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

// Decrypt reverses Encrypt, unmarshalling the result into dst.
func (e *EncryptionService) Decrypt(ciphertext []byte, dst any) error {
	block, err := aes.NewCipher(e.key)
	if err != nil {
		return err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return errors.New("ciphertext too short")
	}

	nonce, data := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, data, nil)
	if err != nil {
		return err
	}

	return json.Unmarshal(plaintext, dst)
}
