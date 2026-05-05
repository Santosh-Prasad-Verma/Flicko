package handlers

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/razorpay/razorpay-go"
	"go.uber.org/zap"
)

const (
	nitroBasicPlan = "nitro_basic"
	nitroFullPlan  = "nitro_full"
)

type PremiumHandler struct {
	db          *pgxpool.Pool
	logger      *zap.Logger
	mailService *services.MailService
	rzpKeyID    string
	rzpSecret   string
	rzpClient   *razorpay.Client
}

type createGiftRequest struct {
	Plan         string `json:"plan"`
	DurationDays int    `json:"duration_days,omitempty"`
}

type redeemGiftRequest struct {
	Code string `json:"code"`
}

type applyBoostCreditRequest struct {
	ServerID string `json:"server_id"`
}

type createOrderRequest struct {
	Plan string `json:"plan"` // "nitro_basic" or "nitro_full"
}

type verifyPaymentRequest struct {
	OrderID   string `json:"razorpay_order_id"`
	PaymentID string `json:"razorpay_payment_id"`
	Signature string `json:"razorpay_signature"`
	Plan      string `json:"plan"`
}

type boostCreditResponse struct {
	ID                 string     `json:"id"`
	IssuedAt           time.Time  `json:"issued_at"`
	ExpiresAt          time.Time  `json:"expires_at"`
	ConsumedAt         *time.Time `json:"consumed_at,omitempty"`
	ConsumedByServerID *string    `json:"consumed_by_server_id,omitempty"`
	Source             string     `json:"source"`
}

type applyCosmeticRequest struct {
	CosmeticID string `json:"cosmetic_id"`
}

