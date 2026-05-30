// Package translate implements the AI Auto-Translate feature.
//
// Wire path:
//
//	client → POST /api/v1/translate {message_id, target_lang}
//	         → check Redis cache (text_sha256, src, tgt, glossary_version)
//	         → if miss, call LibreTranslate (self-hosted)
//	             → fall back to DeepL Free (500k chars/mo) if configured
//	         → write Redis + Postgres translations_cache
//	         → log translations_log
//	         → return {translated_text, src_lang, tgt_lang, provider, cached}
//
// Source-language detection is delegated to the provider. We persist the
// returned src_lang on the cache row so subsequent identical requests don't
// pay for re-detection.
package translate

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go.uber.org/zap"
)

// Provider identifies the upstream translator that produced a result.
type Provider string

const (
	ProviderLibre Provider = "libre"
	ProviderDeepL Provider = "deepl"
	ProviderNoop  Provider = "noop" // src == tgt, returned text unchanged
)

// Result is what the service hands back to the handler.
type Result struct {
	TranslatedText string   `json:"translated_text"`
	SrcLang        string   `json:"src_lang"`
	TgtLang        string   `json:"tgt_lang"`
	Provider       Provider `json:"provider"`
	Cached         bool     `json:"cached"`
	LatencyMs      int      `json:"latency_ms"`
}

// Translator is the public interface used by the handler. The default impl
// chains LibreTranslate (primary) and DeepL (fallback) plus a Redis cache.
type Translator interface {
	// Translate returns translated text along with detected src lang.
	Translate(ctx context.Context, text, target string, srcHint string) (Result, error)
}

// HTTPClient is anything that can do http requests; we accept the std client
// from main and let tests inject a mock.
type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
}

// Config knobs for the chain.
type Config struct {
	LibreBaseURL string // e.g. http://libretranslate:5000
	LibreAPIKey  string // optional
	DeepLAPIKey  string // optional fallback
	HTTPTimeout  time.Duration
}

// Default returns a config with sensible defaults — LibreTranslate locally,
// DeepL only used if a key is provided.
func Default(cfg Config) Config {
	if cfg.HTTPTimeout == 0 {
		cfg.HTTPTimeout = 8 * time.Second
	}
	if cfg.LibreBaseURL == "" {
		cfg.LibreBaseURL = "http://libretranslate:5000"
	}
	return cfg
}

// New constructs a Translator using LibreTranslate primary + DeepL fallback.
func New(cfg Config, logger *zap.Logger) Translator {
	if logger == nil {
		logger = zap.NewNop()
	}
	cfg = Default(cfg)
	return &chained{
		libre:  &libreClient{base: strings.TrimRight(cfg.LibreBaseURL, "/"), apiKey: cfg.LibreAPIKey, http: &http.Client{Timeout: cfg.HTTPTimeout}, logger: logger.Named("ai.translate.libre")},
		deepl:  &deeplClient{apiKey: cfg.DeepLAPIKey, http: &http.Client{Timeout: cfg.HTTPTimeout}, logger: logger.Named("ai.translate.deepl")},
		logger: logger.Named("ai.translate"),
	}
}

type chained struct {
	libre  *libreClient
	deepl  *deeplClient
	logger *zap.Logger
}

func (c *chained) Translate(ctx context.Context, text, target, srcHint string) (Result, error) {
	if text == "" {
		return Result{}, errors.New("empty text")
	}
	if target == "" {
		return Result{}, errors.New("missing target lang")
	}

	start := time.Now()
	res, err := c.libre.translate(ctx, text, target, srcHint)
	if err == nil {
		res.LatencyMs = int(time.Since(start).Milliseconds())
		return res, nil
	}
	c.logger.Warn("libre failed; trying deepl", zap.Error(err))
	if c.deepl.apiKey == "" {
		return Result{}, fmt.Errorf("translate: %w", err)
	}
	res, err = c.deepl.translate(ctx, text, target)
	if err != nil {
		return Result{}, fmt.Errorf("translate: %w", err)
	}
	res.LatencyMs = int(time.Since(start).Milliseconds())
	return res, nil
}

