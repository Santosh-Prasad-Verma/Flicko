package handlers

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base32"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type MFAHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

const (
	totpPeriodSeconds int64 = 30
	totpDigits        int   = 6
	totpSkewWindows   int64 = 1
)

func NewMFAHandler(db *pgxpool.Pool, logger *zap.Logger) *MFAHandler {
	return &MFAHandler{
		db:     db,
		logger: logger.Named("handler.mfa"),
	}
}

type mfaEnrollResponse struct {
	FactorID        string `json:"factor_id"`
	Secret          string `json:"secret"`
	ProvisioningURI string `json:"provisioning_uri"`
}

type mfaVerifyRequest struct {
	Code string `json:"code"`
}

type mfaVerifyResponse struct {
	Status        string   `json:"status"`
	MFAEnabled    bool     `json:"mfa_enabled"`
	RecoveryCodes []string `json:"recovery_codes,omitempty"`
}

type mfaDisableRequest struct {
	Code         string `json:"code"`
	RecoveryCode string `json:"recovery_code"`
}

func (h *MFAHandler) Enroll(w http.ResponseWriter, r *http.Request) {
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

	secret, err := generateTOTPSecret()
	if err != nil {
		h.logger.Error("failed to generate totp secret", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to enroll mfa")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin mfa enroll transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to enroll mfa")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.mfa_factors
		SET enabled = false,
		    disabled_at = NOW(),
		    updated_at = NOW()
		WHERE user_id = $1
		  AND factor_type = 'totp'
		  AND disabled_at IS NULL
	`, userUUID); err != nil {
		h.logger.Error("failed to retire existing mfa factors", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to enroll mfa")
		return
	}

	var factorID string
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.mfa_factors (user_id, factor_type, secret, enabled)
		VALUES ($1, 'totp', $2, false)
		RETURNING id
	`, userUUID, secret).Scan(&factorID); err != nil {
		h.logger.Error("failed to create mfa factor", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to enroll mfa")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit mfa enroll transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to enroll mfa")
		return
	}

	label := url.QueryEscape(fmt.Sprintf("Flicko:%s", userUUID))
	issuer := url.QueryEscape("Flicko")
	provisioningURI := fmt.Sprintf(
		"otpauth://totp/%s?secret=%s&issuer=%s&period=%d&digits=%d",
		label, secret, issuer, totpPeriodSeconds, totpDigits,
	)

	writeJSON(w, http.StatusOK, mfaEnrollResponse{
		FactorID:        factorID,
		Secret:          secret,
		ProvisioningURI: provisioningURI,
	})
}

func (h *MFAHandler) Verify(w http.ResponseWriter, r *http.Request) {
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

	var req mfaVerifyRequest
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Code = strings.TrimSpace(req.Code)
	if !isNDigitCode(req.Code, totpDigits) {
		writeError(w, http.StatusBadRequest, "code must be a valid mfa code")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin mfa verify transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify mfa")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var factorID string
	var secret string
	var enabled bool
	if err = tx.QueryRow(r.Context(), `
		SELECT id, secret, enabled
		FROM public.mfa_factors
		WHERE user_id = $1
		  AND factor_type = 'totp'
		  AND disabled_at IS NULL
		ORDER BY created_at DESC
		LIMIT 1
		FOR UPDATE
	`, userUUID).Scan(&factorID, &secret, &enabled); err != nil {
		writeError(w, http.StatusNotFound, "mfa factor not enrolled")
		return
	}

	if !verifyTOTP(secret, req.Code, time.Now().UTC(), totpPeriodSeconds, totpDigits, totpSkewWindows) {
		writeError(w, http.StatusUnauthorized, "invalid mfa code")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.mfa_factors
		SET enabled = true,
		    verified_at = COALESCE(verified_at, NOW()),
		    updated_at = NOW()
		WHERE id = $1
	`, factorID); err != nil {
		h.logger.Error("failed to enable mfa factor", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify mfa")
		return
	}

	var recoveryCount int
	if err = tx.QueryRow(r.Context(), `
		SELECT COUNT(*)
		FROM public.mfa_recovery_codes
		WHERE factor_id = $1
		  AND used_at IS NULL
	`, factorID).Scan(&recoveryCount); err != nil {
		h.logger.Error("failed to count recovery codes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify mfa")
		return
	}

	resp := mfaVerifyResponse{
		Status:     "verified",
		MFAEnabled: true,
	}
	if recoveryCount == 0 {
		recoveryCodes, hashes, genErr := generateRecoveryCodes(8)
		if genErr != nil {
			h.logger.Error("failed to generate recovery codes", zap.Error(genErr))
			writeError(w, http.StatusInternalServerError, "failed to verify mfa")
			return
		}
		for _, hash := range hashes {
			if _, err = tx.Exec(r.Context(), `
				INSERT INTO public.mfa_recovery_codes (user_id, factor_id, code_hash)
				VALUES ($1, $2, $3)
			`, userUUID, factorID, hash); err != nil {
				h.logger.Error("failed to store recovery code", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to verify mfa")
				return
			}
		}
		resp.RecoveryCodes = recoveryCodes
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit mfa verify transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify mfa")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *MFAHandler) Disable(w http.ResponseWriter, r *http.Request) {
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

	var req mfaDisableRequest
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Code = strings.TrimSpace(req.Code)
	req.RecoveryCode = strings.TrimSpace(req.RecoveryCode)
	if req.Code == "" && req.RecoveryCode == "" {
		writeError(w, http.StatusBadRequest, "code or recovery_code is required")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin mfa disable transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to disable mfa")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var factorID string
	var secret string
	var enabled bool
	if err = tx.QueryRow(r.Context(), `
		SELECT id, secret, enabled
		FROM public.mfa_factors
		WHERE user_id = $1
		  AND factor_type = 'totp'
		  AND disabled_at IS NULL
		ORDER BY created_at DESC
		LIMIT 1
		FOR UPDATE
	`, userUUID).Scan(&factorID, &secret, &enabled); err != nil {
		writeError(w, http.StatusNotFound, "mfa factor not found")
		return
	}
	if !enabled {
		writeError(w, http.StatusConflict, "mfa is not enabled")
		return
	}

	authorized := false
	if req.Code != "" && isNDigitCode(req.Code, totpDigits) &&
		verifyTOTP(secret, req.Code, time.Now().UTC(), totpPeriodSeconds, totpDigits, totpSkewWindows) {
		authorized = true
	}

	var usedRecoveryCodeID string
	if !authorized && req.RecoveryCode != "" {
		hash := hashRecoveryCode(req.RecoveryCode)
		if err = tx.QueryRow(r.Context(), `
			SELECT id
			FROM public.mfa_recovery_codes
			WHERE user_id = $1
			  AND factor_id = $2
			  AND code_hash = $3
			  AND used_at IS NULL
			LIMIT 1
			FOR UPDATE
		`, userUUID, factorID, hash).Scan(&usedRecoveryCodeID); err == nil {
			authorized = true
		}
	}

	if !authorized {
		writeError(w, http.StatusUnauthorized, "invalid mfa code")
		return
	}

	if usedRecoveryCodeID != "" {
		if _, err = tx.Exec(r.Context(), `
			UPDATE public.mfa_recovery_codes
			SET used_at = NOW()
			WHERE id = $1
		`, usedRecoveryCodeID); err != nil {
			h.logger.Error("failed to mark recovery code used", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to disable mfa")
			return
		}
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.mfa_factors
		SET enabled = false,
		    disabled_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1
	`, factorID); err != nil {
		h.logger.Error("failed to disable mfa factor", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to disable mfa")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit mfa disable transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to disable mfa")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":      "disabled",
		"mfa_enabled": false,
	})
}

