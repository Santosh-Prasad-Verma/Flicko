package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	nitroBasicPlan = "nitro_basic"
	nitroFullPlan  = "nitro_full"
)

type PremiumHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type createGiftRequest struct {
	Plan         string `json:"plan"`
	DurationDays int    `json:"duration_days,omitempty"`
}

type redeemGiftRequest struct {
	Code string `json:"code"`
}

func NewPremiumHandler(db *pgxpool.Pool, logger *zap.Logger) *PremiumHandler {
	return &PremiumHandler{
		db:     db,
		logger: logger.Named("handler.premium"),
	}
}

func (h *PremiumHandler) CreateGift(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := createGiftRequest{
		Plan:         nitroBasicPlan,
		DurationDays: 30,
	}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Plan = strings.TrimSpace(req.Plan)
	if req.Plan == "" {
		req.Plan = nitroBasicPlan
	}
	if req.Plan != nitroBasicPlan && req.Plan != nitroFullPlan {
		writeError(w, http.StatusBadRequest, "plan must be nitro_basic or nitro_full")
		return
	}
	if req.DurationDays <= 0 {
		req.DurationDays = 30
	}
	if req.DurationDays > 365 {
		writeError(w, http.StatusBadRequest, "duration_days must be between 1 and 365")
		return
	}

	code, err := generateGiftCode()
	if err != nil {
		h.logger.Error("failed to generate gift code", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create premium gift")
		return
	}
	priceCents := 299
	if req.Plan == nitroFullPlan {
		priceCents = 999
	}

	var giftID uuid.UUID
	var expiresAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.gift_transactions (
			purchaser_id, plan, duration_days, price_cents, currency, gift_code, status, expires_at
		)
		VALUES ($1, $2, $3, $4, 'usd', $5, 'issued', NOW() + INTERVAL '30 days')
		RETURNING id, expires_at
	`, userUUID, req.Plan, req.DurationDays, priceCents, code).Scan(&giftID, &expiresAt); err != nil {
		h.logger.Error("failed to create gift transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create premium gift")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":            giftID.String(),
		"gift_code":     code,
		"plan":          req.Plan,
		"duration_days": req.DurationDays,
		"price_cents":   priceCents,
		"currency":      "usd",
		"expires_at":    expiresAt,
		"status":        "issued",
	})
}

func (h *PremiumHandler) RedeemGift(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := redeemGiftRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Code = strings.ToUpper(strings.TrimSpace(req.Code))
	if req.Code == "" {
		writeError(w, http.StatusBadRequest, "code is required")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin redeem transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var giftID uuid.UUID
	var purchaserID uuid.UUID
	var plan string
	var durationDays int
	var status string
	var expiresAt time.Time
	err = tx.QueryRow(r.Context(), `
		SELECT id, purchaser_id, plan, duration_days, status, expires_at
		FROM public.gift_transactions
		WHERE gift_code = $1
		FOR UPDATE
	`, req.Code).Scan(&giftID, &purchaserID, &plan, &durationDays, &status, &expiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "gift code not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to query gift transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}

	if purchaserID == userUUID {
		writeError(w, http.StatusBadRequest, "cannot redeem your own gift")
		return
	}
	if status != "issued" {
		writeError(w, http.StatusConflict, "gift code is no longer redeemable")
		return
	}
	if time.Now().UTC().After(expiresAt) {
		if _, err = tx.Exec(r.Context(), `
			UPDATE public.gift_transactions
			SET status = 'expired',
			    updated_at = NOW()
			WHERE id = $1
		`, giftID); err != nil {
			h.logger.Error("failed to expire gift transaction", zap.Error(err))
		}
		writeError(w, http.StatusConflict, "gift code has expired")
		return
	}

	var entitlementID uuid.UUID
	var entitlementExpiresAt time.Time
	err = tx.QueryRow(r.Context(), `
		INSERT INTO public.entitlements (user_id, type, source, source_id, granted_at, expires_at, revoked)
		VALUES ($1, $2, 'gift', $3, NOW(), NOW() + ($4 * INTERVAL '1 day'), FALSE)
		RETURNING id, expires_at
	`, userUUID, plan, giftID, durationDays).Scan(&entitlementID, &entitlementExpiresAt)
	if err != nil {
		h.logger.Error("failed to create entitlement from gift redemption", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}

	var redemptionID uuid.UUID
	var redeemedAt time.Time
	err = tx.QueryRow(r.Context(), `
		INSERT INTO public.gift_redemptions (gift_transaction_id, redeemer_id, entitlement_id, redeemed_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id, redeemed_at
	`, giftID, userUUID, entitlementID).Scan(&redemptionID, &redeemedAt)
	if err != nil {
		h.logger.Error("failed to create gift redemption", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.gift_transactions
		SET status = 'redeemed',
		    redeemed_at = NOW(),
		    redeemed_by = $2,
		    updated_at = NOW()
		WHERE id = $1
	`, giftID, userUUID); err != nil {
		h.logger.Error("failed to update redeemed gift transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit gift redemption transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to redeem premium gift")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"gift_transaction_id": giftID.String(),
		"gift_redemption_id":  redemptionID.String(),
		"entitlement_id":      entitlementID.String(),
		"plan":                plan,
		"redeemed_at":         redeemedAt,
		"entitlement_expires": entitlementExpiresAt,
		"status":              "redeemed",
	})
}

func generateGiftCode() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return strings.ToUpper(hex.EncodeToString(b)), nil
}
