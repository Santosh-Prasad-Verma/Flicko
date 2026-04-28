package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"sync"
	"time"
)

const (
	SignatureHeader  = "X-Flicko-Signature"
	TimestampHeader  = "X-Flicko-Timestamp"
	NonceHeader      = "X-Flicko-Nonce"
	MaxTimestampSkew = 5 * time.Minute
	NonceWindowSize  = 10 * time.Minute
)

var (
	ErrInvalidSignature = errors.New("invalid webhook signature")
	ErrTimestampExpired = errors.New("timestamp outside acceptable window")
	ErrNonceReplayed    = errors.New("nonce already seen — replay attack detected")
	ErrMissingHeaders   = errors.New("missing required security headers")
)

type NonceStore struct {
	mu         sync.RWMutex
	current    map[string]time.Time
	previous   map[string]time.Time
	rotatedAt  time.Time
	windowSize time.Duration
}

func NewNonceStore(windowSize time.Duration) *NonceStore {
	return &NonceStore{
		current:    make(map[string]time.Time),
		previous:   make(map[string]time.Time),
		rotatedAt:  time.Now(),
		windowSize: windowSize,
	}
}

func (ns *NonceStore) CheckAndStore(nonce string) error {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	if time.Since(ns.rotatedAt) > ns.windowSize {
		ns.previous = ns.current
		ns.current = make(map[string]time.Time)
		ns.rotatedAt = time.Now()
	}

	if _, exists := ns.current[nonce]; exists {
		return ErrNonceReplayed
	}
	if _, exists := ns.previous[nonce]; exists {
		return ErrNonceReplayed
	}

	ns.current[nonce] = time.Now()
	return nil
}

type Signer struct {
	nonceStore *NonceStore
}

func NewSigner() *Signer {
	return &Signer{
		nonceStore: NewNonceStore(NonceWindowSize),
	}
}

func (s *Signer) Sign(secret string, body []byte) (map[string]string, error) {
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)

	nonce := make([]byte, 16)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("nonce generation failed: %w", err)
	}
	nonceHex := hex.EncodeToString(nonce)

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(timestamp))
	mac.Write([]byte("."))
	mac.Write([]byte(nonceHex))
	mac.Write([]byte("."))
	mac.Write(body)
	sig := hex.EncodeToString(mac.Sum(nil))

	return map[string]string{
		SignatureHeader: "sha256=" + sig,
		TimestampHeader: timestamp,
		NonceHeader:     nonceHex,
	}, nil
}

func (s *Signer) Verify(secret string, body []byte, headers map[string]string) error {
	sig, ok1 := headers[SignatureHeader]
	tsStr, ok2 := headers[TimestampHeader]
	nonce, ok3 := headers[NonceHeader]
	if !ok1 || !ok2 || !ok3 {
		return ErrMissingHeaders
	}

	ts, err := strconv.ParseInt(tsStr, 10, 64)
	if err != nil {
		return ErrTimestampExpired
	}
	skew := time.Since(time.Unix(ts, 0)).Abs()
	if skew > MaxTimestampSkew {
		return ErrTimestampExpired
	}

	if err := s.nonceStore.CheckAndStore(nonce); err != nil {
		return err
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(tsStr))
	mac.Write([]byte("."))
	mac.Write([]byte(nonce))
	mac.Write([]byte("."))
	mac.Write(body)
	expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(sig), []byte(expected)) {
		return ErrInvalidSignature
	}
	return nil
}