func generateTOTPSecret() (string, error) {
	secret := make([]byte, 20)
	if _, err := rand.Read(secret); err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(secret), nil
}

func isNDigitCode(code string, digits int) bool {
	if len(code) != digits {
		return false
	}
	for _, c := range code {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func verifyTOTP(secret, code string, now time.Time, period int64, digits int, skew int64) bool {
	decoded, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.ToUpper(strings.TrimSpace(secret)))
	if err != nil {
		return false
	}
	for i := -skew; i <= skew; i++ {
		counter := now.Unix()/period + i
		if counter < 0 {
			continue
		}
		expected := hotp(decoded, uint64(counter), digits)
		if hmac.Equal([]byte(expected), []byte(code)) {
			return true
		}
	}
	return false
}

func hotp(secret []byte, counter uint64, digits int) string {
	var msg [8]byte
	binary.BigEndian.PutUint64(msg[:], counter)

	mac := hmac.New(sha1.New, secret)
	_, _ = mac.Write(msg[:])
	sum := mac.Sum(nil)

	offset := sum[len(sum)-1] & 0x0f
	truncated := (uint32(sum[offset])&0x7f)<<24 |
		(uint32(sum[offset+1])&0xff)<<16 |
		(uint32(sum[offset+2])&0xff)<<8 |
		(uint32(sum[offset+3]) & 0xff)

	mod := uint32(1)
	for i := 0; i < digits; i++ {
		mod *= 10
	}
	code := truncated % mod
	return fmt.Sprintf("%0*d", digits, code)
}

func generateRecoveryCodes(n int) ([]string, []string, error) {
	if n <= 0 {
		return []string{}, []string{}, nil
	}
	codes := make([]string, 0, n)
	hashes := make([]string, 0, n)
	for i := 0; i < n; i++ {
		codeNum, err := cryptoRandomInt(10000000, 99999999)
		if err != nil {
			return nil, nil, err
		}
		code := strconv.Itoa(codeNum)
		codes = append(codes, code)
		hashes = append(hashes, hashRecoveryCode(code))
	}
	return codes, hashes, nil
}

func cryptoRandomInt(minVal, maxVal int) (int, error) {
	if maxVal < minVal {
		return 0, fmt.Errorf("invalid range")
	}
	if maxVal == minVal {
		return minVal, nil
	}
	width := maxVal - minVal + 1
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return 0, err
	}
	randVal := int(binary.BigEndian.Uint64(buf) % uint64(width))
	return minVal + randVal, nil
}

func hashRecoveryCode(code string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(code)))
	return hex.EncodeToString(sum[:])
}
