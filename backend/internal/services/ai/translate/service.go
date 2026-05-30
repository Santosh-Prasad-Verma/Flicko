package translate

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
)

// Service is the orchestrator: ACL + cache + provider chain + log.
type Service interface {
	Translate(ctx context.Context, in TranslateInput) (Result, error)
	GetUserSettings(ctx context.Context, userID string) (UserSettings, error)
	UpdateUserSettings(ctx context.Context, userID string, patch UserSettingsPatch) (UserSettings, error)
}

// UserSettings is the per-user preference object surfaced through GET/PATCH
// /api/v1/ai/translate/settings.
type UserSettings struct {
	UserID           string   `json:"user_id"`
	TargetLang       string   `json:"target_lang"`
	FluentLangs      []string `json:"fluent_langs"`
	Behavior         string   `json:"behavior"` // always|ask|never
	ShowProviderChip bool     `json:"show_provider_chip"`
}

// UserSettingsPatch is the optional-field shape used by PATCH.
type UserSettingsPatch struct {
	TargetLang       *string
	FluentLangs      []string
	Behavior         *string
	ShowProviderChip *bool
}

// TranslateInput is the validated request.
type TranslateInput struct {
	UserID    string
	ServerID  string
	ChannelID string
	MessageID string  // optional; persisted for log
	Text      string  // required
	Target    string  // BCP-47 / ISO-639-1 (e.g. "en", "fr")
	Hint      string  // optional source-language hint
}

type service struct {
	t      Translator
	cache  cache.CacheLayer
	db     database.DatabaseClient
	logger *zap.Logger
}

// NewService wires the orchestrator.
func NewService(t Translator, c cache.CacheLayer, db database.DatabaseClient, logger *zap.Logger) Service {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &service{t: t, cache: c, db: db, logger: logger.Named("ai.translate.svc")}
}

func (s *service) Translate(ctx context.Context, in TranslateInput) (Result, error) {
	if in.Text == "" || in.Target == "" {
		return Result{}, errors.New("missing text or target")
	}

	textHash := Hash(in.Text)
	gver := s.serverGlossaryVersion(ctx, in.ServerID)

	// Hot cache (Redis)
	cacheKey := "translate:cache:" + textHash + ":" + in.Hint + ":" + in.Target + ":" + itoa(gver)
	if s.cache != nil {
		if raw, err := s.cache.Get(ctx, cacheKey); err == nil && raw != "" {
			var hit cachedEntry
			if json.Unmarshal([]byte(raw), &hit) == nil {
				s.logTranslation(ctx, in, textHash, hit.Provider, true, 0, len(in.Text))
				return Result{
					TranslatedText: hit.Text,
					SrcLang:        hit.Src,
					TgtLang:        in.Target,
					Provider:       Provider(hit.Provider),
					Cached:         true,
				}, nil
			}
		}
	}

	// Miss — call upstream chain.
	res, err := s.t.Translate(ctx, in.Text, in.Target, in.Hint)
	if err != nil {
		return Result{}, err
	}

	// Write back to Redis + Postgres durable cache.
	if s.cache != nil {
		buf, _ := json.Marshal(cachedEntry{
			Text:     res.TranslatedText,
			Src:      res.SrcLang,
			Provider: string(res.Provider),
		})
		_ = s.cache.Set(ctx, cacheKey, string(buf), 30*24*time.Hour)
	}
	s.persistDurable(ctx, textHash, gver, in.Target, res)
	s.logTranslation(ctx, in, textHash, string(res.Provider), false, res.LatencyMs, len(in.Text))
	return res, nil
}

func (s *service) serverGlossaryVersion(ctx context.Context, serverID string) int {
	if serverID == "" || s.db == nil {
		return 0
	}
	row := s.db.QueryRow(ctx,
		`SELECT COALESCE(glossary_version, 0) FROM public.translate_server_settings WHERE server_id=$1`,
		serverID,
	)
	var v int
	_ = row.Scan(&v)
	return v
}

