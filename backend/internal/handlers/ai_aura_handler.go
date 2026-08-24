package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/gorilla/mux"
	"github.com/flicko-org/flicko-backend/internal/config"
	"go.uber.org/zap"
)

type AIAuraHandler struct {
	cfg    *config.Config
	logger *zap.Logger
}

func NewAIAuraHandler(cfg *config.Config, logger *zap.Logger) *AIAuraHandler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &AIAuraHandler{
		cfg:    cfg,
		logger: logger.Named("handler.ai_aura"),
	}
}

func (h *AIAuraHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/aura/chat", h.HandleAuraChat).Methods(http.MethodPost, http.MethodOptions)
	r.HandleFunc("/aura/gifs", h.HandleGifSearch).Methods(http.MethodGet, http.MethodOptions)
	r.HandleFunc("/aura/tts", h.HandleTTS).Methods(http.MethodPost, http.MethodOptions)
}

type auraMessage struct {
	Role    string `json:"role"`
	Sender  string `json:"sender"`
	Content string `json:"content"`
	Text    string `json:"text"`
}

type auraChatReq struct {
	Category string        `json:"category"`
	Messages []auraMessage `json:"messages"`
}

var systemPrompts = map[string]string{
	"Text Writer":     "You are Aura, a premium AI assistant inside the Flicko messaging app. You are warm, knowledgeable, and conversational. Respond concisely but helpfully. Use markdown formatting when appropriate.",
	"Image Generator": "You are Aura, an AI image description specialist inside the Flicko app. Describe images vividly.",
	"Code Tutor":       "You are Aura, an expert programming tutor inside the Flicko app. Provide clear code examples with explanations. Use markdown code blocks.",
}

