package game

import (
	"errors"

	"github.com/flicko-org/flicko-backend/internal/services/rng"
)

// SafeSquares mapping standard classic Ludo safe spots on a 52-tile board
var SafeSquares = map[int]bool{
	0:  true, // Player 1 start
	8:  true, // Star
	13: true, // Player 2 start
	21: true, // Star
	26: true, // Player 3 start
	34: true, // Star
	39: true, // Player 4 start
	47: true, // Star
}

// Token represents a single Ludo piece moving along the 1D perimeter
type Token struct {
	ID               int    `json:"id"`
	PlayerID         string `json:"player_id"`
	ColorOffset      int    `json:"color_offset"`      // 0, 13, 26, 39 (Entry point offsets)
	ProgressionIndex int    `json:"progression_index"` // -1 = base, 0-50 = perimeter, 51-56 = home run, 57 = finished
}

// TurnState tracks the active dice roll for a turn, detached from the user payload to prevent forgery
type TurnState struct {
	DiceValue  int    `json:"dice_value"`
	RollID     string `json:"roll_id"`
	IsConsumed bool   `json:"is_consumed"`
}

type LudoValidator struct {
	rngService rng.RNGService
}

func NewLudoValidator(rngSvc rng.RNGService) *LudoValidator {
	return &LudoValidator{
		rngService: rngSvc,
	}
}

// ValidateMove strictly verifies Ludo rules including base-exits, safe zones, and capturing.
func (v *LudoValidator) ValidateMove(token *Token, turn *TurnState, boardTokens []*Token) error {
	if turn.IsConsumed {
		return errors.New("dice value already consumed or invalid")
	}

	// Exit base logic
	if token.ProgressionIndex == -1 {
		if turn.DiceValue != 6 {
			return errors.New("must roll a 6 to exit base")
		}
		token.ProgressionIndex = 0
	} else {
		// Normal progression
		newProgression := token.ProgressionIndex + turn.DiceValue
		if newProgression > 57 {
			return errors.New("move exceeds home limit, bounce not supported in this ruleset")
		}
		token.ProgressionIndex = newProgression
	}

	// Capture evaluation (Only active on the 0-50 main perimeter)
	if token.ProgressionIndex <= 50 && token.ProgressionIndex >= 0 {
		physicalPos := (token.ColorOffset + token.ProgressionIndex) % 52

		for _, otherToken := range boardTokens {
			// Skip self or base/home tokens
			if otherToken.PlayerID == token.PlayerID {
				continue
			}
			if otherToken.ProgressionIndex < 0 || otherToken.ProgressionIndex > 50 {
				continue
			}

			// Map opponent's physical position via the same Modulo 52 function
			otherPhysical := (otherToken.ColorOffset + otherToken.ProgressionIndex) % 52

			// Collision detected
			if physicalPos == otherPhysical {
				if SafeSquares[physicalPos] {
					continue // Cannot capture on a star/entry safe zone
				}
				// Force opponent token back to base
				otherToken.ProgressionIndex = -1
			}
		}
	}

	// Invalidate the turn state to strictly prevent replay attacks
	turn.IsConsumed = true
	return nil
}

// GetPhysicalPosition converts the unified progression index into the rendering index for UI clients
func (v *LudoValidator) GetPhysicalPosition(token *Token) int {
	if token.ProgressionIndex < 0 {
		return -1 // Rendering offset for base
	}
	if token.ProgressionIndex > 50 {
		return 100 + token.ProgressionIndex // Rendering offset for home stretch
	}
	return (token.ColorOffset + token.ProgressionIndex) % 52
}