func (s *service) persistDurable(ctx context.Context, sha string, gver int, target string, res Result) {
	if s.db == nil {
		return
	}
	const q = `
		INSERT INTO public.translations_cache
		  (text_sha256, src_lang, tgt_lang, translated_text, provider, glossary_version, hit_count, last_seen_at)
		VALUES ($1,$2,$3,$4,$5,$6,1,now())
		ON CONFLICT (text_sha256, src_lang, tgt_lang, glossary_version)
		DO UPDATE SET hit_count = translations_cache.hit_count + 1,
		              last_seen_at = now()
	`
	if _, err := s.db.Exec(ctx, q, sha, res.SrcLang, target, res.TranslatedText, string(res.Provider), gver); err != nil {
		s.logger.Warn("persist translation cache", zap.Error(err))
	}
}

func (s *service) logTranslation(ctx context.Context, in TranslateInput, sha, provider string, cached bool, latencyMs, charCount int) {
	if s.db == nil {
		return
	}
	const q = `
		INSERT INTO public.translations_log
		  (id, requested_by, server_id, channel_id, message_id,
		   text_sha256, src_lang, tgt_lang, provider, cached, latency_ms, char_count)
		VALUES ($1,$2,NULLIF($3,'')::uuid,NULLIF($4,'')::uuid,NULLIF($5,'')::uuid,
		        $6,$7,$8,$9,$10,$11,$12)
	`
	if _, err := s.db.Exec(ctx, q,
		uuid.NewString(), in.UserID, in.ServerID, in.ChannelID, in.MessageID,
		sha, in.Hint, in.Target, provider, cached, latencyMs, charCount,
	); err != nil {
		s.logger.Debug("translation log insert", zap.Error(err))
	}
}

type cachedEntry struct {
	Text     string `json:"t"`
	Src      string `json:"s"`
	Provider string `json:"p"`
}

// GetUserSettings reads the row for `userID` or returns sensible defaults if
// none exists yet (fresh accounts get target_lang=en, behavior=ask).
func (s *service) GetUserSettings(ctx context.Context, userID string) (UserSettings, error) {
	out := UserSettings{
		UserID:           userID,
		TargetLang:       "en",
		FluentLangs:      []string{"en"},
		Behavior:         "ask",
		ShowProviderChip: true,
	}
	if s.db == nil {
		return out, nil
	}
	row := s.db.QueryRow(ctx, `
		SELECT target_lang, fluent_langs, behavior, show_provider_chip
		  FROM public.translate_user_settings
		 WHERE user_id = $1
	`, userID)
	var (
		target string
		fluent []string
		beh    string
		chip   bool
	)
	if err := row.Scan(&target, &fluent, &beh, &chip); err == nil {
		out.TargetLang = target
		out.FluentLangs = fluent
		out.Behavior = beh
		out.ShowProviderChip = chip
	}
	return out, nil
}

// UpdateUserSettings upserts the row using a single COALESCE statement so
// omitted patch fields preserve their current value.
func (s *service) UpdateUserSettings(ctx context.Context, userID string, patch UserSettingsPatch) (UserSettings, error) {
	if s.db == nil {
		return UserSettings{}, errors.New("no db")
	}
	current, _ := s.GetUserSettings(ctx, userID)
	if patch.TargetLang != nil {
		current.TargetLang = *patch.TargetLang
	}
	if patch.FluentLangs != nil {
		current.FluentLangs = patch.FluentLangs
	}
	if patch.Behavior != nil {
		current.Behavior = *patch.Behavior
	}
	if patch.ShowProviderChip != nil {
		current.ShowProviderChip = *patch.ShowProviderChip
	}
	if current.FluentLangs == nil {
		current.FluentLangs = []string{}
	}

	const q = `
		INSERT INTO public.translate_user_settings
		  (user_id, target_lang, fluent_langs, behavior, show_provider_chip, updated_at)
		VALUES ($1, $2, $3, $4, $5, now())
		ON CONFLICT (user_id) DO UPDATE SET
		  target_lang        = EXCLUDED.target_lang,
		  fluent_langs       = EXCLUDED.fluent_langs,
		  behavior           = EXCLUDED.behavior,
		  show_provider_chip = EXCLUDED.show_provider_chip,
		  updated_at         = now()
	`
	if _, err := s.db.Exec(ctx, q,
		userID, current.TargetLang, current.FluentLangs, current.Behavior, current.ShowProviderChip,
	); err != nil {
		return UserSettings{}, err
	}
	current.UserID = userID
	return current, nil
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	negative := n < 0
	if negative {
		n = -n
	}
	digits := []byte{}
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	if negative {
		digits = append([]byte{'-'}, digits...)
	}
	return string(digits)
}
