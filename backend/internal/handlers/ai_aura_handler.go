package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/flicko-org/flicko-backend/internal/config"
	"go.uber.org/zap"
)

type AIAuraHandler struct {
	cfg    *config.Config
	logger *zap.Logger
}

func NewAIAuraHandler(cfg *config.Config, logger *zap.Logger) *AIAuraHandler {
	return &AIAuraHandler{
		cfg:    cfg,
		logger: logger,
	}
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
	var req auraChatReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.Messages) == 0 {
		writeError(w, http.StatusBadRequest, "messages array is required")
		return
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		apiKey = os.Getenv("FLICKO_GEMINI_API_KEY")
	}

	sysPrompt, ok := systemPrompts[req.Category]
	if !ok {
		sysPrompt = systemPrompts["Text Writer"]
	}

	if apiKey != "" {
		contents := make([]map[string]interface{}, 0, len(req.Messages))
		for _, m := range req.Messages {
			role := "user"
			if m.Role == "assistant" || m.Sender == "assistant" {
				role = "model"
			}
			txt := m.Content
			if txt == "" {
				txt = m.Text
			}
			contents = append(contents, map[string]interface{}{
				"role": role,
				"parts": []map[string]string{
					{"text": txt},
				},
			})
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
		url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=%s", apiKey)
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

	writeJSON(w, http.StatusOK, map[string]string{"text": "I'm Aura, your AI assistant. I'm operating in fallback mode!"})
}

type GIFSearchReq struct {
	Query string `json:"q"`
	Limit int    `json:"limit"`
}

func (h *AIAuraHandler) HandleGifSearch(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		q = "funny"
	}
	giphyKey := os.Getenv("FLICKO_GIPHY_API_KEY")
	if giphyKey == "" {
		giphyKey = "HfMWbKrtVOYGPkt4I3qg6IH64HSOIv2U"
	}

	url := fmt.Sprintf("https://api.giphy.com/v1/gifs/search?api_key=%s&q=%s&limit=20&rating=g", giphyKey, q)
	resp, err := http.Get(url)
	if err != nil || resp.StatusCode != http.StatusOK {
		writeError(w, http.StatusInternalServerError, "Failed to fetch GIFs")
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	io.Copy(w, resp.Body)
}