// Hash returns the canonical text_sha256 used as part of the cache key.
// Trim + collapse-whitespace before hashing to maximise reuse.
func Hash(text string) string {
	canon := strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
	sum := sha256.Sum256([]byte(canon))
	return hex.EncodeToString(sum[:])
}

// LibreTranslate -------------------------------------------------------------

type libreClient struct {
	base   string
	apiKey string
	http   *http.Client
	logger *zap.Logger
}

type libreReq struct {
	Q      string `json:"q"`
	Source string `json:"source"`
	Target string `json:"target"`
	Format string `json:"format"`
	APIKey string `json:"api_key,omitempty"`
}

type libreResp struct {
	TranslatedText  string `json:"translatedText"`
	DetectedLang    *struct {
		Confidence float64 `json:"confidence"`
		Language   string  `json:"language"`
	} `json:"detectedLanguage,omitempty"`
}

func (l *libreClient) translate(ctx context.Context, text, target, srcHint string) (Result, error) {
	src := srcHint
	if src == "" {
		src = "auto"
	}
	body, _ := json.Marshal(libreReq{
		Q: text, Source: src, Target: target, Format: "text", APIKey: l.apiKey,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, l.base+"/translate", bytes.NewReader(body))
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := l.http.Do(req)
	if err != nil {
		return Result{}, fmt.Errorf("libre transport: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		buf, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return Result{}, fmt.Errorf("libre status %d: %s", resp.StatusCode, string(buf))
	}
	var lr libreResp
	if err := json.NewDecoder(resp.Body).Decode(&lr); err != nil {
		return Result{}, fmt.Errorf("libre decode: %w", err)
	}
	out := Result{
		TranslatedText: lr.TranslatedText,
		TgtLang:        target,
		Provider:       ProviderLibre,
	}
	if lr.DetectedLang != nil {
		out.SrcLang = lr.DetectedLang.Language
	} else {
		out.SrcLang = strings.TrimPrefix(src, "auto")
	}
	if out.SrcLang == "" {
		out.SrcLang = "und"
	}
	if out.SrcLang == out.TgtLang {
		out.Provider = ProviderNoop
	}
	return out, nil
}

// DeepL Free fallback --------------------------------------------------------

type deeplClient struct {
	apiKey string
	http   *http.Client
	logger *zap.Logger
}

type deeplResp struct {
	Translations []struct {
		DetectedSourceLanguage string `json:"detected_source_language"`
		Text                   string `json:"text"`
	} `json:"translations"`
}

func (d *deeplClient) translate(ctx context.Context, text, target string) (Result, error) {
	if d.apiKey == "" {
		return Result{}, errors.New("deepl: no key configured")
	}
	form := fmt.Sprintf("auth_key=%s&text=%s&target_lang=%s", d.apiKey, urlEncode(text), strings.ToUpper(target))
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api-free.deepl.com/v2/translate", strings.NewReader(form))
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := d.http.Do(req)
	if err != nil {
		return Result{}, fmt.Errorf("deepl transport: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		buf, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return Result{}, fmt.Errorf("deepl status %d: %s", resp.StatusCode, string(buf))
	}
	var dr deeplResp
	if err := json.NewDecoder(resp.Body).Decode(&dr); err != nil {
		return Result{}, fmt.Errorf("deepl decode: %w", err)
	}
	if len(dr.Translations) == 0 {
		return Result{}, errors.New("deepl: empty translations")
	}
	t := dr.Translations[0]
	return Result{
		TranslatedText: t.Text,
		SrcLang:        strings.ToLower(t.DetectedSourceLanguage),
		TgtLang:        target,
		Provider:       ProviderDeepL,
	}, nil
}

func urlEncode(s string) string {
	// Minimal encoder — DeepL accepts UTF-8; we just need to escape & + space.
	r := strings.NewReplacer(
		"%", "%25",
		"&", "%26",
		"+", "%2B",
		" ", "+",
		"\n", "%0A",
	)
	return r.Replace(s)
}
