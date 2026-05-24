package search

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/hibiken/asynq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
)

func TestCDCWorkerAndMeiliSearch(t *testing.T) {
	log := zap.NewNop()

	// 1. Setup mock Meilisearch HTTP server
	var mu sync.Mutex
	receivedDocs := make([]interface{}, 0)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()

		w.Header().Set("Content-Type", "application/json")

		// Handle GET /indexes/messages
		if r.Method == http.MethodGet && r.URL.Path == "/indexes/messages" {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"uid":"messages","primaryKey":"id"}`))
			return
		}

		// Handle POST /indexes
		if r.Method == http.MethodPost && r.URL.Path == "/indexes" {
			w.WriteHeader(http.StatusCreated)
			_, _ = w.Write([]byte(`{"taskUid": 1}`))
			return
		}

		// Handle PUT filterable attributes
		if r.Method == http.MethodPut && r.URL.Path == "/indexes/messages/settings/filterable-attributes" {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"taskUid": 2}`))
			return
		}

		// Handle PUT sortable attributes
		if r.Method == http.MethodPut && r.URL.Path == "/indexes/messages/settings/sortable-attributes" {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"taskUid": 3}`))
			return
		}

		// Handle POST /indexes/messages/documents
		if r.Method == http.MethodPost && r.URL.Path == "/indexes/messages/documents" {
			var docs []interface{}
			err := json.NewDecoder(r.Body).Decode(&docs)
			if err == nil {
				receivedDocs = append(receivedDocs, docs...)
			}
			w.WriteHeader(http.StatusAccepted)
			_, _ = w.Write([]byte(`{"taskUid": 4}`))
			return
		}

		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	// Override Meilisearch host env
	t.Setenv("MEILISEARCH_HOST", server.URL)
	t.Setenv("MEILISEARCH_API_KEY", "test-key")

	// 2. Start miniredis for Asynq
	mr := miniredis.RunT(t)
	defer mr.Close()

	// 3. Initialize MeiliSearchClient
	meili := NewMeiliSearchClient(log)
	
	// Wait a bit for the async index creation to finish
	time.Sleep(100 * time.Millisecond)

	t.Run("EnqueueSearchSync and CDC Worker process", func(t *testing.T) {
		// Initialize asynq client pointing to miniredis
		asynqClient := asynq.NewClient(asynq.RedisClientOpt{Addr: mr.Addr()})
		defer asynqClient.Close()

		msg := &repository.Message{
			ID:        "msg-123",
			ChannelID: "chan-456",
			AuthorID:  "user-789",
			Content:   "Hello from Asynq CDC worker test!",
			CreatedAt: time.Now(),
		}

		ctx := context.Background()

		// Enqueue the task
		err := EnqueueSearchSync(ctx, asynqClient, msg, log)
		require.NoError(t, err)

		// Start CDC worker
		worker := NewCDCWorker("redis://"+mr.Addr(), meili, log)
		err = worker.Start()
		require.NoError(t, err)
		defer worker.Stop()

		// Wait for the worker to process the task
		time.Sleep(300 * time.Millisecond)

		// Verify document was indexed in Meilisearch mock server
		mu.Lock()
		defer mu.Unlock()
		assert.NotEmpty(t, receivedDocs)
		
		// Decode received doc to check content matches
		docBytes, err := json.Marshal(receivedDocs[0])
		require.NoError(t, err)
		
		var decodedMsg repository.Message
		err = json.Unmarshal(docBytes, &decodedMsg)
		require.NoError(t, err)

		assert.Equal(t, msg.ID, decodedMsg.ID)
		assert.Equal(t, msg.Content, decodedMsg.Content)
	})

	t.Run("SearchService integration", func(t *testing.T) {
		// Verify search queries are correctly forwarded to Meilisearch
		// We mock a search request
		// GET /indexes/messages/search?q=Hello&...
		// In meilisearch-go, SearchWithContext performs POST /indexes/messages/search
		server.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			if r.Method == http.MethodPost && r.URL.Path == "/indexes/messages/search" {
				w.WriteHeader(http.StatusOK)
				_, _ = w.Write([]byte(`{
					"hits": [
						{
							"id": "msg-123",
							"channel_id": "chan-456",
							"author_id": "user-789",
							"content": "Hello from Meilisearch mock!",
							"created_at": "2026-05-24T11:21:55Z"
						}
					],
					"query": "Hello",
					"processingTimeMs": 1,
					"limit": 20,
					"offset": 0,
					"estimatedTotalHits": 1
				}`))
				return
			}
			w.WriteHeader(http.StatusNotFound)
		})

		ctx := context.Background()
		res, err := meili.Search(ctx, "chan-456", "Hello", nil, 20)
		require.NoError(t, err)
		require.Len(t, res, 1)
		assert.Equal(t, "msg-123", res[0].ID)
		assert.Equal(t, "Hello from Meilisearch mock!", res[0].Content)
	})
}