func NewPremiumHandler(db *pgxpool.Pool, logger *zap.Logger, mailSvc *services.MailService, rzpID, rzpSecret string) *PremiumHandler {
	client := razorpay.NewClient(rzpID, rzpSecret)
	return &PremiumHandler{
		db:          db,
		logger:      logger.Named("handler.premium"),
		mailService: mailSvc,
		rzpKeyID:    rzpID,
		rzpSecret:   rzpSecret,
		rzpClient:   client,
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

func (h *PremiumHandler) GetBoostCredits(w http.ResponseWriter, r *http.Request) {
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

	rows, err := h.db.Query(r.Context(), `
		SELECT id, issued_at, expires_at, consumed_at, consumed_by_server_id, source
		FROM public.boost_credits
		WHERE user_id = $1
		ORDER BY issued_at DESC
	`, userUUID)
	if err != nil {
		h.logger.Error("failed to list boost credits", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch boost credits")
		return
	}
	defer rows.Close()

	credits := make([]boostCreditResponse, 0)
	available := 0
	consumed := 0
	now := time.Now().UTC()
	for rows.Next() {
		var item boostCreditResponse
		var id uuid.UUID
		var consumedByServerID *uuid.UUID
		if err = rows.Scan(&id, &item.IssuedAt, &item.ExpiresAt, &item.ConsumedAt, &consumedByServerID, &item.Source); err != nil {
			h.logger.Error("failed to scan boost credit row", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to fetch boost credits")
			return
		}
		item.ID = id.String()
		if consumedByServerID != nil {
			serverID := consumedByServerID.String()
			item.ConsumedByServerID = &serverID
		}
		if item.ConsumedAt == nil && item.ExpiresAt.After(now) {
			available++
		} else {
			consumed++
		}
		credits = append(credits, item)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("boost credits row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch boost credits")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":           userUUID.String(),
		"available_credits": available,
		"used_credits":      consumed,
		"total_credits":     len(credits),
		"credits":           credits,
	})
}

func (h *PremiumHandler) ApplyBoostCredit(w http.ResponseWriter, r *http.Request) {
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

	req := applyBoostCreditRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	serverUUID, err := uuid.Parse(req.ServerID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}

	var isMember bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.server_members
			WHERE server_id = $1
			  AND user_id = $2
		)
	`, serverUUID, userUUID).Scan(&isMember); err != nil {
		h.logger.Error("failed to verify server membership for boost apply", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin boost apply transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var creditID uuid.UUID
	err = tx.QueryRow(r.Context(), `
		SELECT id
		FROM public.boost_credits
		WHERE user_id = $1
		  AND consumed_at IS NULL
		  AND expires_at > NOW()
		ORDER BY issued_at ASC
		LIMIT 1
		FOR UPDATE
	`, userUUID).Scan(&creditID)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusConflict, "no available boost credits")
		return
	}
	if err != nil {
		h.logger.Error("failed to locate available boost credit", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}

	var consumedAt time.Time
	if err = tx.QueryRow(r.Context(), `
		UPDATE public.boost_credits
		SET consumed_at = NOW(),
		    consumed_by_server_id = $2,
		    updated_at = NOW()
		WHERE id = $1
		RETURNING consumed_at
	`, creditID, serverUUID).Scan(&consumedAt); err != nil {
		h.logger.Error("failed to consume boost credit", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}

	var serverBoostID uuid.UUID
	var boostExpiresAt time.Time
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.server_boosts (
			server_id, user_id, started_at, expires_at, is_active
		)
		VALUES ($1, $2, NOW(), NOW() + INTERVAL '30 days', TRUE)
		RETURNING id, expires_at
	`, serverUUID, userUUID).Scan(&serverBoostID, &boostExpiresAt); err != nil {
		h.logger.Error("failed to create server boost from credit", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit boost apply transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply boost credit")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"boost_credit_id": creditID.String(),
		"server_boost_id": serverBoostID.String(),
		"server_id":       serverUUID.String(),
		"user_id":         userUUID.String(),
		"consumed_at":     consumedAt,
		"expires_at":      boostExpiresAt,
		"status":          "applied",
	})
}

func (h *PremiumHandler) ListCosmetics(w http.ResponseWriter, r *http.Request) {
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

	rows, err := h.db.Query(r.Context(), `
		SELECT
			cc.id,
			cc.slug,
			cc.name,
			cc.cosmetic_type,
			cc.asset_url,
			cc.rarity,
			cc.required_plan,
			cc.is_active,
			uc.id IS NOT NULL AS owned,
			COALESCE(uc.is_equipped, FALSE) AS equipped,
			uc.unlocked_at
		FROM public.cosmetic_catalog cc
		LEFT JOIN public.user_cosmetics uc
		  ON uc.cosmetic_id = cc.id
		 AND uc.user_id = $1
		WHERE cc.is_active = TRUE
		ORDER BY cc.cosmetic_type ASC, cc.rarity DESC, cc.name ASC
	`, userUUID)
	if err != nil {
		h.logger.Error("failed to list cosmetics catalog", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch cosmetics")
		return
	}
	defer rows.Close()

	items := make([]map[string]interface{}, 0)
	for rows.Next() {
		var cosmeticID uuid.UUID
		var slug, name, cosmeticType, assetURL, rarity string
		var requiredPlan *string
		var isActive, owned, equipped bool
		var unlockedAt *time.Time
		if err = rows.Scan(
			&cosmeticID, &slug, &name, &cosmeticType, &assetURL, &rarity,
			&requiredPlan, &isActive, &owned, &equipped, &unlockedAt,
		); err != nil {
			h.logger.Error("failed to scan cosmetic row", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to fetch cosmetics")
			return
		}
		items = append(items, map[string]interface{}{
			"id":            cosmeticID.String(),
			"slug":          slug,
			"name":          name,
			"type":          cosmeticType,
			"asset_url":     assetURL,
			"rarity":        rarity,
			"required_plan": requiredPlan,
			"is_active":     isActive,
			"owned":         owned,
			"equipped":      equipped,
			"unlocked_at":   unlockedAt,
		})
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("cosmetics row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch cosmetics")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":   userUUID.String(),
		"cosmetics": items,
		"count":     len(items),
	})
}

func (h *PremiumHandler) ApplyCosmetic(w http.ResponseWriter, r *http.Request) {
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

	req := applyCosmeticRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	cosmeticUUID, err := uuid.Parse(req.CosmeticID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid cosmetic id")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin apply cosmetic transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply cosmetic")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var cosmeticType string
	var owned bool
	err = tx.QueryRow(r.Context(), `
		SELECT cc.cosmetic_type, uc.id IS NOT NULL AS owned
		FROM public.cosmetic_catalog cc
		LEFT JOIN public.user_cosmetics uc
		  ON uc.cosmetic_id = cc.id
		 AND uc.user_id = $2
		WHERE cc.id = $1
		  AND cc.is_active = TRUE
	`, cosmeticUUID, userUUID).Scan(&cosmeticType, &owned)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "cosmetic not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to query cosmetic ownership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply cosmetic")
		return
	}
	if !owned {
		writeError(w, http.StatusForbidden, "cosmetic is not owned")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.user_cosmetics uc
		SET is_equipped = FALSE,
		    updated_at = NOW()
		FROM public.cosmetic_catalog cc
		WHERE uc.cosmetic_id = cc.id
		  AND uc.user_id = $1
		  AND cc.cosmetic_type = $2
	`, userUUID, cosmeticType); err != nil {
		h.logger.Error("failed to clear equipped cosmetics", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply cosmetic")
		return
	}

	var updatedAt time.Time
	if err = tx.QueryRow(r.Context(), `
		UPDATE public.user_cosmetics
		SET is_equipped = TRUE,
		    updated_at = NOW()
		WHERE user_id = $1
		  AND cosmetic_id = $2
		RETURNING updated_at
	`, userUUID, cosmeticUUID).Scan(&updatedAt); err != nil {
		h.logger.Error("failed to set equipped cosmetic", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply cosmetic")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit apply cosmetic transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to apply cosmetic")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":     userUUID.String(),
		"cosmetic_id": cosmeticUUID.String(),
		"type":        cosmeticType,
		"equipped":    true,
		"updated_at":  updatedAt,
	})
}

func (h *PremiumHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	req := createOrderRequest{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}

	amount := 29900 // Default 299 INR in paise
	if req.Plan == nitroFullPlan {
		amount = 99900
	}

	data := map[string]interface{}{
		"amount":          amount,
		"currency":        "INR",
		"receipt":         uuid.New().String(),
		"partial_payment": false,
		"notes": map[string]interface{}{
			"user_id": userID,
			"plan":    req.Plan,
		},
	}

	body, err := h.rzpClient.Order.Create(data, nil)
	if err != nil {
		h.logger.Error("failed to create razorpay order", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to initiate payment")
		return
	}

	// The Razorpay SDK returns the body as a map[string]interface{}
	// We need to extract the order ID from it.
	orderID, ok := body["id"].(string)
	if !ok {
		h.logger.Error("razorpay response missing order id", zap.Any("body", body))
		writeError(w, http.StatusInternalServerError, "failed to initiate payment")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"order_id": orderID,
		"amount":   amount,
		"currency": "INR",
		"key_id":   h.rzpKeyID,
	})
}

func (h *PremiumHandler) VerifyPayment(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, _ := uuid.Parse(userID)

	req := verifyPaymentRequest{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}

	// Verify Signature
	// Generated Signature = hmac_sha256(order_id + "|" + payment_id, secret)
	data := req.OrderID + "|" + req.PaymentID
	mac := hmac.New(sha256.New, []byte(h.rzpSecret))
	mac.Write([]byte(data))
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	if expectedSignature != req.Signature {
		h.logger.Warn("invalid payment signature", 
			zap.String("user", userID), 
			zap.String("order", req.OrderID))
		writeError(w, http.StatusBadRequest, "invalid signature")
		return
	}

	// Grant Premium
	duration := 30 // days
	plan := req.Plan
	if plan == "" {
		plan = nitroBasicPlan
	}

	_, err := h.db.Exec(r.Context(), `
		INSERT INTO public.entitlements (user_id, type, source, source_id, granted_at, expires_at, revoked)
		VALUES ($1, $2, 'payment', $3, NOW(), NOW() + ($4 * INTERVAL '1 day'), FALSE)
	`, userUUID, plan, req.PaymentID, duration)

	if err != nil {
		h.logger.Error("failed to grant premium entitlement", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal error")
		return
	}

	// Send Confirmation Email
	// In a real app, we'd fetch the user's email from the DB first
	var email, username string
	err = h.db.QueryRow(r.Context(), "SELECT email, username FROM public.users WHERE id = $1", userUUID).Scan(&email, &username)
	if err == nil {
		amountStr := "₹299.00"
		if plan == nitroFullPlan {
			amountStr = "₹999.00"
		}
		
		go func() {
			if err := h.mailService.SendFlickoPlusConfirmation(email, username, req.PaymentID, amountStr); err != nil {
				h.logger.Error("failed to send payment confirmation email", zap.Error(err))
			}
		}()
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "success",
		"plan":   plan,
	})
}

func generateGiftCode() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return strings.ToUpper(hex.EncodeToString(b)), nil
}

