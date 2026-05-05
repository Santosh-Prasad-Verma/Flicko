package rng

import (
	"crypto/rand"
	"math/big"
)

// RNGService provides cryptographically secure random number generation
type RNGService interface {
	DiceRoll(sides int) (int, error)
}

type secureRNGService struct{}

func NewRNGService() RNGService {
	return &secureRNGService{}
}

// DiceRoll strictly uses crypto/rand. Returns a 1-based roll.
// It never uses math/rand to prevent PRNG predictability attacks.
func (s *secureRNGService) DiceRoll(sides int) (int, error) {
	if sides <= 0 {
		return 0, nil
	}
	// generate a random number [0, sides)
	n, err := rand.Int(rand.Reader, big.NewInt(int64(sides)))
	if err != nil {
		return 0, err
	}
	// return 1-indexed roll [1, sides]
	return int(n.Int64()) + 1, nil
}
