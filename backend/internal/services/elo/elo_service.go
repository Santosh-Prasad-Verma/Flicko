package elo

import "math"

// ELOService manages ELO rating calculations
type ELOService interface {
	CalculateELO(winnerELO, loserELO int) (int, int)
	CalculateELODraw(playerAELO, playerBELO int) (int, int)
}

type eloService struct {
	kFactor float64
}

func NewELOService(kFactor float64) ELOService {
	// Standard K-Factor is often 32
	if kFactor <= 0 {
		kFactor = 32.0
	}
	return &eloService{kFactor: kFactor}
}

// expectedScore returns the expected probability of player A beating player B
func expectedScore(ratingA, ratingB int) float64 {
	exponent := float64(ratingB-ratingA) / 400.0
	return 1.0 / (1.0 + math.Pow(10, exponent))
}

// CalculateELO computes the new ELOs for a winner and a loser.
// Uses math.Round to avoid integer truncation bias and ensures a strict zero-sum exchange.
func (s *eloService) CalculateELO(winnerELO, loserELO int) (newWinner, newLoser int) {
	expectedWinner := expectedScore(winnerELO, loserELO)
	
	// Winner actual score = 1.0, Loser actual score = 0.0
	delta := math.Round(s.kFactor * (1.0 - expectedWinner))
	
	newWinner = winnerELO + int(delta)
	newLoser = loserELO - int(delta) // strictly zero-sum
	
	// ELO floor to prevent negative ratings (optional but good practice)
	if newLoser < 0 {
		newLoser = 0
	}
	
	return newWinner, newLoser
}

// CalculateELODraw computes the new ELOs in the event of a draw.
func (s *eloService) CalculateELODraw(playerAELO, playerBELO int) (newPlayerA, newPlayerB int) {
	expectedA := expectedScore(playerAELO, playerBELO)
	
	// Draw actual score = 0.5
	delta := math.Round(s.kFactor * (0.5 - expectedA))
	
	newPlayerA = playerAELO + int(delta)
	newPlayerB = playerBELO - int(delta) // strictly zero-sum
	
	if newPlayerA < 0 {
		newPlayerA = 0
	}
	if newPlayerB < 0 {
		newPlayerB = 0
	}
	
	return newPlayerA, newPlayerB
}
