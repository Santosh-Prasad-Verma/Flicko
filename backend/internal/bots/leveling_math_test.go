package bots

import (
	"math/rand"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestLevelForXP_BoundaryConditions checks the closed-form HIGH-5 inverse
// matches the original quadratic at exact level boundaries.
func TestLevelForXP_BoundaryConditions(t *testing.T) {
	// Below level 1: anything <100 XP is level 0.
	for xp := 0; xp < 100; xp++ {
		assert.Equal(t, 0, levelForXP(xp), "xp=%d should map to level 0", xp)
	}

	// At each level boundary, levelForXP(xpForLevel(L)) MUST equal L.
	for L := 1; L < 100; L++ {
		threshold := xpForLevel(L)
		got := levelForXP(threshold)
		assert.Equal(t, L, got, "levelForXP(xpForLevel(%d))=%d but expected %d (threshold=%d)",
			L, got, L, threshold)
	}

	// One XP below a threshold should still be the previous level.
	for L := 2; L < 100; L++ {
		threshold := xpForLevel(L)
		got := levelForXP(threshold - 1)
		assert.Equal(t, L-1, got, "levelForXP(threshold-1) for L=%d should be %d (threshold=%d)", L, L-1, threshold)
	}
}

// TestLevelForXP_MatchesOldImpl is a property-style test: the closed-form
// inverse must agree with the original O(level) loop on a swath of values.
func TestLevelForXP_MatchesOldImpl(t *testing.T) {
	oldImpl := func(xp int) int {
		level := 0
		for xpForLevel(level+1) <= xp {
			level++
		}
		if level > 1000 {
			level = 1000
		}
		return level
	}

	rng := rand.New(rand.NewSource(42))
	for i := 0; i < 1000; i++ {
		xp := rng.Intn(5_000_000)
		fast := levelForXP(xp)
		slow := oldImpl(xp)
		assert.Equal(t, slow, fast, "mismatch for xp=%d: slow=%d fast=%d", xp, slow, fast)
	}
}

// TestLevelForXP_NeverExceedsCap checks the safety cap.
func TestLevelForXP_NeverExceedsCap(t *testing.T) {
	got := levelForXP(1 << 30) // huge value
	assert.LessOrEqual(t, got, 1000, "level should be capped at 1000")
}

// TestLevelForXP_NegativeIsZero gracefully handles unexpected inputs.
func TestLevelForXP_NegativeIsZero(t *testing.T) {
	assert.Equal(t, 0, levelForXP(-5))
	assert.Equal(t, 0, levelForXP(-100000))
}

// TestXpForLevel_Monotonic ensures the threshold function is strictly
// monotonically increasing — required for levelForXP to be unambiguous.
func TestXpForLevel_Monotonic(t *testing.T) {
	prev := xpForLevel(0)
	for L := 1; L <= 100; L++ {
		curr := xpForLevel(L)
		assert.Greater(t, curr, prev, "xpForLevel(%d)=%d should be > xpForLevel(%d)=%d", L, curr, L-1, prev)
		prev = curr
	}
}