func (h *AIAuraHandler) HandleAuraChat(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	var req auraChatReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.Messages) == 0 {
		writeError(w, http.StatusBadRequest, "messages array is required")
		return
	}

	apiKey := ""
	if h.cfg != nil && h.cfg.FlickoGeminiAPIKey != "" {
		apiKey = h.cfg.FlickoGeminiAPIKey
	}
	if apiKey == "" {
		apiKey = os.Getenv("OPENROUTER_API_KEY")
	}
	if apiKey == "" {
		apiKey = os.Getenv("FLICKO_OPENROUTER_API_KEY")
	}
	if apiKey == "" {
		apiKey = os.Getenv("GEMINI_API_KEY")
	}
	if apiKey == "" {
		apiKey = os.Getenv("FLICKO_GEMINI_API_KEY")
	}

	sysPrompt, ok := systemPrompts[req.Category]
	if !ok {
		sysPrompt = systemPrompts["Text Writer"]
	}

	if apiKey != "" {
		// 1. OpenRouter (OpenAI-compatible) endpoint
		if strings.HasPrefix(apiKey, "sk-or-") {
			model := "nvidia/nemotron-3-ultra-550b-a55b:free"
			if h.cfg != nil && h.cfg.GeminiModel != "" {
				model = h.cfg.GeminiModel
			}

			oaiMessages := make([]map[string]string, 0, len(req.Messages)+1)
			oaiMessages = append(oaiMessages, map[string]string{
				"role":    "system",
				"content": sysPrompt,
			})
			for _, m := range req.Messages {
				role := "user"
				if m.Role == "assistant" || m.Sender == "assistant" || m.Role == "model" {
					role = "assistant"
				}
				txt := m.Content
				if txt == "" {
					txt = m.Text
				}
				if txt != "" {
					oaiMessages = append(oaiMessages, map[string]string{
						"role":    role,
						"content": txt,
					})
				}
			}

			payload := map[string]interface{}{
				"model":       model,
				"messages":    oaiMessages,
				"temperature": 0.7,
				"max_tokens":  2048,
			}

			jsonBytes, _ := json.Marshal(payload)
			httpReq, reqErr := http.NewRequestWithContext(r.Context(), http.MethodPost, "https://openrouter.ai/api/v1/chat/completions", bytes.NewBuffer(jsonBytes))
			if reqErr == nil {
				httpReq.Header.Set("Content-Type", "application/json")
				httpReq.Header.Set("Authorization", "Bearer "+apiKey)
				httpReq.Header.Set("HTTP-Referer", "https://flicko.dev")
				httpReq.Header.Set("X-Title", "Flicko")

				resp, err := http.DefaultClient.Do(httpReq)
				if err == nil {
					defer resp.Body.Close()
					if resp.StatusCode == http.StatusOK {
						var data struct {
							Choices []struct {
								Message struct {
									Content string `json:"content"`
								} `json:"message"`
							} `json:"choices"`
						}
						if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && len(data.Choices) > 0 && data.Choices[0].Message.Content != "" {
							writeJSON(w, http.StatusOK, map[string]string{"text": data.Choices[0].Message.Content})
							return
						}
					} else {
						buf, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
						h.logger.Warn("openrouter call non-200", zap.Int("status", resp.StatusCode), zap.String("body", string(buf)))
					}
				} else {
					h.logger.Warn("openrouter request failed", zap.Error(err))
				}
			}
		} else {
			// 2. Direct Google Gemini endpoint
			contents := make([]map[string]interface{}, 0, len(req.Messages))
			for _, m := range req.Messages {
				role := "user"
				if m.Role == "assistant" || m.Sender == "assistant" || m.Role == "model" {
					role = "model"
				}
				txt := m.Content
				if txt == "" {
					txt = m.Text
				}
				if txt != "" {
					contents = append(contents, map[string]interface{}{
						"role": role,
						"parts": []map[string]string{
							{"text": txt},
						},
					})
				}
			}

			payload := map[string]interface{}{
				"contents": contents,
				"systemInstruction": map[string]interface{}{
					"parts": []map[string]string{{"text": sysPrompt}},
				},
				"generationConfig": map[string]interface{}{
					"temperature":     0.7,
					"maxOutputTokens": 2048,
				},
			}

			jsonBytes, _ := json.Marshal(payload)
			url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=%s", apiKey)
			resp, err := http.Post(url, "application/json", bytes.NewBuffer(jsonBytes))
			if err == nil && resp.StatusCode == http.StatusOK {
				defer resp.Body.Close()
				var data struct {
					Candidates []struct {
						Content struct {
							Parts []struct {
								Text string `json:"text"`
							} `json:"parts"`
						} `json:"content"`
					} `json:"candidates"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && len(data.Candidates) > 0 && len(data.Candidates[0].Content.Parts) > 0 {
					writeJSON(w, http.StatusOK, map[string]string{"text": data.Candidates[0].Content.Parts[0].Text})
					return
				}
			}
		}
	}

	writeJSON(w, http.StatusOK, map[string]string{"text": "I'm Aura, your AI assistant. I'm operating in fallback mode!"})
}

func (h *AIAuraHandler) HandleTTS(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	// Return 204 No Content so clients smoothly use on-device TTS
	w.WriteHeader(http.StatusNoContent)
}

func (h *AIAuraHandler) HandleGifSearch(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		q = "funny"
	}
	giphyKey := os.Getenv("FLICKO_GIPHY_API_KEY")
	if giphyKey == "" {
		writeError(w, http.StatusServiceUnavailable, "GIF search service is currently unavailable")
		return
	}

	searchURL := fmt.Sprintf("https://api.giphy.com/v1/gifs/search?api_key=%s&q=%s&limit=20&rating=g",
		url.QueryEscape(giphyKey),
		url.QueryEscape(q),
	)
	resp, err := http.Get(searchURL)
	if err != nil || resp.StatusCode != http.StatusOK {
		writeError(w, http.StatusInternalServerError, "Failed to fetch GIFs")
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	io.Copy(w, resp.Body)
}
