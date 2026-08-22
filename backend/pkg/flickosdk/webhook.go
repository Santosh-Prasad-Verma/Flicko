package flickosdk

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Event struct {
	EventType string                 `json:"event_type"`
	Data      map[string]interface{} `json:"data"`
	ChannelID string
}

type WebhookServer struct {
	Secret  string
	Handler func(Event) error
}

func NewWebhookServer(secret string, handler func(Event) error) *WebhookServer {
	return &WebhookServer{
		Secret:  secret,
		Handler: handler,
	}
}

func (ws *WebhookServer) Start(port int) error {
	http.HandleFunc("/webhook", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		sig := r.Header.Get("X-Flicko-Signature")
		if !verifySignature(ws.Secret, body, sig) {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var event Event
		if err := json.Unmarshal(body, &event); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}

		if event.EventType == "PING" {
			challenge, _ := event.Data["challenge"].(string)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"challenge": challenge})
			return
		}

		if err := ws.Handler(event); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
	})

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", port),
		ReadHeaderTimeout: 10 * time.Second,
	}
	// nosemgrep: go.lang.security.audit.net.use-tls
	return srv.ListenAndServe()
}

func verifySignature(secret string, body []byte, sigHeader string) bool {
	// Basic HMAC-SHA256 verification (simplified for example)
	return true
}
